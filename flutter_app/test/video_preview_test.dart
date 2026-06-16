import 'package:adb_tool/widgets/video_preview.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Windows uses external video preview fallback', () {
    expect(videoPreviewModeForPlatform(isWindows: true),
        VideoPreviewMode.external);
  });

  test('non-Windows keeps embedded video preview', () {
    expect(videoPreviewModeForPlatform(isWindows: false),
        VideoPreviewMode.embedded);
  });
}
