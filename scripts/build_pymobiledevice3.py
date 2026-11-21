"""Build the platform-native CLI and accompanying source archive for release."""

import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import urlopen
import venv
import zipfile


CLI_VERSION = "11.55.1"
PYINSTALLER_VERSION = "6.22.3"
SCRIPTS = Path(__file__).resolve().parent
SOURCE_LICENSE = re.compile(
    r"\b(?:[al]?gpl(?:v\d+)?|mpl(?:v\d+)?|general public license|mozilla public license)\b",
    re.IGNORECASE,
)
NOTICE_PREFIXES = ("licen", "copying", "notice")


def read_url(url):
    import ssl
    ctx = ssl.create_default_context()
    for cafile in ("/etc/ssl/cert.pem", "/opt/homebrew/share/ca-certificates/cacert.pem"):
        if os.path.isfile(cafile):
            ctx.load_verify_locations(cafile=cafile)
            break
    for attempt in range(5):
        try:
            with urlopen(url, timeout=30, context=ctx) as response:
                return response.read()
        except (URLError, TimeoutError) as error:
            permanent_error = (
                isinstance(error, HTTPError)
                and 400 <= error.code < 500
                and error.code not in (408, 429)
            )
            if attempt == 4 or permanent_error:
                raise RuntimeError(f"Failed to download {url}") from error
            time.sleep(2 ** attempt)


def download_source(name, version):
    print(f"Collecting source for {name} {version}", flush=True)
    project_url = f"https://pypi.org/pypi/{quote(name)}/{quote(version)}/json"
    project = json.loads(read_url(project_url))
    source = next(
        (item for item in project["urls"] if item["packagetype"] == "sdist"), None
    )
    if source is None:
        raise RuntimeError(f"No source distribution for {name} {version}")
    data = read_url(source["url"])
    if hashlib.sha256(data).hexdigest() != source["digests"]["sha256"]:
        raise RuntimeError(f"Source checksum mismatch for {name} {version}")
    return f"sources/{source['filename']}", data


def create_source_archive(python, destination, existing_archive=None):
    info = json.loads(subprocess.check_output(
        [python, "-m", "pip", "inspect", "--local"],
        env=os.environ | {"PYTHONIOENCODING": "utf-8"},
    ))
    existing_sources = {}
    if existing_archive and Path(existing_archive).is_file():
        try:
            with zipfile.ZipFile(existing_archive, "r") as old_zf:
                for member in old_zf.namelist():
                    if member.startswith("sources/"):
                        existing_sources[member] = old_zf.read(member)
        except Exception:
            pass

    def get_or_download(name, version):
        prefix = f"sources/{name.replace('-', '_')}-{version}."
        alt_prefix = f"sources/{name}-{version}."
        for k, v in existing_sources.items():
            if k.startswith(prefix) or k.startswith(alt_prefix):
                return k, v
        return download_source(name, version)

    with (
        ThreadPoolExecutor(max_workers=4) as downloads,
        zipfile.ZipFile(destination, "w", zipfile.ZIP_DEFLATED) as archive,
    ):
        versions = []
        sources = []
        for installed in info["installed"]:
            metadata = installed["metadata"]
            name, version = metadata["name"], metadata["version"]
            versions.append(f"{name}=={version}")
            # Some older wheels use the full license text or Trove classifiers.
            license_info = " ".join(
                [
                    metadata.get("license_expression", ""),
                    metadata.get("license", "")[:1000],
                    *(item for item in metadata.get("classifier", []) if item.startswith("License ::")),
                ]
            )
            if SOURCE_LICENSE.search(license_info):
                sources.append(downloads.submit(get_or_download, name, version))

            dist_info = Path(installed["metadata_location"])
            if dist_info.is_dir():
                for notice in sorted(dist_info.rglob("*")):
                    rel = notice.relative_to(dist_info)
                    is_notice = any(part.lower().startswith(NOTICE_PREFIXES) for part in rel.parts)
                    if notice.is_file() and is_notice:
                        archive.write(notice, f"licenses/{name}/{rel.as_posix()}")

        for source in sources:
            filename, data = source.result()
            archive.writestr(filename, data)

        archive.writestr("python-packages.txt", "\n".join(sorted(versions)) + "\n")
        archive.write(__file__, "build/build_pymobiledevice3.py")
        archive.write(SCRIPTS / "pymobiledevice3_cli.py", "build/pymobiledevice3_cli.py")


def build(output):
    with tempfile.TemporaryDirectory(prefix="adb-tool-ios-") as temp_dir:
        work = Path(temp_dir)
        venv.create(work / "venv", with_pip=True)
        windows = sys.platform == "win32"
        python = work / "venv" / ("Scripts/python.exe" if windows else "bin/python")
        subprocess.run(
            [
                python, "-m", "pip", "install", "--disable-pip-version-check",
                f"pymobiledevice3=={CLI_VERSION}", f"pyinstaller=={PYINSTALLER_VERSION}",
            ],
            check=True,
        )
        pyinstaller_args = [
            python, "-m", "PyInstaller", "--onefile", "--noupx",
            "--name", "pymobiledevice3",
            "--collect-all", "pymobiledevice3",
            "--collect-all", "pytun_pmd3",
            "--collect-data", "pykdebugparser",
            "--recursive-copy-metadata", "pymobiledevice3",
            "--distpath", work / "dist",
            "--workpath", work / "build",
            "--specpath", work,
        ]
        if windows:
            wintun_dir = subprocess.check_output(
                [python, "-c", "import pathlib, pytun_pmd3; print(pathlib.Path(pytun_pmd3.__file__).parent / 'wintun')"],
                text=True,
            ).strip()
            if os.path.isdir(wintun_dir):
                pyinstaller_args.extend(["--add-data", f"{wintun_dir};pytun_pmd3/wintun"])
        pyinstaller_args.append(SCRIPTS / "pymobiledevice3_cli.py")
        subprocess.run(
            pyinstaller_args,
            check=True,
            env=os.environ | {"PYINSTALLER_CONFIG_DIR": str(work / "pyinstaller-cache")},
        )

        binary = work / "dist" / ("pymobiledevice3.exe" if windows else "pymobiledevice3")
        result = subprocess.check_output([binary, "version"], text=True, timeout=30)
        if result.strip() != CLI_VERSION:
            raise RuntimeError(f"Expected {CLI_VERSION}, got {result.strip()!r}")
        for args in (["usbmux", "list"], ["crash", "ls"], ["crash", "pull"]):
            subprocess.run([binary, *args, "--help"], check=True, stdout=subprocess.DEVNULL, timeout=30)

        sources = work / "pymobiledevice3-source.zip"
        create_source_archive(python, sources, output / sources.name)
        output.mkdir(parents=True, exist_ok=True)
        shutil.copy2(binary, output / binary.name)
        shutil.copy2(sources, output / sources.name)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path, help="Destination directory for the CLI and source archive")
    build(parser.parse_args().output)
