import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/router/nav_history.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../shared/widgets/date_range_bar.dart';
import '../application/leave_controller.dart';
import '../domain/models.dart';
import '../../home/presentation/nav_destinations.dart';
import '../../auth/application/auth_controller.dart';

final _dateFmt = DateFormat('d MMM yyyy');

/// HR module's Leaves screen. Four tabs:
///   • Applications - every leave application (HR/admin) with date + status
///                    filtering; tapping one opens a read-only detail sheet.
///   • Requests     - leave requests waiting on the signed-in user; the same
///                    detail sheet with Approve / Reject (reason) actions.
///   • Comp-Off     - compensatory-leave requests waiting on the user, with the
///                    same approve/reject flow.
///   • WFH          - Work From Home requests waiting on the user, same flow.
/// This carries the same approval flow as the old Approval Requests screen
/// (Leave + Comp-Off), which has been removed in favour of this screen.
class LeaveManagementScreen extends StatelessWidget {
  const LeaveManagementScreen({
    super.key,
    this.initialTab = 0,
    this.initialStatus,
  });

  /// 0 = Applications, 1 = Requests, 2 = Comp-Off, 3 = WFH.
  final int initialTab;

  /// Optional starting status filter for the Applications tab, e.g. 'pending'
  /// (used by the HR dashboard "Pending Leaves" card).
  final String? initialStatus;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      initialIndex: initialTab.clamp(0, 3),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: const AppBackButton(),
          backgroundColor: AppColors.surfaceContainerLowest,
          title: const Text('Leaves'),
          actions: [
            Consumer(
              builder: (context, ref, _) =>
                  screenOn(
                    ref.watch(authControllerProvider).profile,
                    'hr.leave_rules',
                  )
                  ? IconButton(
                      tooltip: 'Leave policy',
                      icon: Icon(
                        Icons.rule_folder_outlined,
                        color: AppColors.primary,
                      ),
                      onPressed: () => context.push(Routes.leaveNoticeRules),
                    )
                  : const SizedBox.shrink(),
            ),
            Consumer(
              builder: (context, ref, _) => IconButton(
                tooltip: 'Refresh',
                icon: Icon(Icons.refresh, color: AppColors.primary),
                onPressed: () {
                  ref.invalidate(allLeaveApplicationsProvider);
                  ref.invalidate(pendingLeaveApprovalsProvider);
                  ref.invalidate(allCompOffProvider);
                  ref.invalidate(pendingWfhApprovalsProvider);
                },
              ),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Applications'),
              Tab(text: 'Requests'),
              Tab(text: 'Compensatory'),
              Tab(text: 'WFH'),
            ],
          ),
        ),
        body: SafeArea(
          top: false,
          child: TabBarView(
            children: [
              _ApplicationsTab(initialStatus: initialStatus),
              const _RequestsTab(),
              const _CompOffTab(),
              const _WfhTab(),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Applications tab - all applications, filtered by date range + status
// ---------------------------------------------------------------------------
enum _StatusFilter { all, pending, approved, rejected }

extension _StatusFilterX on _StatusFilter {
  String get label => switch (this) {
    _StatusFilter.all => 'All',
    _StatusFilter.pending => 'Pending',
    _StatusFilter.approved => 'Approved',
    _StatusFilter.rejected => 'Rejected',
  };

  bool matches(LeaveStatus s) => switch (this) {
    _StatusFilter.all => true,
    _StatusFilter.pending => s == LeaveStatus.open,
    _StatusFilter.approved => s == LeaveStatus.approved,
    _StatusFilter.rejected => s == LeaveStatus.rejected,
  };
}

class _ApplicationsTab extends ConsumerStatefulWidget {
  const _ApplicationsTab({this.initialStatus});
  final String? initialStatus;

  @override
  ConsumerState<_ApplicationsTab> createState() => _ApplicationsTabState();
}

class _ApplicationsTabState extends ConsumerState<_ApplicationsTab>
    with AutomaticKeepAliveClientMixin {
  late DateTime _from;
  late DateTime _to;
  late _StatusFilter _filter;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // All-time by default so the list matches the dashboard's all-time KPI
    // counts; the "All" chip keeps this in one tap.
    final all = DateRangeBar.allTime();
    _from = all.from;
    _to = all.to;
    _filter = switch (widget.initialStatus) {
      'pending' => _StatusFilter.pending,
      'approved' => _StatusFilter.approved,
      'rejected' => _StatusFilter.rejected,
      _ => _StatusFilter.all,
    };
  }

  LeaveApplicationsRange get _range => (from: _from, to: _to);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final async = ref.watch(allLeaveApplicationsProvider(_range));
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        ref.invalidate(allLeaveApplicationsProvider(_range));
        await Future<void>.delayed(const Duration(milliseconds: 400));
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppDimens.screenPadding,
          AppDimens.md,
          AppDimens.screenPadding,
          AppDimens.xl,
        ),
        children: [
          DateRangeBar(
            from: _from,
            to: _to,
            showAll: true,
            onChanged: (f, t) => setState(() {
              _from = f;
              _to = t;
            }),
          ),
          const SizedBox(height: AppDimens.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final f in _StatusFilter.values) ...[
                  ChoiceChip(
                    label: Text(f.label),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
                  const SizedBox(width: AppDimens.sm),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppDimens.sm),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppDimens.xxxl),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(AppDimens.xl),
              child: Text(
                e is ApiException ? e.message : 'Could not load applications.',
                textAlign: TextAlign.center,
              ),
            ),
            data: (all) {
              final apps = all.where((a) => _filter.matches(a.status)).toList();
              if (apps.isEmpty) {
                return const _EmptyState(
                  icon: Icons.event_busy_outlined,
                  text: 'No leave applications in this range.',
                );
              }
              return Column(
                children: [
                  for (final a in apps)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppDimens.md),
                      child: _ApplicationCard(app: a),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({required this.app});
  final LeaveApplication app;

  @override
  Widget build(BuildContext context) {
    final title =
        (app.employeeName != null && app.employeeName!.trim().isNotEmpty)
        ? app.employeeName!
        : app.name;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        onTap: () => _showLeaveDetail(context, app.name),
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${app.leaveType} · ${_range(app.fromDate, app.toDate)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    // While pending, spell out which hop it is sitting at
                    // (manager vs HR) so oversight sees more than just "Pending".
                    if (app.status == LeaveStatus.open &&
                        app.stageLabel != null &&
                        app.stageLabel!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        app.stageLabel!.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppDimens.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _days(app.totalLeaveDays),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _LeaveStatusChip(status: app.status),
                ],
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: AppColors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Requests tab - leave requests waiting on this user
// ---------------------------------------------------------------------------
class _RequestsTab extends ConsumerStatefulWidget {
  const _RequestsTab();

  @override
  ConsumerState<_RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends ConsumerState<_RequestsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final async = ref.watch(pendingLeaveApprovalsProvider);
    return RefreshIndicator(
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
                e is ApiException ? e.message : 'Could not load requests.',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        data: (items) {
          if (items.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                _EmptyState(
                  icon: Icons.inbox_outlined,
                  text: 'No leave requests waiting on you.',
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
            itemBuilder: (_, i) => _RequestCard(item: items[i]),
          );
        },
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.item});
  final PendingLeaveApproval item;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        onTap: () => _showLeaveDetail(context, item.name, approval: item),
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
                  _HatBadge(asHr: item.asHr),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${item.leaveType} · ${_range(item.fromDate, item.toDate)}'
                ' · ${_days(item.totalLeaveDays)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (item.stageLabel.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  item.stageLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: AppDimens.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () =>
                      _showLeaveDetail(context, item.name, approval: item),
                  icon: const Icon(Icons.event_note_outlined, size: 18),
                  label: const Text('View & action'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Comp-Off tab - management list of every comp-off request (HR/admin see all,
// others their own), filtered by date range + status. Tapping one opens the
// detail sheet, which still offers approve/reject while the request is pending.
// ---------------------------------------------------------------------------
class _CompOffTab extends ConsumerStatefulWidget {
  const _CompOffTab();

  @override
  ConsumerState<_CompOffTab> createState() => _CompOffTabState();
}

class _CompOffTabState extends ConsumerState<_CompOffTab>
    with AutomaticKeepAliveClientMixin {
  late DateTime _from;
  late DateTime _to;
  _StatusFilter _filter = _StatusFilter.all;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final all = DateRangeBar.allTime();
    _from = all.from;
    _to = all.to;
  }

  LeaveApplicationsRange get _range => (from: _from, to: _to);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final async = ref.watch(allCompOffProvider(_range));
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        ref.invalidate(allCompOffProvider(_range));
        await Future<void>.delayed(const Duration(milliseconds: 400));
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppDimens.screenPadding,
          AppDimens.md,
          AppDimens.screenPadding,
          AppDimens.xl,
        ),
        children: [
          DateRangeBar(
            from: _from,
            to: _to,
            showAll: true,
            onChanged: (f, t) => setState(() {
              _from = f;
              _to = t;
            }),
          ),
          const SizedBox(height: AppDimens.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final f in _StatusFilter.values) ...[
                  ChoiceChip(
                    label: Text(f.label),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
                  const SizedBox(width: AppDimens.sm),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppDimens.sm),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppDimens.xxxl),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(AppDimens.xl),
              child: Text(
                e is ApiException ? e.message : 'Could not load requests.',
                textAlign: TextAlign.center,
              ),
            ),
            data: (all) {
              final items = all
                  .where((r) => _filter.matches(r.status))
                  .toList();
              if (items.isEmpty) {
                return const _EmptyState(
                  icon: Icons.event_available_outlined,
                  text: 'No comp-off requests in this range.',
                );
              }
              return Column(
                children: [
                  for (final r in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppDimens.md),
                      child: _CompOffCard(item: r),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CompOffCard extends StatelessWidget {
  const _CompOffCard({required this.item});
  final CompOffApplication item;

  @override
  Widget build(BuildContext context) {
    final title = item.employeeName.trim().isNotEmpty
        ? item.employeeName
        : item.name;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        onTap: () => _showCompOffDetail(context, item),
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Worked · ${_range(item.workFromDate, item.workEndDate)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    if (item.status == LeaveStatus.open &&
                        item.stageLabel.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.stageLabel.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppDimens.sm),
              _LeaveStatusChip(status: item.status),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: AppColors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Leave detail sheet (read-only, or with approve/reject when [approval] is set)
// ---------------------------------------------------------------------------
/// Public entry so other screens (e.g. My Leave) can open the same read-only
/// leave detail sheet — tap a request anywhere and get the identical modal.
Future<void> showLeaveDetailSheet(BuildContext context, String name) =>
    _showLeaveDetail(context, name);

Future<void> _showLeaveDetail(
  BuildContext context,
  String name, {
  PendingLeaveApproval? approval,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceContainerLowest,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppDimens.radiusXl),
      ),
    ),
    builder: (_) => _LeaveDetailSheet(name: name, approval: approval),
  );
}

class _LeaveDetailSheet extends ConsumerStatefulWidget {
  const _LeaveDetailSheet({required this.name, this.approval});
  final String name;
  final PendingLeaveApproval? approval;

  @override
  ConsumerState<_LeaveDetailSheet> createState() => _LeaveDetailSheetState();
}

class _LeaveDetailSheetState extends ConsumerState<_LeaveDetailSheet> {
  bool _busy = false;

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  bool _opening = false;

  /// Proof files are stored private, which a plain URL can't open from an
  /// external browser (no auth token → 403). So we download the bytes through
  /// the authenticated API and open the saved copy in the device's default
  /// viewer (image/PDF). If no app can handle it, fall back to the OS share
  /// sheet so the file is never a dead end.
  Future<void> _open(LeaveAttachment a) async {
    if (_opening) return;
    setState(() => _opening = true);
    _toast('Opening ${a.fileName}…');
    try {
      final path = await ref
          .read(leaveRepositoryProvider)
          .downloadAttachment(a.name);
      final result = await OpenFilex.open(path);
      if (result.type != ResultType.done) {
        // No viewer available for this type — hand it to the share sheet.
        await SharePlus.instance.share(
          ShareParams(files: [XFile(path)], fileNameOverrides: [a.fileName]),
        );
      }
    } on ApiException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('Could not open the file.');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _act(String action) async {
    final item = widget.approval;
    if (item == null) return;
    String? reason;
    if (action == 'Reject') {
      reason = await _askReason(context, item.employeeName);
      if (reason == null) return; // cancelled
    } else {
      final ok = await _confirmApprove(
        context,
        '${item.employeeName} — ${item.leaveType}, '
        '${_days(item.totalLeaveDays)}.',
      );
      if (!ok) return;
    }

    setState(() => _busy = true);
    try {
      await ref
          .read(leaveControllerProvider.notifier)
          .actOnApplication(name: widget.name, action: action, reason: reason);
      ref.invalidate(allLeaveApplicationsProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      _toast(
        action == 'Approve'
            ? 'Approved. ${item.asHr ? "The leave is now approved." : "Sent to HR."}'
            : 'Rejected.',
      );
    } on ApiException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('Could not update the request.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(leaveApplicationDetailProvider(widget.name));
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: async.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppDimens.xxxl),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(AppDimens.xl),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    e is ApiException
                        ? e.message
                        : 'Could not load the application.',
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          data: (d) => _content(context, d),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, LeaveApplicationDetail d) {
    final theme = Theme.of(context);
    final canAct = widget.approval != null;
    final who = (d.employeeName != null && d.employeeName!.trim().isNotEmpty)
        ? d.employeeName!
        : d.name;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header with title, status and close cross.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.lg,
            AppDimens.md,
            AppDimens.sm,
            0,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      who,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      d.leaveType,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimens.sm),
              _LeaveStatusChip(status: d.status),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        const Divider(height: AppDimens.md),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.lg,
              0,
              AppDimens.lg,
              AppDimens.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (d.stageLabel != null && d.stageLabel!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppDimens.sm),
                    child: Text(
                      d.stageLabel!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                _InfoRow(label: 'Dates', value: _range(d.fromDate, d.toDate)),
                _InfoRow(label: 'Days', value: _days(d.totalLeaveDays)),
                if (d.halfDay)
                  _InfoRow(
                    label: 'Half day',
                    value: d.halfDayDate != null
                        ? _dateFmt.format(d.halfDayDate!)
                        : 'Yes',
                  ),
                if (d.leaveApproverName != null &&
                    d.leaveApproverName!.trim().isNotEmpty)
                  _InfoRow(label: 'Approver', value: d.leaveApproverName!),
                if (d.postingDate != null)
                  _InfoRow(
                    label: 'Applied on',
                    value: _dateFmt.format(d.postingDate!),
                  ),
                if (d.description != null &&
                    d.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: AppDimens.md),
                  Text('Reason', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    d.description!.trim(),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
                if (d.attachments.isNotEmpty) ...[
                  const Divider(height: AppDimens.xl),
                  Text('Attachments', style: theme.textTheme.titleSmall),
                  const SizedBox(height: AppDimens.sm),
                  for (final a in d.attachments)
                    _AttachmentRow(attachment: a, onOpen: () => _open(a)),
                ],
              ],
            ),
          ),
        ),
        if (canAct) _ActionBar(busy: _busy, onAct: _act),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// The applicant's own comp-off / WFH requests (My Leave). Same modal as a leave
// request, read-only: the list row already carries every field to show.
// ---------------------------------------------------------------------------
Future<void> showMyCompOffDetailSheet(BuildContext context, CompOffSummary r) =>
    _showRequestSheet(
      context,
      title: r.leaveType.isEmpty ? 'Compensatory Off' : r.leaveType,
      subtitle: 'Compensatory Off request',
      status: r.status,
      stageLabel: r.stageLabel,
      rows: [
        _InfoRow(
          label: 'Worked on',
          value: _range(r.workFromDate, r.workEndDate),
        ),
        if (r.halfDay) const _InfoRow(label: 'Half day', value: 'Yes'),
        if (r.postingDate != null)
          _InfoRow(label: 'Applied on', value: _dateFmt.format(r.postingDate!)),
        _InfoRow(label: 'Request ID', value: r.name),
      ],
      reason: r.reason,
    );

Future<void> showMyWfhDetailSheet(BuildContext context, WfhSummary r) =>
    _showRequestSheet(
      context,
      title: 'Work From Home',
      subtitle: 'WFH request',
      status: r.status,
      stageLabel: r.stageLabel,
      rows: [
        _InfoRow(label: 'Dates', value: _range(r.fromDate, r.toDate)),
        if (r.halfDay)
          _InfoRow(
            label: 'Half day',
            value: r.halfDayDate != null
                ? _dateFmt.format(r.halfDayDate!)
                : 'Yes',
          ),
        if (r.postingDate != null)
          _InfoRow(label: 'Applied on', value: _dateFmt.format(r.postingDate!)),
        _InfoRow(label: 'Request ID', value: r.name),
      ],
      reason: r.explanation,
    );

Future<void> _showRequestSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
  required LeaveStatus status,
  required String stageLabel,
  required List<Widget> rows,
  String? reason,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceContainerLowest,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppDimens.radiusXl),
      ),
    ),
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.88,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.lg,
                  AppDimens.md,
                  AppDimens.sm,
                  0,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppDimens.sm),
                    _LeaveStatusChip(status: status),
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: AppDimens.md),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.lg,
                    0,
                    AppDimens.lg,
                    AppDimens.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (stageLabel.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppDimens.sm),
                          child: Text(
                            stageLabel,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ...rows,
                      if (reason != null && reason.trim().isNotEmpty) ...[
                        const SizedBox(height: AppDimens.md),
                        Text('Reason', style: theme.textTheme.titleSmall),
                        const SizedBox(height: 4),
                        Text(reason.trim(), style: theme.textTheme.bodyMedium),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Comp-off detail sheet. Read-only oversight for any request; approve/reject
// is offered only while the request is still pending (the server also enforces
// that only HR/admin may act, and never on their own request).
// ---------------------------------------------------------------------------
Future<void> _showCompOffDetail(BuildContext context, CompOffApplication item) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceContainerLowest,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppDimens.radiusXl),
      ),
    ),
    builder: (_) => _CompOffDetailSheet(item: item),
  );
}

class _CompOffDetailSheet extends ConsumerStatefulWidget {
  const _CompOffDetailSheet({required this.item});
  final CompOffApplication item;

  @override
  ConsumerState<_CompOffDetailSheet> createState() =>
      _CompOffDetailSheetState();
}

class _CompOffDetailSheetState extends ConsumerState<_CompOffDetailSheet> {
  bool _busy = false;

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _act(String action) async {
    final item = widget.item;
    String? reason;
    if (action == 'Reject') {
      reason = await _askReason(context, item.employeeName);
      if (reason == null) return; // cancelled
    } else {
      final ok = await _confirmApprove(
        context,
        '${item.employeeName} worked on '
        '${_range(item.workFromDate, item.workEndDate)}.',
      );
      if (!ok) return;
    }

    setState(() => _busy = true);
    try {
      await ref
          .read(leaveControllerProvider.notifier)
          .actOnCompOff(name: item.name, action: action, reason: reason);
      ref.invalidate(allCompOffProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      _toast(action == 'Approve' ? 'Approved. Comp-off granted.' : 'Rejected.');
    } on ApiException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('Could not update the request.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;
    // Approve/reject only matters while the request is still open; closed ones
    // are view-only. The server re-checks the acting user's rights regardless.
    final canAct = item.status == LeaveStatus.open;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.lg,
                AppDimens.md,
                AppDimens.sm,
                0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.employeeName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          item.leaveType.isEmpty ? 'Comp-Off' : item.leaveType,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppDimens.sm),
                  _LeaveStatusChip(status: item.status),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: AppDimens.md),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.lg,
                  0,
                  AppDimens.lg,
                  AppDimens.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (item.stageLabel.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppDimens.sm),
                        child: Text(
                          item.stageLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    _InfoRow(
                      label: 'Worked on',
                      value: _range(item.workFromDate, item.workEndDate),
                    ),
                    if (item.halfDay)
                      const _InfoRow(label: 'Half day', value: 'Yes'),
                    if (item.reason != null &&
                        item.reason!.trim().isNotEmpty) ...[
                      const SizedBox(height: AppDimens.md),
                      Text('Reason', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(
                        item.reason!.trim(),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (canAct) _ActionBar(busy: _busy, onAct: _act),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// WFH tab - Work From Home requests waiting on this user
// ---------------------------------------------------------------------------
class _WfhTab extends ConsumerStatefulWidget {
  const _WfhTab();

  @override
  ConsumerState<_WfhTab> createState() => _WfhTabState();
}

class _WfhTabState extends ConsumerState<_WfhTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final async = ref.watch(pendingWfhApprovalsProvider);
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        ref.invalidate(pendingWfhApprovalsProvider);
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
                e is ApiException ? e.message : 'Could not load requests.',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        data: (items) {
          if (items.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                _EmptyState(
                  icon: Icons.inbox_outlined,
                  text: 'No WFH requests waiting on you.',
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
            itemBuilder: (_, i) => _WfhCard(item: items[i]),
          );
        },
      ),
    );
  }
}

class _WfhCard extends StatelessWidget {
  const _WfhCard({required this.item});
  final PendingWfhApproval item;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        onTap: () => _showWfhDetail(context, item),
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
                  _HatBadge(asHr: item.asHr),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'WFH · ${_range(item.fromDate, item.toDate)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (item.stageLabel.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  item.stageLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: AppDimens.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _showWfhDetail(context, item),
                  icon: const Icon(Icons.home_work_outlined, size: 18),
                  label: const Text('View & action'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showWfhDetail(BuildContext context, PendingWfhApproval item) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceContainerLowest,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppDimens.radiusXl),
      ),
    ),
    builder: (_) => _WfhDetailSheet(item: item),
  );
}

class _WfhDetailSheet extends ConsumerStatefulWidget {
  const _WfhDetailSheet({required this.item});
  final PendingWfhApproval item;

  @override
  ConsumerState<_WfhDetailSheet> createState() => _WfhDetailSheetState();
}

class _WfhDetailSheetState extends ConsumerState<_WfhDetailSheet> {
  bool _busy = false;

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _act(String action) async {
    final item = widget.item;
    String? reason;
    if (action == 'Reject') {
      reason = await _askReason(context, item.employeeName);
      if (reason == null) return; // cancelled
    } else {
      final ok = await _confirmApprove(
        context,
        '${item.employeeName} — WFH ${_range(item.fromDate, item.toDate)}.',
      );
      if (!ok) return;
    }

    setState(() => _busy = true);
    try {
      await ref
          .read(leaveControllerProvider.notifier)
          .actOnWfh(name: item.name, action: action, reason: reason);
      if (!mounted) return;
      Navigator.of(context).pop();
      _toast(
        action == 'Approve'
            ? 'Approved. ${item.asHr ? "WFH marked." : "Sent to HR."}'
            : 'Rejected.',
      );
    } on ApiException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('Could not update the request.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.lg,
                AppDimens.md,
                AppDimens.sm,
                0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.employeeName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Work From Home',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppDimens.sm),
                  _HatBadge(asHr: item.asHr),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: AppDimens.md),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.lg,
                  0,
                  AppDimens.lg,
                  AppDimens.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (item.stageLabel.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppDimens.sm),
                        child: Text(
                          item.stageLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    _InfoRow(
                      label: 'Dates',
                      value: _range(item.fromDate, item.toDate),
                    ),
                    if (item.halfDay)
                      const _InfoRow(label: 'Half day', value: 'Yes'),
                    if (item.explanation != null &&
                        item.explanation!.trim().isNotEmpty) ...[
                      const SizedBox(height: AppDimens.md),
                      Text('Reason', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(
                        item.explanation!.trim(),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            _ActionBar(busy: _busy, onAct: _act),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small shared widgets
// ---------------------------------------------------------------------------
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.busy, required this.onAct});
  final bool busy;
  final Future<void> Function(String action) onAct;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.lg,
        0,
        AppDimens.lg,
        AppDimens.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: busy ? null : () => onAct('Reject'),
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
              onPressed: busy ? null : () => onAct('Approve'),
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
    );
  }
}

class _HatBadge extends StatelessWidget {
  const _HatBadge({required this.asHr});
  final bool asHr;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.secondaryFixed,
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      ),
      child: Text(
        asHr ? 'As HR' : 'Your team',
        style: TextStyle(
          color: AppColors.onSecondaryFixedVariant,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentRow extends StatelessWidget {
  const _AttachmentRow({required this.attachment, required this.onOpen});
  final LeaveAttachment attachment;
  final VoidCallback onOpen;

  IconData get _icon {
    final n = attachment.fileName.toLowerCase();
    if (n.endsWith('.pdf')) return Icons.picture_as_pdf_outlined;
    if (n.endsWith('.png') ||
        n.endsWith('.jpg') ||
        n.endsWith('.jpeg') ||
        n.endsWith('.webp') ||
        n.endsWith('.gif')) {
      return Icons.image_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.xs),
      child: Material(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.sm),
            child: Row(
              children: [
                Icon(_icon, color: AppColors.primary),
                const SizedBox(width: AppDimens.sm),
                Expanded(
                  child: Text(
                    attachment.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Icon(
                  Icons.open_in_new,
                  size: 18,
                  color: AppColors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LeaveStatusChip extends StatelessWidget {
  const _LeaveStatusChip({required this.status});
  final LeaveStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      LeaveStatus.approved => ('Approved', const Color(0xFF15803D)),
      LeaveStatus.rejected => ('Rejected', const Color(0xFFB42318)),
      LeaveStatus.cancelled => ('Cancelled', const Color(0xFF6B7280)),
      LeaveStatus.open => ('Pending', const Color(0xFFB54708)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppDimens.xxxl),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.onSurfaceVariant),
          const SizedBox(height: AppDimens.md),
          Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Approve confirm + reject reason dialogs
// ---------------------------------------------------------------------------
Future<bool> _confirmApprove(BuildContext context, String message) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Approve this request?'),
      content: Text(message),
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
  return ok == true;
}

/// Returns the trimmed reason, or null if the user cancelled.
Future<String?> _askReason(BuildContext context, String who) {
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
              '$who will see this reason.',
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

// ---------------------------------------------------------------------------
// Formatting helpers
// ---------------------------------------------------------------------------
String _range(DateTime from, DateTime to) {
  if (from.year == to.year && from.month == to.month && from.day == to.day) {
    return _dateFmt.format(from);
  }
  return '${_dateFmt.format(from)} – ${_dateFmt.format(to)}';
}

String _days(double d) {
  final s = d == d.roundToDouble() ? d.toStringAsFixed(0) : d.toString();
  return '$s ${d == 1 ? 'day' : 'days'}';
}
