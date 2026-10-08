import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/router/nav_history.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/ui/app_message_dialog.dart';
import '../../auth/application/auth_controller.dart';
import '../data/records_repository.dart';
import '../domain/descriptor.dart';
import 'dynamic_form_screen.dart';

/// Generic list for any allowlisted doctype, configured by a [RecordDescriptor].
/// Visible only when the user can read the doctype (nav gated by descriptor.cap);
/// the Add button follows the ERP-native create permission.
class RecordListScreen extends ConsumerStatefulWidget {
  const RecordListScreen({super.key, required this.descriptor});
  final RecordDescriptor descriptor;

  @override
  ConsumerState<RecordListScreen> createState() => _RecordListScreenState();
}

class _RecordListScreenState extends ConsumerState<RecordListScreen> {
  List<Map<String, dynamic>>? _rows;
  Object? _error;
  bool _loading = true;
  Timer? _debounce;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await ref
          .read(recordsRepositoryProvider)
          .listDocs(widget.descriptor.doctype, search: _search);
      if (mounted) setState(() => _rows = rows);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearch(String q) {
    _search = q;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.descriptor;
    final profile = ref.watch(authControllerProvider.select((s) => s.profile));
    final canCreate = profile?.canDo(d.cap, 'create') ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(d.title),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh, color: AppColors.primary),
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () async {
                final created = await Navigator.of(context).push<String>(
                  MaterialPageRoute(
                    builder: (_) => DynamicFormScreen(
                        doctype: d.doctype, title: d.title),
                  ),
                );
                if (created != null) _load();
              },
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimens.md),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search ${d.title.toLowerCase()}…',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: _onSearch,
            ),
          ),
          Expanded(child: _body(d)),
        ],
      ),
    );
  }

  Widget _body(RecordDescriptor d) {
    if (_loading && _rows == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _rows == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(friendlyMessageFor(_error!).message,
                  textAlign: TextAlign.center),
              const SizedBox(height: AppDimens.md),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    final rows = _rows ?? const [];
    if (rows.isEmpty) {
      return Center(child: Text('No ${d.title.toLowerCase()} found'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        itemCount: rows.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final row = rows[i];
          final title = _str(row[d.titleField]).isNotEmpty
              ? _str(row[d.titleField])
              : _str(row['name']);
          final sub = d.subtitleFields
              .map((f) => _str(row[f]))
              .where((s) => s.isNotEmpty)
              .join('  •  ');
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primaryContainer,
              child: Text(
                title.isNotEmpty ? title[0].toUpperCase() : '?',
                style: TextStyle(color: AppColors.onPrimaryContainer),
              ),
            ),
            title: Text(title),
            subtitle: sub.isEmpty ? null : Text(sub),
            onTap: () => context.push(
              Routes.recordDetail,
              extra: RecordArgs(d, _str(row['name'])),
            ),
          );
        },
      ),
    );
  }

  String _str(dynamic v) => v == null ? '' : v.toString();
}
