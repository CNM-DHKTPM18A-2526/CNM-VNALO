import 'package:flutter_test/flutter_test.dart';
import 'package:vnalo_mobile/features/call/utils/call_duration_formatter.dart';

void main() {
  group('formatCallDuration', () {
    test('formats under one hour as mm:ss', () {
      expect(formatCallDuration(const Duration(seconds: 5)), '00:05');
      expect(
        formatCallDuration(const Duration(minutes: 3, seconds: 12)),
        '03:12',
      );
      expect(
        formatCallDuration(const Duration(minutes: 59, seconds: 59)),
        '59:59',
      );
    });

    test('formats one hour or more as hh:mm:ss', () {
      expect(
        formatCallDuration(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '01:02:03',
      );
      expect(
        formatCallDuration(const Duration(hours: 12, minutes: 0, seconds: 9)),
        '12:00:09',
      );
    });
  });
}
