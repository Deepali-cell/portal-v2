import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/router/app_router.dart';
import '../../call_detection/data/recording_repository.dart';
import '../../invoices/domain/models.dart' show InvoiceKind;
import '../../invoices/presentation/invoice_detail_screen.dart'
    show InvoiceDetailArgs;
import '../domain/models.dart';

/// Open the document the notification refers to.
///
/// Maps Frappe DocType to its mobile route. Returns true if a route was
/// pushed (or queued for async push), false if the notification has no
/// usable destination — in which case the caller falls back to just
/// marking it read.
///
/// For `Tcb Call Recording` we don't have a dedicated detail screen —
/// instead we fetch the recording's linked Lead/Deal and open that. The
/// Calls tab of the parent record renders the recording card with its
/// AI summary + suggested status.
///
/// Unknown DocTypes return false instead of guessing — better to do
/// nothing than to land the user on the wrong screen.
bool openNotificationTarget(
  BuildContext context,
  WidgetRef ref,
  NotificationItem item,
) {
  final docType = item.documentType;
  final docName = item.documentName;
  if (docType == null || docName == null || docName.isEmpty) return false;

  // Notifications sits on the ROOT navigator; the target detail routes
  // (leadDetail, dealDetail, invoiceDetail, etc.) live inside
  // StatefulShellBranch children. Using `context.push` from the root nav
  // onto a shell-branch route causes GoRouter's page-key reservation to
  // collide → Navigator asserts '!keyReservation.contains(key)' and the
  // app red-screens. `context.go` navigates the router state cleanly
  // (switches the shell to the right branch, opens the detail on top),
  // so back-swipe lands on the branch's list — the correct UX anyway
  // since the user came here through a notification, not through the
  // list.
  switch (docType) {
    case 'Leave Application':
      context.go(Routes.leaveDetail, extra: docName);
      return true;
    case 'Salary Slip':
      context.go(Routes.payslipDetail, extra: docName);
      return true;
    case 'Sales Invoice':
      context.go(
        Routes.invoiceDetail,
        extra: InvoiceDetailArgs(name: docName, kind: InvoiceKind.sales),
      );
      return true;
    case 'Purchase Invoice':
      context.go(
        Routes.invoiceDetail,
        extra: InvoiceDetailArgs(name: docName, kind: InvoiceKind.purchase),
      );
      return true;
    case 'Lead':
      context.go(Routes.leadDetail, extra: docName);
      return true;
    case 'Opportunity':
      context.go(Routes.dealDetail, extra: docName);
      return true;
    case 'Tcb Call Recording':
      _openRecordingLinked(context, ref, docName);
      return true;
    case 'Timesheet':
      context.go(Routes.timesheetDetail, extra: docName);
      return true;
    // DocTypes without a dedicated detail screen — land on the list.
    case 'Task':
      context.go(Routes.tasks);
      return true;
    case 'ToDo':
      context.go(Routes.tasks);
      return true;
    case 'Expense Claim':
      context.go(Routes.expenses);
      return true;
    case 'Payment Entry':
      context.go(Routes.invoices);
      return true;
    case 'Employee Checkin':
      context.go(Routes.time);
      return true;
    case 'Employee':
      context.go(Routes.directory);
      return true;
    default:
      return false;
  }
}

/// Fetch the Tcb Call Recording and navigate to its linked Lead/Deal.
/// If the recording is unlinked (no phone match + no contact match), we
/// surface a snackbar — better than a silent no-op.
Future<void> _openRecordingLinked(
  BuildContext context,
  WidgetRef ref,
  String recordingName,
) async {
  try {
    final repo = RecordingRepository(ref.read(dioProvider));
    final rec = await repo.get(recordingName);
    final dt = rec.referenceDoctype;
    final dn = rec.referenceDocname;
    if (!context.mounted) return;
    if (dt == 'Lead' && (dn ?? '').isNotEmpty) {
      context.go(Routes.leadDetail, extra: dn);
      return;
    }
    if (dt == 'Opportunity' && (dn ?? '').isNotEmpty) {
      context.go(Routes.dealDetail, extra: dn);
      return;
    }
    // Unlinked recording — friendly message so the tap isn't silent.
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text("Recording $recordingName isn't linked to a lead/deal "
          "yet. Check the Tcb Call Recording in the desk."),
      duration: const Duration(seconds: 4),
    ));
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("Couldn't open the recording. Please try again."),
    ));
  }
}
