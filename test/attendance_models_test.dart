import 'package:flutter_test/flutter_test.dart';
import 'package:tcb_portal/features/attendance/domain/models.dart';

void main() {
  group('LogType', () {
    test('maps to/from Frappe values', () {
      expect(LogType.inn.api, 'IN');
      expect(LogType.out.api, 'OUT');
      expect(LogTypeX.fromApi('OUT'), LogType.out);
      expect(LogTypeX.fromApi('in'), LogType.inn);
      expect(LogTypeX.fromApi(null), LogType.inn);
    });
  });

  group('AttendanceContext.fromJson', () {
    test('parses context with locations and logs', () {
      final ctx = AttendanceContext.fromJson({
        'employee': 'HR-EMP-00066',
        'employee_name': 'ESS Tester',
        'suggested_log_type': 'IN',
        'locations': [
          {
            'name': 'TCB HQ (Test)',
            'location_name': 'TCB HQ (Test)',
            'latitude': 28.6139,
            'longitude': 77.2090,
            'radius': 500,
            'company': 'THINKCOMPBON INFOTECH PRIVATE LIMITED',
          }
        ],
        'todays_logs': [
          {
            'name': 'EMP-CKIN-0001',
            'log_type': 'IN',
            'time': '2026-05-29 09:30:00',
            'latitude': 28.614,
            'longitude': 77.2091,
          }
        ],
      });

      expect(ctx.employee, 'HR-EMP-00066');
      expect(ctx.suggestedLogType, LogType.inn);
      expect(ctx.locations.single.radius, 500);
      expect(ctx.todaysLogs.single.logType, LogType.inn);
      expect(ctx.todaysLogs.single.time.hour, 9);
    });

    test('tolerates missing optional fields', () {
      final ctx = AttendanceContext.fromJson({
        'employee': 'HR-EMP-1',
        'suggested_log_type': 'OUT',
      });
      expect(ctx.locations, isEmpty);
      expect(ctx.todaysLogs, isEmpty);
      expect(ctx.suggestedLogType, LogType.out);
    });
  });

  group('PendingCheckin', () {
    test('round-trips through json for the offline queue', () {
      final original = PendingCheckin(
        id: '123',
        latitude: 28.6139,
        longitude: 77.2090,
        logType: LogType.out,
        capturedAt: DateTime.parse('2026-05-29T09:30:00.000Z'),
        selfiePath: '/tmp/selfie.jpg',
      );
      final copy = PendingCheckin.fromJson(original.toJson());
      expect(copy.id, '123');
      expect(copy.logType, LogType.out);
      expect(copy.latitude, 28.6139);
      expect(copy.selfiePath, '/tmp/selfie.jpg');
      expect(copy.capturedAt.toUtc(), original.capturedAt.toUtc());
    });
  });
}
