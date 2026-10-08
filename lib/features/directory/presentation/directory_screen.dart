import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/router/nav_history.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../records/domain/descriptor.dart';
import '../application/directory_controller.dart';
import '../domain/models.dart';

class DirectoryScreen extends ConsumerStatefulWidget {
  const DirectoryScreen({super.key});

  @override
  ConsumerState<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends ConsumerState<DirectoryScreen> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(directoryControllerProvider.notifier).setSearch(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(directoryControllerProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(),
        backgroundColor: AppColors.surfaceContainerLowest,
        title: const Text('Directory'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () =>
                ref.read(directoryControllerProvider.notifier).reload(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppDimens.screenPadding,
                AppDimens.md,
                AppDimens.screenPadding,
                AppDimens.sm),
            child: TextField(
              controller: _search,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: 'Search by name, role, department, or number',
                prefixIcon: Icon(Icons.search,
                    color: AppColors.onSurfaceVariant),
                filled: true,
                fillColor: AppColors.surfaceContainerLowest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                  borderSide:
                      BorderSide(color: AppColors.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                  borderSide:
                      BorderSide(color: AppColors.outlineVariant),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.md, vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _Err(
                msg: e is ApiException
                    ? e.message
                    : 'Could not load the directory.',
                onRetry: () =>
                    ref.read(directoryControllerProvider.notifier).reload(),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimens.xl),
                      child: Text(
                          _search.text.isEmpty
                              ? 'No employees found.'
                              : 'No matches for "${_search.text}".',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(directoryControllerProvider.notifier).reload(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                        AppDimens.screenPadding,
                        AppDimens.sm,
                        AppDimens.screenPadding,
                        AppDimens.xl),
                    children: [
                      Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < list.length; i++) ...[
                              if (i > 0)
                                Divider(
                                    height: 1,
                                    indent: 76,
                                    color: AppColors.outlineVariant),
                              _Row(entry: list[i]),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.entry});
  final DirectoryEntry entry;

  Future<void> _call(BuildContext context) async {
    final number = entry.cellNumber;
    if (number == null || number.isEmpty) return;
    final cleaned = number.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri(scheme: 'tel', path: cleaned);
    if (!await launchUrl(uri)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start the call.')));
    }
  }

  Future<void> _email(BuildContext context) async {
    final addr = entry.companyEmail;
    if (addr == null || addr.isEmpty) return;
    final uri = Uri(scheme: 'mailto', path: addr);
    if (!await launchUrl(uri)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the mail app.')));
    }
  }

  void _openDetail(BuildContext context) {
    final desc = recordRegistry['hr_employee'];
    if (desc == null) return;
    context.push(Routes.recordDetail, extra: RecordArgs(desc, entry.name));
  }

  @override
  Widget build(BuildContext context) {
    final subtitle =
        [entry.designation, entry.department].where((s) => s != null && s.isNotEmpty).join(' · ');
    return InkWell(
      onTap: () => _openDetail(context),
      child: Padding(
      padding: const EdgeInsets.fromLTRB(
          AppDimens.md, AppDimens.md, AppDimens.sm, AppDimens.md),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.secondaryFixed,
              borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            ),
            alignment: Alignment.center,
            child: Text(entry.initials,
                style: TextStyle(
                    color: AppColors.onSecondaryFixed,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
          ),
          const SizedBox(width: AppDimens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.employeeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w600)),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
                if (entry.companyEmail != null &&
                    entry.companyEmail!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(entry.companyEmail!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.onSecondaryFixedVariant)),
                ],
                if (entry.cellNumber != null &&
                    entry.cellNumber!.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(entry.cellNumber!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.onSurfaceVariant)),
                ],
              ],
            ),
          ),
          if (entry.companyEmail != null && entry.companyEmail!.isNotEmpty)
            IconButton(
              tooltip: 'Email',
              onPressed: () => _email(context),
              icon: Icon(Icons.mail_outline, color: AppColors.primary),
            ),
          if (entry.cellNumber != null && entry.cellNumber!.isNotEmpty)
            IconButton(
              tooltip: 'Call',
              onPressed: () => _call(context),
              icon: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.tertiaryFixed,
                  borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.call,
                    color: AppColors.onTertiaryFixedVariant, size: 20),
              ),
            ),
        ],
      ),
      ),
    );
  }
}

class _Err extends StatelessWidget {
  const _Err({required this.msg, required this.onRetry});
  final String msg;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.xl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 40, color: AppColors.error),
            const SizedBox(height: AppDimens.md),
            Text(msg, textAlign: TextAlign.center),
            const SizedBox(height: AppDimens.lg),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ]),
        ),
      );
}
