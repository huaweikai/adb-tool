// Unit tests for the small identity helpers on `Device` — they
// exist specifically because the v8→v9 identity split moved
// `serial` (PK) to ro.serialno while the Device model returned by
// `GET /api/devices` keeps `serial` = adb-serial. Any code that
// needs to match a Device against the DeviceSerialScope value
// (ro.serialno) used to silently fail before this helper existed.

import 'package:adb_tool/models/device.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Device.matchesIdentity', () {
    test('matches by adb-serial (USB case where ro.serialno == adb-serial)',
        () {
      const d = Device(
        serial: 'R5CT70AHPDR',
        hardwareSerial: 'R5CT70AHPDR',
        state: 'device',
      );
      expect(d.matchesIdentity('R5CT70AHPDR'), isTrue);
    });

    test('matches by hardwareSerial for wireless (scope = ro.serialno, '
        'device.adb-serial = ip:port)', () {
      // The exact pre-fix bug: scope was 'R5CT70AHPDR' (ro.serialno),
      // device.serial was '192.168.31.141:33729' (adb address). The
      // old `d.serial == scopeSerial` check returned false and
      // displayName fell back to showing the raw ro.serialno.
      const d = Device(
        serial: '192.168.31.141:33729',
        hardwareSerial: 'R5CT70AHPDR',
        state: 'device',
      );
      expect(d.matchesIdentity('R5CT70AHPDR'), isTrue,
          reason: 'wireless device must match by ro.serialno');
    });

    test('does not match unrelated serial', () {
      const d = Device(
        serial: '192.168.31.141:33729',
        hardwareSerial: 'R5CT70AHPDR',
        state: 'device',
      );
      expect(d.matchesIdentity('OTHER-DEVICE-SN'), isFalse);
    });

    test('does not match null or empty', () {
      const d = Device(
        serial: 'X',
        hardwareSerial: 'Y',
        state: 'device',
      );
      expect(d.matchesIdentity(null), isFalse);
      expect(d.matchesIdentity(''), isFalse);
    });

    test('unauthorized device (empty hardwareSerial) matches by '
        'adb-serial — the legacy adb-only lookup path', () {
      const d = Device(
        serial: '192.168.31.141:5555',
        hardwareSerial: '',
        state: 'device',
      );
      // Scope might be the adb-serial for these (the reconcile path
      // falls back to it when props are unreadable) OR the
      // hardwareSerial (empty in this case) — the helper must work
      // for both shapes.
      expect(d.matchesIdentity('192.168.31.141:5555'), isTrue);
      expect(d.matchesIdentity(''), isFalse);
    });
  });
}
