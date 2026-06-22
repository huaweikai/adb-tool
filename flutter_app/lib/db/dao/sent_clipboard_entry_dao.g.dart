// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sent_clipboard_entry_dao.dart';

// ignore_for_file: type=lint
mixin _$SentClipboardEntryDaoMixin on DatabaseAccessor<AppDatabase> {
  $SentClipboardEntryTable get sentClipboardEntry =>
      attachedDatabase.sentClipboardEntry;
  SentClipboardEntryDaoManager get managers =>
      SentClipboardEntryDaoManager(this);
}

class SentClipboardEntryDaoManager {
  final _$SentClipboardEntryDaoMixin _db;
  SentClipboardEntryDaoManager(this._db);
  $$SentClipboardEntryTableTableManager get sentClipboardEntry =>
      $$SentClipboardEntryTableTableManager(
          _db.attachedDatabase, _db.sentClipboardEntry);
}
