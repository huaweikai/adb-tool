import 'package:adb_tool/providers/recording_settings_provider.dart';
import 'package:adb_tool/providers/scrcpy_record_state_provider.dart';
import 'package:adb_tool/services/api_client.dart';
import 'package:adb_tool/services/recording_strategy.dart';
import 'package:adb_tool/services/screen_capture_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _Api extends Fake implements ApiClient {}

class _Capture extends Fake implements ScreenCaptureService {}

class _RecordState extends Fake implements ScrcpyRecordStateProvider {}

void main() {
  final api = _Api();
  final capture = _Capture();
  final state = _RecordState();

  for (final method in ScreenRecordMethod.values) {
    test('iOS rejects $method until native recording is implemented', () {
      expect(
        () => RecordingStrategy.create(method,
            serial: 'ios:PHONE',
            api: api,
            capture: capture,
            recordState: state),
        throwsA(isA<UnsupportedError>()),
      );
    });
  }

  test('Android keeps both recording strategies', () {
    expect(
      RecordingStrategy.create(ScreenRecordMethod.adb,
          serial: 'android-phone',
          api: api,
          capture: capture,
          recordState: state),
      isA<AdbRecordingStrategy>(),
    );
    expect(
      RecordingStrategy.create(ScreenRecordMethod.scrcpy,
          serial: 'android-phone',
          api: api,
          capture: capture,
          recordState: state),
      isA<ScrcpyRecordingStrategy>(),
    );
  });
}
