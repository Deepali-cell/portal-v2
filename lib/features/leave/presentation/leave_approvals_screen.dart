import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../application/leave_controller.dart';
import '../domain/models.dart';

final _dateFmt = DateFormat('d MMM yyyy');
final _dateShort = DateFormat('d MMM');

/// Leave requests waiting on the signed in user.
///
/// Two hops land here. A reporting manager sees their own team's requests, and
/// HR sees everything their managers have already cleared. Someone who is both
/// sees both sets, with each row saying which hat it is asking them to wear.
class LeaveApprovalsScreen extends ConsumerStatefulWidget {
  const LeaveApprovalsScreen({super.key});

  @override
  ConsumerState<LeaveApprovalsScreen> createState() =>
      _LeaveApprovalsScreenState();
}

class _LeaveApprovalsScreenState extends ConsumerState<LeaveApprovalsScreen> {
  String? _busyOn;

  Future<void> _act(PendingLeaveApproval item, String action) async {
    String? reason;
    if (action == 'Reject') {
      reason = await _askReason(item);
      if (reason == null) return;
    } else {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Approve this request?'),
          content: Text(
            '${item.employeeName} has asked for ${_days(item.totalLeaveDays)} '
            'of ${item.leaveType}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Approve'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => _busyOn = item.name);
    try {
      await ref
          .read(leaveControllerProvider.notifier)
          .actOnApplication(name: item.name, action: action, reason: reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            action == 'Approve'
                ? 'Approved. ${item.asHr ? "The request is now closed." : "Sent to HR."}'
                : 'Rejected.',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update the request.')),
      );
    } finally {
      if (mounted) setState(() => _busyOn = null);
    }
  }

  Future<String?> _askReason(PendingLeaveApproval item) {
    final ctrl = TextEditingController();
    String? error;
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Reject this request?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${item.employeeName} will see this reason.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: AppDimens.md),
              TextField(
                controller: ctrl,
                autofocus: true,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Reason',
                  hintText: 'Required, at least 4 characters',
                  errorText: error,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final v = ctrl.text.trim();
                if (v.length < 4) {
                  setDialogState(() => error = 'At least 4 characters.');
                  return;
                }
                Navigator.pop(ctx, v);
              },
              child: const Text('Reject'),
            ),
          ],
        ),
      ),
    );
  }

  static String _days(double d) =>
      d == d.truncate() ? '${d.toInt()} day${d == 1 ? "" : "s"}' : '$d days';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(pendingLeaveApprovalsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        title: const Text('Leave approvals'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () => ref.invalidate(pendingLeaveApprovalsProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(pendingLeaveApprovalsProvider);
          await Future<void>.delayed(const Duration(milliseconds: 400));
        },
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Padding(
                padding: const EdgeInsets.all(AppDimens.xl),
                child: Text(
                  e is ApiException
                      ? e.message
                      : 'Could not load the approvals.',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppDimens.xxxl),
                    child: Column(
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 40,
                          color: AppColors.onSurfaceVariant,
                        ),
                        const SizedBox(height: AppDimens.md),
                        Text(
                          'Nothing waiting on you.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppDimens.screenPadding,
                AppDimens.md,
                AppDimens.screenPadding,
                AppDimens.xl,
              ),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppDimens.md),
              itemBuilder: (_, i) => _ApprovalCard(
                item: items[i],
                busy: _busyOn == items[i].name,
                onApprove: () => _act(items[i], 'Approve'),
                onReject: () => _act(items[i], 'Reject'),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({
    required this.item,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  final PendingLeaveApproval item;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final range = item.fromDate == item.toDate
        ? _dateFmt.format(item.fromDate)
        : '${_dateShort.format(item.fromDate)} to ${_dateFmt.format(item.toDate)}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.employeeName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryFixed,
                    borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  ),
                  child: Text(
                    item.asHr ? 'As HR' : 'Your team',
                    style: TextStyle(
                      color: AppColors.onSecondaryFixedVariant,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${item.leaveType} · ${_LeaveApprovalsScreenState._days(item.totalLeaveDays)}'
              '${item.halfDay ? " · half day" : ""}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 2),
            Text(range, style: Theme.of(context).textTheme.labelLarge),
            if (item.description != null &&
                item.description!.trim().isNotEmpty) ...[
              const SizedBox(height: AppDimens.sm),
              Text(
                item.description!.trim(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: AppDimens.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                      ),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: AppDimens.md),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy ? null : onApprove,
                    icon: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: const Text('Approve'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.secondaryContainer,
                      foregroundColor: AppColors.onSecondaryContainer,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
