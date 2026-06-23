// Global clipboard-send history. Shared across all devices (any device
// the user sends text to is a row here) — this is intentional so the
// clipboard tab acts as a "recently used snippets" library rather than
// a per-device log.
//
// `sendCount` is incremented when the same text is sent again so the
// UI can sort by "most-sent" if it wants. We don't expose that today
// but keeping the counter costs nothing.
//
// Trim policy: `watchRecent` returns the favorites first (pinned) then
// the N most recent non-favorites. `trimTo` enforces the cap on every
// insert so the table doesn't grow unbounded.
//
// NOTE: name is `SentClipboardEntry` (not `ClipboardHistory`) and
// file is `sent_clipboard_entry.dart`. drift_dev 2.34 has a parser
// bug that crashes on tables named `ClipboardHistory` / file
// `clipboard_history.dart` — likely an internal AST cache key
// collision with some pre-existing symbol. The rename sidesteps it.
import 'package:drift/drift.dart';

class SentClipboardEntry extends Table {
  IntColumn get id => integer().autoIncrement()();
  // Named `content` (not `text`) to avoid colliding with `Table.text()`
  // — drift's column-constructor method shares the same name. The
  // drift codegen surfaces the column as `content` on the row + companion.
  TextColumn get content => text()();
  DateTimeColumn get sentAt => dateTime()();
  BoolColumn get favorite => boolean()();
  IntColumn get sendCount => integer()();
}
