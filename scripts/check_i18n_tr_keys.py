#!/usr/bin/env python3
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FLUTTER_APP = ROOT / "flutter_app"
LIB = FLUTTER_APP / "lib"
I18N_ENTRY = LIB / "i18n.dart"

STRING_LITERAL = r"(?:'([^'\\]*(?:\\.[^'\\]*)*)'|\"([^\"\\]*(?:\\.[^\"\\]*)*)\")"
TR_CALL_RE = re.compile(r"\btr\s*\(\s*" + STRING_LITERAL, re.MULTILINE)
# `part` directives only matter at the top level of the entry file. Anchoring
# to line-start keeps us from matching the `part 'i18n/<domain>.dart';`
# example in the docstring above (which would otherwise be treated as a real
# file path and fail to resolve).
PART_RE = re.compile(r"^\s*part\s+['\"]([^'\"]+)['\"]\s*;", re.MULTILINE)
LOCALE_BLOCK_RE = re.compile(r"'([^']+)'\s*:\s*\{")
SPREAD_RE = re.compile(r"\.\.\.\s*([A-Za-z_]\w*)")
MAP_RE = re.compile(r"const\s+([A-Za-z_]\w*)\s*=\s*<String,\s*String>\s*\{")
KEY_RE = re.compile(r"^\s*" + STRING_LITERAL + r"\s*:", re.MULTILINE)


def unescape_dart_string(value):
    return bytes(value, "utf-8").decode("unicode_escape")


def literal_value(match, group_start=1):
    value = match.group(group_start) if match.group(group_start) is not None else match.group(group_start + 1)
    return unescape_dart_string(value)


def find_matching_brace(text, open_index):
    depth = 0
    in_string = None
    escaped = False
    for index in range(open_index, len(text)):
        char = text[index]
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == in_string:
                in_string = None
            continue
        if char in ("'", '"'):
            in_string = char
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return index
    raise ValueError(f"Unmatched brace at {open_index}")


def extract_i18n_parts(entry_text):
    return [(LIB / match.group(1)).resolve() for match in PART_RE.finditer(entry_text)]


def extract_locale_spreads(entry_text):
    loc_match = re.search(r"const\s+_loc\s*=\s*<String,\s*Map<String,\s*String>>\s*\{", entry_text)
    if not loc_match:
        raise ValueError("Cannot find const _loc in i18n.dart")
    loc_open = entry_text.find("{", loc_match.start())
    loc_close = find_matching_brace(entry_text, loc_open)
    loc_body = entry_text[loc_open + 1:loc_close]
    locales = {}
    cursor = 0
    while True:
        match = LOCALE_BLOCK_RE.search(loc_body, cursor)
        if not match:
            break
        locale = match.group(1)
        block_open = loc_body.find("{", match.start())
        block_close = find_matching_brace(loc_body, block_open)
        locales[locale] = SPREAD_RE.findall(loc_body[block_open + 1:block_close])
        cursor = block_close + 1
    return locales


def extract_map_keys(file_path):
    text = file_path.read_text(encoding="utf-8")
    maps = {}
    cursor = 0
    while True:
        match = MAP_RE.search(text, cursor)
        if not match:
            break
        name = match.group(1)
        block_open = text.find("{", match.start())
        block_close = find_matching_brace(text, block_open)
        body = text[block_open + 1:block_close]
        maps[name] = {literal_value(key_match) for key_match in KEY_RE.finditer(body)}
        cursor = block_close + 1
    return maps


def collect_generated_keys(entry_text):
    locale_spreads = extract_locale_spreads(entry_text)
    maps = {}
    for part_path in extract_i18n_parts(entry_text):
        if part_path.exists():
            maps.update(extract_map_keys(part_path))
    generated = {}
    missing_maps = {}
    for locale, spread_names in locale_spreads.items():
        keys = set()
        absent = []
        for name in spread_names:
            if name not in maps:
                absent.append(name)
                continue
            keys.update(maps[name])
        generated[locale] = keys
        if absent:
            missing_maps[locale] = absent
    return generated, missing_maps


def collect_tr_calls():
    calls = []
    for file_path in sorted(LIB.rglob("*.dart")):
        if file_path == I18N_ENTRY or "/i18n/" in file_path.as_posix():
            continue
        text = file_path.read_text(encoding="utf-8")
        for match in TR_CALL_RE.finditer(text):
            key = literal_value(match)
            if "$" in key:
                continue
            line = text.count("\n", 0, match.start()) + 1
            calls.append((key, file_path, line))
    return calls


def main():
    if not I18N_ENTRY.exists():
        print(f"i18n.dart not found: {I18N_ENTRY}", file=sys.stderr)
        return 2
    entry_text = I18N_ENTRY.read_text(encoding="utf-8")
    generated, missing_maps = collect_generated_keys(entry_text)
    calls = collect_tr_calls()
    all_generated = set().union(*generated.values()) if generated else set()
    missing_anywhere = [(key, path, line) for key, path, line in calls if key not in all_generated]
    missing_by_locale = {}
    for locale, keys in generated.items():
        locale_missing = [(key, path, line) for key, path, line in calls if key not in keys]
        if locale_missing:
            missing_by_locale[locale] = locale_missing
    print(f"Scanned tr literal calls: {len(calls)}")
    print(f"Locales in _loc: {', '.join(sorted(generated))}")
    for locale in sorted(generated):
        print(f"Generated keys for {locale}: {len(generated[locale])}")
    if missing_maps:
        print("\nMissing spread maps:")
        for locale, names in sorted(missing_maps.items()):
            for name in names:
                print(f"  [{locale}] {name}")
    if missing_anywhere:
        print("\nKeys missing from all generated locale maps:")
        for key, path, line in missing_anywhere:
            print(f"  {path.relative_to(ROOT)}:{line}  tr('{key}')")
    else:
        print("\nNo tr literal keys are missing from all generated locale maps.")
    locale_only = {
        locale: items
        for locale, items in missing_by_locale.items()
        if any(key in all_generated for key, _, _ in items)
    }
    if locale_only:
        print("\nKeys missing in specific locales:")
        for locale in sorted(locale_only):
            print(f"  [{locale}]")
            for key, path, line in locale_only[locale]:
                if key in all_generated:
                    print(f"    {path.relative_to(ROOT)}:{line}  tr('{key}')")
    return 1 if missing_anywhere or locale_only or missing_maps else 0


if __name__ == "__main__":
    raise SystemExit(main())
