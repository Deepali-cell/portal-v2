import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:integration_test/integration_test.dart';

import 'package:tcb_portal/app.dart';
import 'package:tcb_portal/features/attendance/data/attendance_repository.dart';

/// End-to-end against the live backend: login -> Leave -> apply (Leave Without
/// Pay, needs no allocation) -> request appears. Run with
/// --dart-define=TCB_BIOMETRIC_LOCK=false.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Hive.initFlutter();
    if (!Hive.isBoxOpen(AttendanceRepository.boxName)) {
      await Hive.openBox(AttendanceRepository.boxName);
    }
  });

  testWidgets('employee can submit a leave request', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: TcbPortalApp()));

    await _waitForAny(
      tester,
      [find.byType(TextField), find.text('Quick actions')],
      seconds: 30,
    );
    if (_present(find.byType(TextField)) &&
        !_present(find.text('Quick actions'))) {
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'ess.test@tcb.local');
      await tester.enterText(fields.at(1), const String.fromEnvironment('TCB_TEST_PASSWORD'));
      await _tap(tester, find.widgetWithText(ElevatedButton, 'Sign in'));
      await _waitFor(tester, find.text('Quick actions'), seconds: 40);
    }
    expect(find.text('Quick actions'), findsOneWidget);

    // Open the Leave screen.
    await _tap(tester, find.text('Leave'));
    await _waitFor(tester, find.text('Balances'), seconds: 30);
    expect(find.text('My requests'), findsOneWidget);

    // Open the apply sheet.
    await _tap(tester, find.widgetWithText(FloatingActionButton, 'Apply'));
    await _waitFor(tester, find.text('Apply for leave'), seconds: 10);

    // Pick leave type "Leave Without Pay" (no allocation needed).
    await _tap(tester, find.byType(DropdownButtonFormField<String>));
    await _waitFor(tester, find.text('Leave Without Pay').last, seconds: 10);
    await _tap(tester, find.text('Leave Without Pay').last);

    // Accept today's date for both From and To via the date pickers.
    await _tap(tester, find.widgetWithText(InputDecorator, 'From'));
    await _waitFor(tester, find.text('OK'), seconds: 10);
    await _tap(tester, find.text('OK'));

    // Submit.
    await _tap(tester, find.widgetWithText(ElevatedButton, 'Submit request'));

    // Either the confirmation snackbar or the new request card confirms success.
    await _waitForAny(
      tester,
      [find.textContaining('submitted'), find.textContaining('Pending')],
      seconds: 40,
    );
    expect(
      _present(find.textContaining('submitted')) ||
          _present(find.textContaining('Pending')),
      isTrue,
      reason: 'leave request was accepted by the server',
    );
  });
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
