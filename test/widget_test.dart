import 'package:flutter_test/flutter_test.dart';
import 'package:tcb_portal/features/auth/domain/profile.dart';

void main() {
  group('Profile', () {
    test('parses user with linked employee', () {
      final profile = Profile.fromJson({
        'user': 'ess.test@tcb.local',
        'full_name': 'ESS Tester',
        'roles': ['Employee'],
        'employee': {
          'name': 'HR-EMP-00066',
          'employee_name': 'ESS Tester',
          'company': 'THINKCOMPBON INFOTECH PRIVATE LIMITED',
        },
      });

      expect(profile.user, 'ess.test@tcb.local');
      expect(profile.hasEmployee, isTrue);
      expect(profile.employee!.name, 'HR-EMP-00066');
      expect(profile.initials, 'ET');
    });

    test('round-trips through json', () {
      final original = Profile.fromJson({
        'user': 'a@b.com',
        'full_name': 'Alpha Beta',
        'roles': ['Employee'],
      });
      final copy = Profile.fromJson(original.toJson());
      expect(copy.fullName, 'Alpha Beta');
      expect(copy.hasEmployee, isFalse);
    });
  });
}
