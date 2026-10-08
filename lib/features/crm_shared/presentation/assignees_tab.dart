import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../application/providers.dart';
import '../domain/crm_ref.dart';
import '../domain/models.dart';

class AssigneesTab extends ConsumerWidget {
  const AssigneesTab({super.key, required this.crmRef});
  final CrmRef crmRef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(assigneesProvider(crmRef));
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.canvas,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Assign'),
        onPressed: () => _openPicker(context, ref),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(e is ApiException ? e.message : 'Could not load.'),
        ),
        data: (assignees) {
          if (assignees.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppDimens.xl),
                child: Text('No one assigned yet. Tap "Assign" to add someone.'),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(assigneesProvider(crmRef)),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                  AppDimens.screenPadding, AppDimens.screenPadding, AppDimens.screenPadding, 96),
              itemCount: assignees.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppDimens.sm),
              itemBuilder: (_, i) {
                final a = assignees[i];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.navy,
                      child: Text(
                        (a.fullName.isNotEmpty ? a.fullName[0] : '?').toUpperCase(),
                        style: TextStyle(
                            color: AppColors.canvas, fontWeight: FontWeight.w700),
                      ),
                    ),
                    title: Text(a.fullName),
                    subtitle: Text(a.user),
                    trailing: IconButton(
                      tooltip: 'Remove',
                      icon: Icon(Icons.close, color: AppColors.danger),
                      onPressed: () => _remove(context, ref, a),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, CrmAssignee a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unassign?'),
        content: Text('Remove ${a.fullName} from this record?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(crmCollabRepositoryProvider).removeAssignee(crmRef, a.user);
      ref.invalidate(assigneesProvider(crmRef));
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _openPicker(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXl)),
      ),
      builder: (_) => _UserPicker(crmRef: crmRef),
    );
  }
}

class _UserPicker extends ConsumerStatefulWidget {
  const _UserPicker({required this.crmRef});
  final CrmRef crmRef;
  @override
  ConsumerState<_UserPicker> createState() => _UserPickerState();
}

class _UserPickerState extends ConsumerState<_UserPicker> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<UserOption> _results = const [];
  bool _searching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String s) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _search(s));
  }

  Future<void> _search(String q) async {
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final users =
          await ref.read(crmCollabRepositoryProvider).searchUsers(q);
      if (!mounted) return;
      setState(() => _results = users);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _pick(UserOption u) async {
    try {
      await ref
          .read(crmCollabRepositoryProvider)
          .addAssignee(widget.crmRef, u.name);
      ref.invalidate(assigneesProvider(widget.crmRef));
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppDimens.xl, AppDimens.xl, AppDimens.xl, AppDimens.xl + bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            Text('Assign user',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppDimens.lg),
            TextField(
              controller: _query,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Search by name or email',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _onChanged,
            ),
            const SizedBox(height: AppDimens.md),
            Expanded(
              child: _searching
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!))
                      : _results.isEmpty
                          ? const Center(child: Text('No users.'))
                          : ListView.separated(
                              itemCount: _results.length,
                              separatorBuilder: (_, _) => const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final u = _results[i];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: AppColors.navyTint,
                                    child: Text(
                                      (u.fullName.isNotEmpty ? u.fullName[0] : '?').toUpperCase(),
                                      style: TextStyle(
                                          color: AppColors.navy,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  title: Text(u.fullName),
                                  subtitle: Text(u.name),
                                  onTap: () => _pick(u),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
