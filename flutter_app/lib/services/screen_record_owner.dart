// Who initiated the current in-flight screen recording on a device.
// Two surfaces can each initiate a recording on the same device, and
// the two values are mutually exclusive — only one can be active at
// a time. The state is persisted on the SavedDevices row
// (recording_owner text column), so the cross-screen "is anyone
// recording on this device?" check survives app restarts.
//
// Values stored on disk are stable strings (dbValue) so renames of
// the Dart enum don't corrupt existing rows.
enum ScreenRecordOwner {
  /// Recording was started from the file-browser screen. Standalone
  /// (no test session attached) — video goes to a local save dialog
  /// / preview.
  fileBrowser,

  /// Recording was started from the test-session screen. The video
  /// is auto-attached to the active session as an artifact.
  testSession,
}

extension ScreenRecordOwnerX on ScreenRecordOwner {
  /// Stable string for the DB column.
  String get dbValue => switch (this) {
        ScreenRecordOwner.fileBrowser => 'file_browser',
        ScreenRecordOwner.testSession => 'test_session',
      };

  /// Inverse of [dbValue]. Returns null for null / unknown values.
  static ScreenRecordOwner? fromDb(String? value) => switch (value) {
        'file_browser' => ScreenRecordOwner.fileBrowser,
        'test_session' => ScreenRecordOwner.testSession,
        _ => null,
      };

  /// i18n key for the human-friendly page name (used in
  /// "录屏中(在{owner})" hints and snackbars).
  String get pageNameKey => switch (this) {
        ScreenRecordOwner.fileBrowser => 'fileBrowserName',
        ScreenRecordOwner.testSession => 'testSessionName',
      };
}
