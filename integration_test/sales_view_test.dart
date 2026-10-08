import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:integration_test/integration_test.dart';

import 'package:tcb_portal/app.dart';
import 'package:tcb_portal/features/attendance/data/attendance_repository.dart';

/// Proves permission-gated navigation: a sales user (Sales User/Manager) sees
/// the CRM tiles (Leads, Deals) in addition to the employee features.
/// Run with --dart-define=TCB_BIOMETRIC_LOCK=false.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Hive.initFlutter();
    if (!Hive.isBoxOpen(AttendanceRepository.boxName)) {
      await Hive.openBox(AttendanceRepository.boxName);
    }
  });

  testWidgets('sales user sees Leads and Deals tiles', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: TcbPortalApp()));

    await _waitForAny(
      tester,
      [find.byType(TextField), find.text('Quick actions')],
      seconds: 30,
    );

    // If a previous session is signed in, sign out first.
    if (_present(find.text('Quick actions'))) {
      await _tap(tester, find.byIcon(Icons.logout));
      await _waitFor(tester, find.text('Sign out'), seconds: 10);
      await _tap(tester, find.widgetWithText(TextButton, 'Sign out'));
      await _waitFor(tester, find.byType(TextField), seconds: 20);
    }

    // Sign in as the sales user.
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'sales.test@tcb.local');
    await tester.enterText(fields.at(1), const String.fromEnvironment('TCB_TEST_PASSWORD'));
    await _tap(tester, find.widgetWithText(ElevatedButton, 'Sign in'));
    await _waitFor(tester, find.text('Quick actions'), seconds: 40);

    // Employee features + CRM features all present for sales.
    expect(find.text('Leads'), findsOneWidget, reason: 'sales sees Leads');
    expect(find.text('Deals'), findsOneWidget, reason: 'sales sees Deals');
    expect(find.text('Timesheet'), findsOneWidget);
    expect(find.text('Check in / out'), findsOneWidget);
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
  await t.tap(f.first);
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
