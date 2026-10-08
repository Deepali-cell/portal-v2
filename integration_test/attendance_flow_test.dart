import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:integration_test/integration_test.dart';

import 'package:tcb_portal/app.dart';
import 'package:tcb_portal/core/location/location_service.dart';
import 'package:tcb_portal/features/attendance/data/attendance_repository.dart';

/// End-to-end against the live Frappe v16 bench:
/// login -> home -> attendance -> geofenced check-in.
///
/// GPS is faked (fixed position inside the "TCB HQ (Test)" geofence) via a
/// Riverpod override, so the test is deterministic and never hits a native
/// location-permission dialog. Everything else is real, including the server
/// geofence validation. Run with --dart-define=TCB_BIOMETRIC_LOCK=false.
///
/// Requires the bench up on 127.0.0.1:8001 and user ess.test@tcb.local (password via --dart-define=TCB_TEST_PASSWORD=...).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Hive.initFlutter();
    if (!Hive.isBoxOpen(AttendanceRepository.boxName)) {
      await Hive.openBox(AttendanceRepository.boxName);
    }
  });

  testWidgets('employee can check in from within the geofence',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          locationServiceProvider.overrideWithValue(_FakeLocationService()),
        ],
        child: const TcbPortalApp(),
      ),
    );

    await _waitForAny(
      tester,
      [find.byType(TextField), find.text('Quick actions')],
      seconds: 30,
    );

    final needsLogin = _present(find.byType(TextField)) &&
        !_present(find.text('Quick actions'));
    if (needsLogin) {
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'ess.test@tcb.local');
      await tester.enterText(fields.at(1), const String.fromEnvironment('TCB_TEST_PASSWORD'));
      await _tap(tester, find.widgetWithText(ElevatedButton, 'Sign in'));
      await _waitFor(tester, find.text('Quick actions'), seconds: 40);
    }

    expect(find.text('Quick actions'), findsOneWidget,
        reason: 'should reach the home dashboard');

    await _tap(tester, find.text('Check in / out'));
    await _waitFor(tester, find.text('Record attendance'), seconds: 30);

    // Faked GPS sits on the HQ coordinates → geofence resolves to "Inside".
    await _waitFor(tester, find.textContaining('Inside'), seconds: 20);
    expect(find.textContaining('Inside'), findsWidgets,
        reason: 'faked device location is inside the seeded geofence');

    final checkIn = find.widgetWithText(ElevatedButton, 'Check in');
    final checkOut = find.widgetWithText(ElevatedButton, 'Check out');
    final button = _present(checkIn) ? checkIn : checkOut;
    await _tap(tester, button);

    // Live backend confirms with "… recorded at TCB HQ (Test) (… m)".
    await _waitFor(tester, find.textContaining('recorded'), seconds: 30);
    expect(find.textContaining('recorded'), findsWidgets,
        reason: 'server confirmed the geofenced check-in');
  });
}

/// Returns a fixed fix inside the "TCB HQ (Test)" geofence (28.6139, 77.2090).
class _FakeLocationService extends LocationService {
  @override
  Future<Position> currentPosition() async => Position(
        latitude: 28.6139,
        longitude: 77.2090,
        timestamp: DateTime.now(),
        accuracy: 5,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
}

bool _present(Finder f) => f.evaluate().isNotEmpty;

Future<void> _pump(WidgetTester t, [int ms = 500]) async {
  await t.pump();
  await t.pump(Duration(milliseconds: ms));
}

Future<void> _tap(WidgetTester t, Finder f) async {
  try {
    await t.ensureVisible(f);
  } catch (_) {}
  await t.tap(f);
  await _pump(t);
}

Future<void> _waitFor(WidgetTester t, Finder f, {int seconds = 20}) async {
  final deadline = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(deadline)) {
    await t.pump(const Duration(milliseconds: 300));
    if (f.evaluate().isNotEmpty) return;
  }
}

Future<void> _waitForAny(WidgetTester t, List<Finder> fs,
    {int seconds = 20}) async {
  final deadline = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(deadline)) {
    await t.pump(const Duration(milliseconds: 300));
    if (fs.any((f) => f.evaluate().isNotEmpty)) return;
  }
}
