import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/ui/app_message_dialog.dart';
import '../../auth/application/auth_controller.dart';
import '../../crm_shared/application/providers.dart';
import '../../crm_shared/domain/crm_ref.dart';
import '../../projects/data/project_repository.dart';
import '../../purchase/data/purchase_repository.dart';
import '../../purchase/presentation/purchase_comparison_screen.dart';
import '../../manufacturing/data/manufacturing_repository.dart';
import '../../sales/data/sales_repository.dart';
import '../../tasks/application/task_controller.dart';
import '../../tasks/domain/models.dart';
import '../data/records_repository.dart';
import '../domain/descriptor.dart';
import '../domain/form_meta.dart';
import 'dynamic_form_screen.dart';

final _dateFmt = DateFormat('d MMM');

/// Generic detail view for an allowlisted doctype.
class RecordDetailScreen extends ConsumerStatefulWidget {
  const RecordDetailScreen({super.key, required this.args});
  final RecordArgs args;

  @override
  ConsumerState<RecordDetailScreen> createState() => _RecordDetailScreenState();
}

class _RecordDetailScreenState extends ConsumerState<RecordDetailScreen> {
  Map<String, dynamic>? _doc;
  Map<String, dynamic> _created = const {};
  // Full field metadata + saved values, so the detail can render every
  // populated field (and child tables) read-only without opening Edit.
  FormMeta? _meta;
  Map<String, dynamic>? _values;
  Object? _error;
  bool _loading = true;

  /// True if a downstream [targetDoctype] (draft or submitted) already exists
  /// for this record - so its "Create ..." button should hide.
  bool _made(String targetDoctype) =>
      (_created[targetDoctype]?['exists'] as num?)?.toInt() == 1;

  /// A sample name of the already-created [targetDoctype], for the message.
  String _madeSample(String targetDoctype) =>
      _str(_created[targetDoctype]?['sample']);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(recordsRepositoryProvider);
      final doc = await repo.getDoc(
        widget.args.descriptor.doctype,
        widget.args.name,
      );
      // Best-effort: which next-step docs already exist. Never block the screen.
      Map<String, dynamic> created = const {};
      try {
        created = await repo.getCreatedTargets(
          widget.args.descriptor.doctype,
          widget.args.name,
        );
      } catch (_) {}
      // Best-effort: full field meta + saved values, so every populated field
      // (and child table) shows read-only here instead of only inside Edit.
      FormMeta? meta;
      Map<String, dynamic>? values;
      try {
        meta = await repo.getFormMeta(widget.args.descriptor.doctype);
        values = await repo.getFormValues(
          widget.args.descriptor.doctype,
          widget.args.name,
        );
      } catch (_) {}
      if (mounted) {
        setState(() {
          _doc = doc;
          _created = created;
          _meta = meta;
          _values = values;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.args.descriptor;
    final profile = ref.watch(authControllerProvider.select((s) => s.profile));
    final canEdit = profile?.canDo(d.cap, 'write') ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(d.title),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh, color: AppColors.primary),
            onPressed: _load,
          ),
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                final saved = await Navigator.of(context).push<String>(
                  MaterialPageRoute(
                    builder: (_) => DynamicFormScreen(
                      doctype: d.doctype,
                      title: d.title,
                      name: widget.args.name,
                      initialValues: _doc ?? const {},
                    ),
                  ),
                );
                if (saved != null) _load();
              },
            ),
        ],
      ),
      body: _body(d),
    );
  }

  Widget _body(RecordDescriptor d) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.lg),
          child: Text('$_error', textAlign: TextAlign.center),
        ),
      );
    }
    final doc = _doc ?? const {};
    final header = _str(doc[d.titleField]).isNotEmpty
        ? _str(doc[d.titleField])
        : _str(doc['name']);
    return ListView(
      padding: const EdgeInsets.all(AppDimens.md),
      children: [
        Text(header, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: AppDimens.xs),
        Text(_str(doc['name']),
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.onSurfaceVariant)),
        const SizedBox(height: AppDimens.lg),
        ..._detailBody(d),
        // Work Order / Job Card carry their own bespoke submit/lifecycle
        // sections below, so skip the generic one to avoid duplicate buttons.
        if (d.doctype != 'Work Order' && d.doctype != 'Job Card') ...[
          const SizedBox(height: AppDimens.lg),
          _LifecycleSection(
            doctype: d.doctype,
            name: widget.args.name,
            docstatus: (doc['docstatus'] as num?)?.toInt() ?? 0,
            status: _str(doc['status']),
            onChanged: _load,
            onDeleted: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop('deleted');
              }
            },
          ),
        ],
        if (d.doctype == 'Project') ...[
          const SizedBox(height: AppDimens.lg),
          _ProjectTeamSection(project: widget.args.name),
          const SizedBox(height: AppDimens.lg),
          _ProjectTasksSection(project: widget.args.name),
        ],
        if (d.doctype == 'Material Request' &&
            _str(doc['material_request_type']) == 'Purchase' &&
            _str(doc['status']) != 'Draft' &&
            _str(doc['status']) != 'Cancelled') ...[
          const SizedBox(height: AppDimens.lg),
          _MaterialRequestRfqSection(materialRequest: widget.args.name),
        ],
        // ---- Purchase chain: next-step conversion buttons ----
        if (d.doctype == 'Request for Quotation' &&
            !{'Draft', 'Cancelled'}.contains(_str(doc['status']))) ...[
          const SizedBox(height: AppDimens.lg),
          _PurchaseConversionSection(
              doctype: d.doctype,
              name: widget.args.name,
              created: _created,
              onChanged: _load),
        ],
        if (d.doctype == 'Supplier Quotation' &&
            !{'Draft', 'Cancelled', 'Expired', 'Lost', 'Stopped'}
                .contains(_str(doc['status']))) ...[
          const SizedBox(height: AppDimens.lg),
          _PurchaseConversionSection(
              doctype: d.doctype,
              name: widget.args.name,
              created: _created,
              onChanged: _load),
        ],
        if (d.doctype == 'Purchase Order' &&
            {'To Receive and Bill', 'To Receive'}
                .contains(_str(doc['status']))) ...[
          const SizedBox(height: AppDimens.lg),
          _PurchaseConversionSection(
              doctype: d.doctype,
              name: widget.args.name,
              created: _created,
              onChanged: _load),
        ],
        if (d.doctype == 'Purchase Receipt' &&
            !{'Draft', 'Cancelled'}.contains(_str(doc['status']))) ...[
          const SizedBox(height: AppDimens.lg),
          _PurchaseConversionSection(
              doctype: d.doctype,
              name: widget.args.name,
              created: _created,
              onChanged: _load),
        ],
        if (d.doctype == 'Quotation' &&
            !{'Draft', 'Cancelled', 'Lost', 'Expired'}
                .contains(_str(doc['status']))) ...[
          const SizedBox(height: AppDimens.lg),
          _SalesConversionSection(
            status: _str(doc['status']),
            // A newly created Sales Order is a DRAFT, so the Quotation stays
            // "Open" until it is submitted. Detect the SO directly (draft too)
            // so the button hides the moment the SO exists.
            doneNote: _made('Sales Order')
                ? 'Sales Order already created (${_madeSample('Sales Order')}). '
                    'The next steps are now available on that Sales Order.'
                : null,
            actions: _made('Sales Order')
                ? const []
                : [
                    _SalesAction(
                      label: 'Create Sales Order',
                      targetKey: 'sales_order',
                      run: (repo) =>
                          repo.createSoFromQuotation(widget.args.name),
                    ),
                  ],
            onDone: _load,
          ),
        ],
        if (d.doctype == 'Sales Order' &&
            !{'Draft', 'Cancelled', 'Closed'}.contains(_str(doc['status']))) ...[
          const SizedBox(height: AppDimens.lg),
          _SalesConversionSection(
            status: _str(doc['status']),
            // Hide each button once that next-step doc exists (draft counts).
            doneNote: (_made('Delivery Note') || _made('Sales Invoice'))
                ? [
                    if (_made('Delivery Note'))
                      'Delivery Note already created (${_madeSample('Delivery Note')}).',
                    if (_made('Sales Invoice'))
                      'Invoice already created (${_madeSample('Sales Invoice')}).',
                  ].join(' ')
                : null,
            actions: [
              if (!_made('Delivery Note'))
                _SalesAction(
                  label: 'Create Delivery Note',
                  targetKey: 'sales_delivery',
                  run: (repo) =>
                      repo.createDeliveryNoteFromSo(widget.args.name),
                ),
              if (!_made('Sales Invoice'))
                _SalesAction(
                  label: 'Create Invoice',
                  targetKey: null,
                  run: (repo) => repo.createInvoiceFromSo(widget.args.name),
                ),
            ],
            onDone: _load,
          ),
        ],
        if (d.doctype == 'Delivery Note' &&
            !{'Draft', 'Cancelled'}.contains(_str(doc['status']))) ...[
          const SizedBox(height: AppDimens.lg),
          _SalesConversionSection(
            status: _str(doc['status']),
            // Hide the invoice button once an invoice exists (draft counts).
            doneNote: _made('Sales Invoice')
                ? 'Invoice already created (${_madeSample('Sales Invoice')}). '
                    'You can still create a Return if needed.'
                : null,
            actions: [
              if (!_made('Sales Invoice'))
                _SalesAction(
                  label: 'Create Invoice',
                  targetKey: null,
                  run: (repo) =>
                      repo.createInvoiceFromDeliveryNote(widget.args.name),
                ),
              _SalesAction(
                label: 'Create Return',
                targetKey: 'sales_delivery',
                run: (repo) => repo.createSalesReturn(widget.args.name),
              ),
            ],
            onDone: _load,
          ),
        ],
        // ---- Manufacturing chain: next-step conversion buttons ----
        if (d.doctype == 'BOM' &&
            (doc['is_active'] == 1 || doc['is_active'] == true)) ...[
          const SizedBox(height: AppDimens.lg),
          _ManufacturingConversionSection(
            actions: [
              _ManufacturingAction(
                label: 'Create Work Order',
                targetKey: 'mfg_work_order',
                run: (repo) => repo.createWorkOrderFromBom(widget.args.name),
              ),
            ],
          ),
        ],
        if (d.doctype == 'Work Order' && _str(doc['status']) == 'Draft') ...[
          const SizedBox(height: AppDimens.lg),
          _WorkOrderSubmitSection(
              workOrder: widget.args.name, onSubmitted: _load),
        ],
        if (d.doctype == 'Work Order' &&
            {'Not Started', 'In Process'}.contains(_str(doc['status']))) ...[
          const SizedBox(height: AppDimens.lg),
          _WorkOrderJobCardsSection(workOrder: widget.args.name),
          const SizedBox(height: AppDimens.lg),
          // Stock check drives the next step: short -> Material Request only;
          // in stock -> Transfer Material only; transferred -> Manufacture only.
          _WorkOrderStockSection(
            workOrder: widget.args.name,
            orderQty: double.tryParse('${doc['qty']}') ?? 0,
            transferredQty:
                double.tryParse('${doc['material_transferred_for_manufacturing']}') ??
                    0,
          ),
        ],
        if (d.doctype == 'Job Card') ...[
          const SizedBox(height: AppDimens.lg),
          _JobCardShopFloorSection(jobCard: widget.args.name),
        ],
      ],
    );
  }

  // Layout / non-data field types that carry no value to display.
  static const Set<String> _skipFieldTypes = {
    'Section Break', 'Column Break', 'Tab Break', 'HTML', 'Button',
    'Fold', 'Heading', 'Image', 'Signature', 'Barcode',
  };

  /// Every populated field of the record, read-only. Prefers the full form
  /// meta + saved values (so all filled fields and child tables show without
  /// opening Edit); falls back to the descriptor's curated detailFields when
  /// meta/values could not be loaded (e.g. offline or a permission gap).
  List<Widget> _detailBody(RecordDescriptor d) {
    final meta = _meta;
    final values = _values;
    if (meta == null || values == null) {
      final doc = _doc ?? const {};
      return [for (final f in d.detailFields) _row(f, doc[f.key])];
    }
    final rows = <Widget>[];
    final shown = <String>{};
    for (final f in meta.fields) {
      if (_skipFieldTypes.contains(f.fieldtype)) continue;
      // name + the title are already shown in the header above.
      if (f.fieldname == 'name' || f.fieldname == d.titleField) continue;
      final v = values[f.fieldname];
      if (f.isTable) {
        final child = _childTable(f, v);
        if (child != null) {
          rows.add(child);
          shown.add(f.fieldname);
        }
        continue;
      }
      final text = _formatValue(f.fieldtype, v);
      if (text.isEmpty) continue;
      rows.add(_kv(f.label, text));
      shown.add(f.fieldname);
    }
    // Add any curated detail field the editable meta didn't cover (e.g. a
    // read-only status), so this never shows less than before.
    final doc = _doc ?? const {};
    for (final f in d.detailFields) {
      if (shown.contains(f.key) || f.key == d.titleField || f.key == 'name') {
        continue;
      }
      rows.add(_row(f, doc[f.key]));
    }
    // Never leave the screen blank if everything resolved empty.
    if (rows.isEmpty) {
      return [for (final f in d.detailFields) _row(f, doc[f.key])];
    }
    return rows;
  }

  String _formatValue(String fieldtype, dynamic v) {
    if (v == null) return '';
    if (fieldtype == 'Check') return (v == 1 || v == true) ? 'Yes' : 'No';
    return v.toString().trim();
  }

  Widget _kv(String label, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: TextStyle(color: AppColors.onSurfaceVariant)),
          ),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  /// Relative width weight for a child-table column, so free-text columns get
  /// more room than short codes/dates/numbers.
  int _colFlex(String fieldtype) => switch (fieldtype) {
        'Small Text' ||
        'Text' ||
        'Long Text' ||
        'Text Editor' ||
        'Data' =>
          3,
        _ => 2,
      };

  /// A child table rendered as a real grid: a shaded header row of column
  /// labels, then one striped row per entry. Empty columns (no value in any
  /// row) are dropped so the grid stays tight. Returns null when the table has
  /// no usable rows.
  Widget? _childTable(FieldMeta f, dynamic v) {
    if (v is! List || v.isEmpty) return null;
    final allCols = f.childFields
        .where((c) => !_skipFieldTypes.contains(c.fieldtype))
        .toList();
    if (allCols.isEmpty) return null;

    // Materialise the rows once, then keep only columns that carry a value in
    // at least one row (so a table never shows an all-blank column).
    final maps = <Map>[for (final row in v) if (row is Map) row];
    final cols = allCols
        .where((c) => maps.any(
            (row) => _formatValue(c.fieldtype, row[c.fieldname]).isNotEmpty))
        .toList();
    if (cols.isEmpty) return null;

    final dataRows = <List<String>>[];
    for (final row in maps) {
      final cells = [
        for (final c in cols) _formatValue(c.fieldtype, row[c.fieldname])
      ];
      if (cells.every((t) => t.isEmpty)) continue;
      dataRows.add(cells);
    }
    if (dataRows.isEmpty) return null;

    Widget cell(String text, int flex, {required bool header, required bool numeric}) =>
        Expanded(
          flex: flex,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.sm, vertical: AppDimens.xs),
            child: Text(
              text,
              textAlign: numeric ? TextAlign.right : TextAlign.left,
              style: TextStyle(
                fontSize: 13,
                height: 1.3,
                fontWeight: header ? FontWeight.w700 : FontWeight.w500,
                color: header
                    ? AppColors.onSurfaceVariant
                    : AppColors.onSurface,
              ),
            ),
          ),
        );

    bool isNumeric(String t) => switch (t) {
          'Int' || 'Float' || 'Currency' || 'Percent' => true,
          _ => false,
        };

    final headerRow = Container(
      color: AppColors.surfaceContainer,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final c in cols)
            cell(c.label, _colFlex(c.fieldtype),
                header: true, numeric: isNumeric(c.fieldtype)),
        ],
      ),
    );

    final body = <Widget>[];
    for (var i = 0; i < dataRows.length; i++) {
      final cells = dataRows[i];
      body.add(Container(
        color: i.isOdd
            ? AppColors.surfaceContainerLowest
            : Colors.transparent,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var j = 0; j < cols.length; j++)
              cell(cells[j], _colFlex(cols[j].fieldtype),
                  header: false, numeric: isNumeric(cols[j].fieldtype)),
          ],
        ),
      ));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(f.label,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(width: AppDimens.xs),
              Text('(${dataRows.length})',
                  style: TextStyle(
                      color: AppColors.onSurfaceVariant, fontSize: 12)),
            ],
          ),
          const SizedBox(height: AppDimens.xs),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Column(
              children: [
                headerRow,
                Divider(height: 1, color: AppColors.outlineVariant),
                for (var i = 0; i < body.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, color: AppColors.outlineVariant),
                  body[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(FieldSpec f, dynamic value) {
    final text = f.isBool
        ? ((value == 1 || value == true) ? 'Yes' : 'No')
        : _str(value);
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(f.label,
                style: TextStyle(color: AppColors.onSurfaceVariant)),
          ),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  String _str(dynamic v) => v == null ? '' : v.toString();
}

/// Universal document lifecycle actions driven by ERPNext docstatus:
/// draft (0) -> Submit + Delete, submitted (1) -> Cancel, cancelled (2) -> note.
/// Non-submittable doctypes only ever show Delete. All backend calls enforce
/// the matching ERPNext permission (submit/cancel/delete) and link checks.
class _LifecycleSection extends ConsumerStatefulWidget {
  const _LifecycleSection({
    required this.doctype,
    required this.name,
    required this.docstatus,
    required this.status,
    required this.onChanged,
    required this.onDeleted,
  });

  final String doctype;
  final String name;
  final int docstatus;
  final String status;

  /// Refresh the detail after submit/cancel so the stage and forward actions update.
  final VoidCallback onChanged;

  /// Called after a successful delete (the record no longer exists).
  final VoidCallback onDeleted;

  /// Doctypes this app works with that are submittable in ERPNext. A draft of
  /// these can be submitted; anything else only offers Delete.
  static const Set<String> _submittable = {
    'Quotation',
    'Sales Order',
    'Delivery Note',
    'Sales Invoice',
    'Purchase Order',
    'Purchase Receipt',
    'Purchase Invoice',
    'Material Request',
    'Request for Quotation',
    'Supplier Quotation',
    'Stock Entry',
    'Work Order',
    'Job Card',
    'BOM',
    'Payment Entry',
    'Shift Assignment',
    'Leave Policy',
    'Leave Policy Assignment',
    'Leave Allocation',
    'Holiday List Assignment',
  };

  @override
  ConsumerState<_LifecycleSection> createState() => _LifecycleSectionState();
}

class _LifecycleSectionState extends ConsumerState<_LifecycleSection> {
  bool _busy = false;

  bool get _isSubmittable =>
      _LifecycleSection._submittable.contains(widget.doctype);

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m, maxLines: 6, overflow: TextOverflow.ellipsis),
        duration: const Duration(seconds: 6)));
  }

  Future<bool> _confirm(String title, String message, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(recordsRepositoryProvider)
          .submitDoc(widget.doctype, widget.name);
      _snack('Submitted successfully.');
      widget.onChanged();
    } catch (e) {
      if (mounted) await showFriendlyError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    if (!await _confirm('Cancel this document?',
        'This document will be cancelled. Are you sure?', 'Cancel it')) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(recordsRepositoryProvider)
          .cancelDoc(widget.doctype, widget.name);
      _snack('Cancelled successfully.');
      widget.onChanged();
    } catch (e) {
      if (mounted) await showFriendlyError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    if (!await _confirm('Delete this record?',
        'This record will be permanently deleted. Are you sure?', 'Delete it')) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(recordsRepositoryProvider)
          .deleteDoc(widget.doctype, widget.name);
      _snack('Deleted successfully.');
      widget.onDeleted();
    } catch (e) {
      if (mounted) await showFriendlyError(context, e);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ds = widget.docstatus;
    final buttons = <Widget>[];

    if (ds == 0) {
      if (_isSubmittable) {
        buttons.add(FilledButton.icon(
          onPressed: _busy ? null : _submit,
          icon: const Icon(Icons.check),
          label: const Text('Submit'),
        ));
      }
      buttons.add(OutlinedButton.icon(
        onPressed: _busy ? null : _delete,
        icon: Icon(Icons.delete_outline, color: AppColors.error),
        label: Text('Delete', style: TextStyle(color: AppColors.error)),
      ));
    } else if (ds == 1) {
      buttons.add(OutlinedButton.icon(
        onPressed: _busy ? null : _cancel,
        icon: Icon(Icons.cancel_outlined, color: AppColors.error),
        label: Text('Cancel', style: TextStyle(color: AppColors.error)),
      ));
    } else {
      // Cancelled - allow removing the record entirely.
      buttons.add(OutlinedButton.icon(
        onPressed: _busy ? null : _delete,
        icon: Icon(Icons.delete_outline, color: AppColors.error),
        label: Text('Delete', style: TextStyle(color: AppColors.error)),
      ));
    }

    final stageLabel = ds == 0
        ? 'Draft'
        : ds == 2
            ? 'Cancelled'
            : (widget.status.isEmpty ? 'Submitted' : widget.status);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Document',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.sm, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  ),
                  child: Text(stageLabel,
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.sm),
            Wrap(spacing: AppDimens.sm, runSpacing: AppDimens.sm, children: buttons),
          ],
        ),
      ),
    );
  }
}

/// Project team ("Assign Projects"): who this project is assigned to, with
/// add/remove. Separate from the generic edit form because `users` is a
/// child table Frappe's list query can't select (see project_repository.dart).
class _ProjectTeamSection extends ConsumerStatefulWidget {
  const _ProjectTeamSection({required this.project});
  final String project;

  @override
  ConsumerState<_ProjectTeamSection> createState() => _ProjectTeamSectionState();
}

class _ProjectTeamSectionState extends ConsumerState<_ProjectTeamSection> {
  List<ProjectMember>? _team;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final team =
          await ref.read(projectRepositoryProvider).getTeam(widget.project);
      if (mounted) {
        setState(() {
          _team = team;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _addMember() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _UserSearchSheet(),
    );
    if (picked == null) return;
    try {
      await ref.read(projectRepositoryProvider).addMember(widget.project, picked);
      _load();
    } catch (e) {
      if (mounted) _snack('$e');
    }
  }

  Future<void> _removeMember(String user) async {
    try {
      await ref.read(projectRepositoryProvider).removeMember(widget.project, user);
      _load();
    } catch (e) {
      if (mounted) _snack('$e');
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m, maxLines: 6, overflow: TextOverflow.ellipsis),
        duration: const Duration(seconds: 6)));

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Team',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                TextButton.icon(
                  onPressed: _addMember,
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                  label: const Text('Assign'),
                ),
              ],
            ),
            if (_error != null)
              Text('$_error', style: const TextStyle(color: AppColors.error)),
            if (_team == null && _error == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppDimens.sm),
                child: Center(child: CircularProgressIndicator()),
              )
            else if ((_team ?? const []).isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppDimens.sm),
                child: Text('Nobody assigned yet',
                    style: TextStyle(color: AppColors.onSurfaceVariant)),
              )
            else
              for (final m in _team!)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primaryContainer,
                    child: Text(
                      m.fullName.isNotEmpty ? m.fullName[0].toUpperCase() : '?',
                      style: TextStyle(color: AppColors.onPrimaryContainer),
                    ),
                  ),
                  title: Text(m.fullName),
                  subtitle: Text(m.user),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => _removeMember(m.user),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// Project tasks: every Task under this project, any status/assignee, with
/// quick create/status-change/assign. Reuses the bespoke Task feature's
/// repository - Task keeps its own richer screen for "my tasks" elsewhere.
class _ProjectTasksSection extends ConsumerStatefulWidget {
  const _ProjectTasksSection({required this.project});
  final String project;

  @override
  ConsumerState<_ProjectTasksSection> createState() => _ProjectTasksSectionState();
}

class _ProjectTasksSectionState extends ConsumerState<_ProjectTasksSection> {
  List<TaskItem>? _tasks;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final tasks = await ref
          .read(taskRepositoryProvider)
          .listByProject(widget.project);
      if (mounted) {
        setState(() {
          _tasks = tasks;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m, maxLines: 6, overflow: TextOverflow.ellipsis),
        duration: const Duration(seconds: 6)));

  Future<void> _addTask() async {
    final subject = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _NewTaskSubjectSheet(),
    );
    if (subject == null || subject.trim().isEmpty) return;
    try {
      await ref
          .read(taskRepositoryProvider)
          .create(subject: subject.trim(), project: widget.project);
      _load();
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    }
  }

  Future<void> _changeStatus(TaskItem task) async {
    const statuses = ['Open', 'Working', 'Pending Review', 'Completed', 'Cancelled'];
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(AppDimens.lg),
              child: Text('Set status', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            for (final s in statuses)
              ListTile(
                title: Text(s),
                trailing: s == task.status ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, s),
              ),
          ],
        ),
      ),
    );
    if (picked != null && picked != task.status) {
      try {
        await ref.read(taskRepositoryProvider).setStatus(task.name, picked);
        _load();
      } on ApiException catch (e) {
        if (mounted) _snack(e.message);
      }
    }
  }

  Future<void> _assign(TaskItem task) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _UserSearchSheet(),
    );
    if (picked == null) return;
    try {
      await ref.read(taskRepositoryProvider).assign(task.name, picked);
      _load();
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Tasks',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                TextButton.icon(
                  onPressed: _addTask,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add task'),
                ),
              ],
            ),
            if (_error != null)
              Text('$_error', style: const TextStyle(color: AppColors.error)),
            if (_tasks == null && _error == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppDimens.sm),
                child: Center(child: CircularProgressIndicator()),
              )
            else if ((_tasks ?? const []).isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppDimens.sm),
                child: Text('No tasks under this project yet',
                    style: TextStyle(color: AppColors.onSurfaceVariant)),
              )
            else
              for (final t in _tasks!)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(t.subject),
                  subtitle: Text(
                    [
                      t.status,
                      t.priority,
                      if (t.expEndDate != null) 'Due ${_dateFmt.format(t.expEndDate!)}',
                      if (t.assignees.isNotEmpty) 'Assigned: ${t.assignees.join(', ')}',
                    ].join('  •  '),
                  ),
                  onTap: () => _changeStatus(t),
                  trailing: IconButton(
                    tooltip: 'Assign',
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    onPressed: () => _assign(t),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// Minimal "subject only" sheet for quickly adding a task under a project.
class _NewTaskSubjectSheet extends StatefulWidget {
  const _NewTaskSubjectSheet();
  @override
  State<_NewTaskSubjectSheet> createState() => _NewTaskSubjectSheetState();
}

class _NewTaskSubjectSheetState extends State<_NewTaskSubjectSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(AppDimens.xl, AppDimens.xl, AppDimens.xl,
          AppDimens.xl + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('New task', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppDimens.lg),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Subject'),
            onSubmitted: (v) => Navigator.of(context).pop(v),
          ),
          const SizedBox(height: AppDimens.lg),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

/// Material Request -> RFQ conversion. Lists RFQs already raised against this
/// MR and lets the user raise a new one by picking suppliers to invite -
/// ERPNext's own make_request_for_quotation() maps over the pending items.
class _MaterialRequestRfqSection extends ConsumerStatefulWidget {
  const _MaterialRequestRfqSection({required this.materialRequest});
  final String materialRequest;

  @override
  ConsumerState<_MaterialRequestRfqSection> createState() =>
      _MaterialRequestRfqSectionState();
}

class _MaterialRequestRfqSectionState
    extends ConsumerState<_MaterialRequestRfqSection> {
  List<Map<String, dynamic>>? _rfqs;
  Object? _error;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rfqs = await ref
          .read(purchaseRepositoryProvider)
          .rfqsForMaterialRequest(widget.materialRequest);
      if (mounted) {
        setState(() {
          _rfqs = rfqs;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m, maxLines: 6, overflow: TextOverflow.ellipsis),
        duration: const Duration(seconds: 6)));

  Future<void> _createRfq() async {
    final suppliers = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _SupplierMultiSelectSheet(),
    );
    if (suppliers == null || suppliers.isEmpty) return;

    setState(() => _creating = true);
    try {
      final name = await ref
          .read(purchaseRepositoryProvider)
          .createRfqFromMaterialRequest(widget.materialRequest, suppliers);
      if (!mounted) return;
      _snack('RFQ created: $name');
      _load();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RecordDetailScreen(
            args: RecordArgs(recordRegistry['purchase_rfq']!, name),
          ),
        ),
      );
    } catch (e) {
      if (mounted) _snack("Couldn't complete. $e");
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('RFQs',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                TextButton.icon(
                  onPressed: _creating ? null : _createRfq,
                  icon: _creating
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add, size: 18),
                  label: const Text('Create RFQ'),
                ),
              ],
            ),
            if (_error != null)
              Text('$_error', style: const TextStyle(color: AppColors.error)),
            if (_rfqs == null && _error == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppDimens.sm),
                child: Center(child: CircularProgressIndicator()),
              )
            else if ((_rfqs ?? const []).isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppDimens.sm),
                child: Text('No RFQ raised yet',
                    style: TextStyle(color: AppColors.onSurfaceVariant)),
              )
            else
              for (final r in _rfqs!)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(r['name']?.toString() ?? ''),
                  subtitle: Text(r['status']?.toString() ?? ''),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RecordDetailScreen(
                        args: RecordArgs(
                          recordRegistry['purchase_rfq']!,
                          r['name'].toString(),
                        ),
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// Supplier Quotation -> Purchase Order links. Read-only list of the POs
/// already created from this Supplier Quotation (a PO carries its source SQ on
/// each PO item). Creating a new PO is handled separately by the "Next step"
/// conversion section, so this section only surfaces existing links.
/// Purchase-chain "Next step" buttons shown on RFQ / Supplier Quotation /
/// Purchase Order / Purchase Receipt detail screens. Mirrors the Sales
/// conversion pattern; the RFQ and Return steps need a small picker first,
/// the rest are one tap. Backed by tcb_portal_erp.api.purchase.
class _PurchaseConversionSection extends ConsumerStatefulWidget {
  const _PurchaseConversionSection({
    required this.doctype,
    required this.name,
    this.created = const {},
    this.onChanged,
  });
  final String doctype;
  final String name;

  /// {targetDoctype: {exists, count, sample}} - which next-step docs exist.
  final Map<String, dynamic> created;

  /// Refresh the source detail after a conversion so buttons update.
  final VoidCallback? onChanged;

  @override
  ConsumerState<_PurchaseConversionSection> createState() =>
      _PurchaseConversionSectionState();
}

class _PurchaseConversionSectionState
    extends ConsumerState<_PurchaseConversionSection> {
  bool _running = false;

  PurchaseRepository get _repo => ref.read(purchaseRepositoryProvider);

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m, maxLines: 6, overflow: TextOverflow.ellipsis),
        duration: const Duration(seconds: 6)));

  Future<void> _oneTap(
    Future<String> Function() run,
    String label, {
    String? targetKey,
  }) async {
    setState(() => _running = true);
    try {
      final name = await run();
      if (!mounted) return;
      _snack('$label: $name');
      // Refresh the source so the just-created step's button hides.
      widget.onChanged?.call();
      if (targetKey != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RecordDetailScreen(
              args: RecordArgs(recordRegistry[targetKey]!, name),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) _snack("Couldn't complete. $e");
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _createSqFromRfq() async {
    List<Map<String, dynamic>> suppliers;
    try {
      suppliers = await _repo.rfqSuppliers(widget.name);
    } catch (e) {
      if (mounted) _snack("Couldn't complete. $e");
      return;
    }
    if (!mounted) return;
    if (suppliers.isEmpty) {
      _snack('No suppliers invited on this RFQ');
      return;
    }
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(AppDimens.lg),
              child: Text('Create quotation for supplier',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            for (final s in suppliers)
              ListTile(
                title: Text((s['supplier_name'] ?? s['supplier']).toString()),
                subtitle: Text((s['supplier'] ?? '').toString()),
                onTap: () =>
                    Navigator.pop(context, (s['supplier'] ?? '').toString()),
              ),
          ],
        ),
      ),
    );
    if (picked == null || picked.isEmpty) return;
    await _oneTap(
      () => _repo.createSupplierQuotationFromRfq(widget.name, picked),
      'Supplier Quotation',
      targetKey: 'purchase_supplier_quotation',
    );
  }

  Future<void> _createReturn() async {
    List<Map<String, dynamic>> items;
    try {
      items = await _repo.receiptItems(widget.name);
    } catch (e) {
      if (mounted) _snack("Couldn't complete. $e");
      return;
    }
    if (!mounted) return;
    final result = await showModalBottomSheet<List<Map<String, dynamic>>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ReturnItemsSheet(items: items),
    );
    if (result == null || result.isEmpty) return;
    await _oneTap(
      () => _repo.createPurchaseReturn(widget.name, result),
      'Return',
      targetKey: 'purchase_receipt',
    );
  }

  @override
  Widget build(BuildContext context) {
    final spinner = _running;
    Widget primaryBtn(String label, IconData icon, VoidCallback onTap) =>
        FilledButton.icon(
          onPressed: spinner ? null : onTap,
          icon: spinner
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Icon(icon, size: 18),
          label: Text(label),
        );
    Widget outlineBtn(String label, IconData icon, VoidCallback onTap) =>
        OutlinedButton.icon(
          onPressed: spinner ? null : onTap,
          icon: Icon(icon, size: 18),
          label: Text(label),
        );

    bool made(String target) =>
        (widget.created[target]?['exists'] as num?)?.toInt() == 1;
    String sample(String target) =>
        (widget.created[target]?['sample'] ?? '').toString();

    final buttons = <Widget>[];
    final notes = <String>[];
    switch (widget.doctype) {
      case 'Request for Quotation':
        if (made('Supplier Quotation')) {
          notes.add('Supplier Quotation already created (${sample('Supplier Quotation')}).');
        } else {
          buttons.add(primaryBtn('Create Supplier Quotation',
              Icons.request_quote_outlined, _createSqFromRfq));
        }
        buttons.add(outlineBtn(
            'Compare Quotations',
            Icons.compare_arrows,
            () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => PurchaseComparisonScreen(
                      requestForQuotation: widget.name),
                ))));
        break;
      case 'Supplier Quotation':
        if (made('Purchase Order')) {
          notes.add('Purchase Order already created (${sample('Purchase Order')}).');
        } else {
          buttons.add(primaryBtn(
              'Create Purchase Order',
              Icons.shopping_cart_outlined,
              () => _oneTap(
                  () => _repo.createPoFromSupplierQuotation(widget.name),
                  'Purchase Order',
                  targetKey: 'purchase_order')));
        }
        break;
      case 'Purchase Order':
        if (made('Purchase Receipt')) {
          notes.add('Receipt (GRN) already created (${sample('Purchase Receipt')}).');
        } else {
          buttons.add(primaryBtn(
              'Create Receipt (GRN)',
              Icons.inventory_2_outlined,
              () => _oneTap(() => _repo.createReceiptFromPo(widget.name),
                  'Purchase Receipt',
                  targetKey: 'purchase_receipt')));
        }
        // A PO can be billed directly (without a receipt): show the invoice
        // status, and offer a Create Invoice button when none exists yet.
        if (made('Purchase Invoice')) {
          notes.add('Invoice already created (${sample('Purchase Invoice')}).');
        } else {
          buttons.add(primaryBtn(
              'Create Invoice',
              Icons.receipt_long_outlined,
              () => _oneTap(() => _repo.createInvoiceFromPo(widget.name),
                  'Purchase Invoice')));
        }
        break;
      case 'Purchase Receipt':
        if (made('Purchase Invoice')) {
          notes.add('Invoice already created (${sample('Purchase Invoice')}).');
        } else {
          buttons.add(primaryBtn(
              'Create Invoice',
              Icons.receipt_long_outlined,
              () => _oneTap(() => _repo.createInvoiceFromReceipt(widget.name),
                  'Purchase Invoice')));
        }
        buttons.add(outlineBtn('Create Return',
            Icons.assignment_return_outlined, _createReturn));
        break;
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Next step',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            for (final n in notes) ...[
              const SizedBox(height: AppDimens.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle, size: 18, color: AppColors.success),
                  const SizedBox(width: AppDimens.xs),
                  Expanded(child: Text(n)),
                ],
              ),
            ],
            const SizedBox(height: AppDimens.sm),
            Wrap(
              spacing: AppDimens.sm,
              runSpacing: AppDimens.sm,
              children: buttons,
            ),
          ],
        ),
      ),
    );
  }
}

/// Quantity sheet for a Purchase Return: lists the receipt's items with their
/// returnable qty (received - already returned) and lets the user enter how
/// much of each to return. Returns [{item_code, qty}] for the picked rows.
class _ReturnItemsSheet extends StatefulWidget {
  const _ReturnItemsSheet({required this.items});
  final List<Map<String, dynamic>> items;

  @override
  State<_ReturnItemsSheet> createState() => _ReturnItemsSheetState();
}

class _ReturnItemsSheetState extends State<_ReturnItemsSheet> {
  late final Map<String, TextEditingController> _controllers;

  double _returnable(Map<String, dynamic> it) {
    final rec = (it['received_qty'] as num?)?.toDouble() ?? 0;
    final ret = (it['returned_qty'] as num?)?.toDouble() ?? 0;
    final left = rec - ret;
    return left < 0 ? 0 : left;
  }

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final it in widget.items)
        (it['item_code'] ?? '').toString(): TextEditingController(),
    };
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final out = <Map<String, dynamic>>[];
    for (final it in widget.items) {
      final code = (it['item_code'] ?? '').toString();
      final qty = double.tryParse(_controllers[code]?.text.trim() ?? '') ?? 0;
      if (qty > 0) out.add({'item_code': code, 'qty': qty});
    }
    Navigator.of(context).pop(out);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(AppDimens.lg),
              child: Text('Return quantities',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: widget.items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final it = widget.items[i];
                  final code = (it['item_code'] ?? '').toString();
                  final name = (it['item_name'] ?? code).toString();
                  final left = _returnable(it);
                  return ListTile(
                    title: Text(name),
                    subtitle: Text('$code  •  returnable: $left'),
                    trailing: SizedBox(
                      width: 90,
                      child: TextField(
                        controller: _controllers[code],
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Qty',
                          isDense: true,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppDimens.md),
                child: FilledButton(
                  onPressed: _submit,
                  child: const Text('Create Return'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Multi-select Supplier picker for inviting suppliers on a new RFQ.
class _SupplierMultiSelectSheet extends ConsumerStatefulWidget {
  const _SupplierMultiSelectSheet();
  @override
  ConsumerState<_SupplierMultiSelectSheet> createState() =>
      _SupplierMultiSelectSheetState();
}

class _SupplierMultiSelectSheetState
    extends ConsumerState<_SupplierMultiSelectSheet> {
  List<Map<String, String>> _results = const [];
  final Set<String> _selected = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  Future<void> _search(String txt) async {
    setState(() => _loading = true);
    try {
      final r = await ref
          .read(recordsRepositoryProvider)
          .searchLink('Supplier', txt: txt);
      if (mounted) setState(() => _results = r);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppDimens.md),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search suppliers…',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: _search,
              ),
            ),
            if (_loading) const LinearProgressIndicator(),
            Expanded(
              child: ListView.separated(
                itemCount: _results.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final r = _results[i];
                  final value = r['value'] ?? '';
                  return CheckboxListTile(
                    value: _selected.contains(value),
                    title: Text(r['label'] ?? ''),
                    subtitle:
                        (r['label'] != value) ? Text(value) : null,
                    onChanged: (checked) => setState(() {
                      if (checked == true) {
                        _selected.add(value);
                      } else {
                        _selected.remove(value);
                      }
                    }),
                  );
                },
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppDimens.md),
                child: FilledButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => Navigator.of(context).pop(_selected.toList()),
                  child: Text('Invite ${_selected.length} supplier(s)'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Searchable User picker, reused for "assign project" and "assign task".
class _UserSearchSheet extends ConsumerStatefulWidget {
  const _UserSearchSheet();
  @override
  ConsumerState<_UserSearchSheet> createState() => _UserSearchSheetState();
}

class _UserSearchSheetState extends ConsumerState<_UserSearchSheet> {
  List<Map<String, String>> _results = const [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  Future<void> _search(String txt) async {
    setState(() => _loading = true);
    try {
      final r =
          await ref.read(recordsRepositoryProvider).searchLink('User', txt: txt);
      if (mounted) setState(() => _results = r);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppDimens.md),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search user…',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: _search,
              ),
            ),
            if (_loading) const LinearProgressIndicator(),
            Expanded(
              child: ListView.separated(
                itemCount: _results.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final r = _results[i];
                  return ListTile(
                    title: Text(r['label'] ?? ''),
                    subtitle: (r['label'] != r['value']) ? Text(r['value'] ?? '') : null,
                    onTap: () => Navigator.of(context).pop(r['value']),
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

/// One document-conversion action (e.g. "Create Delivery Note" from a Sales
/// Order). `targetKey` is the recordRegistry key to open on success, or null
/// when the created doc has no generic record screen (e.g. Sales Invoice,
/// which uses the bespoke invoices/ feature instead).
class _SalesAction {
  const _SalesAction({
    required this.label,
    required this.targetKey,
    required this.run,
  });
  final String label;
  final String? targetKey;
  final Future<String> Function(SalesRepository repo) run;
}

/// Sales-cycle conversion buttons shown on Quotation/Sales Order/Delivery
/// Note detail screens. Mirrors the Purchase module's conversion-action
/// pattern (_MaterialRequestRfqSection) but as simple one-tap buttons since
/// each of these steps creates exactly one draft document, not a list.
class _SalesConversionSection extends ConsumerStatefulWidget {
  const _SalesConversionSection({
    required this.actions,
    this.status = '',
    this.doneNote,
    this.onDone,
  });
  final List<_SalesAction> actions;

  /// Current ERPNext status of the source doc, shown as a stage chip.
  final String status;

  /// Shown (with a check) when a step is already done, e.g. the Sales Order
  /// has been created from this Quotation.
  final String? doneNote;

  /// Called after a successful conversion so the detail can refresh its
  /// status - the button then hides itself and the stage updates.
  final VoidCallback? onDone;

  @override
  ConsumerState<_SalesConversionSection> createState() =>
      _SalesConversionSectionState();
}

class _SalesConversionSectionState
    extends ConsumerState<_SalesConversionSection> {
  bool _running = false;

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m, maxLines: 6, overflow: TextOverflow.ellipsis),
        duration: const Duration(seconds: 6)));

  Future<void> _run(_SalesAction action) async {
    setState(() => _running = true);
    try {
      final repo = ref.read(salesRepositoryProvider);
      final name = await action.run(repo);
      if (!mounted) return;
      _snack('${action.label}: $name');
      // Refresh the source doc so its status advances and any completed
      // step's button disappears.
      widget.onDone?.call();
      final targetKey = action.targetKey;
      if (targetKey != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RecordDetailScreen(
              args: RecordArgs(recordRegistry[targetKey]!, name),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) await showFriendlyError(context, e);
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Next step',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                if (widget.status.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.sm, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                    ),
                    child: Text(widget.status,
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: AppDimens.sm),
            if (widget.doneNote != null)
              Padding(
                padding: EdgeInsets.only(
                    bottom: widget.actions.isEmpty ? 0 : AppDimens.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle,
                        color: AppColors.success, size: 18),
                    const SizedBox(width: AppDimens.xs),
                    Expanded(
                      child: Text(widget.doneNote!,
                          style: TextStyle(color: AppColors.success)),
                    ),
                  ],
                ),
              ),
            if (widget.actions.isNotEmpty)
              Wrap(
                spacing: AppDimens.sm,
                runSpacing: AppDimens.sm,
                children: [
                  for (final action in widget.actions)
                    FilledButton.icon(
                      onPressed: _running ? null : () => _run(action),
                      icon: _running
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.arrow_forward, size: 18),
                      label: Text(action.label),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// One next-step action on the Manufacturing detail (e.g. BOM -> Work Order).
/// `targetKey` is the recordRegistry key to open on success.
class _ManufacturingAction {
  const _ManufacturingAction({
    required this.label,
    required this.targetKey,
    required this.run,
  });
  final String label;
  final String? targetKey;
  final Future<String> Function(ManufacturingRepository repo) run;
}

/// Manufacturing-cycle conversion buttons shown on BOM/Work Order detail
/// screens. Mirrors the Sales/Purchase conversion-action pattern: each tap
/// creates exactly one draft document and opens it.
class _ManufacturingConversionSection extends ConsumerStatefulWidget {
  const _ManufacturingConversionSection({required this.actions});
  final List<_ManufacturingAction> actions;

  @override
  ConsumerState<_ManufacturingConversionSection> createState() =>
      _ManufacturingConversionSectionState();
}

class _ManufacturingConversionSectionState
    extends ConsumerState<_ManufacturingConversionSection> {
  bool _running = false;

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m, maxLines: 6, overflow: TextOverflow.ellipsis),
        duration: const Duration(seconds: 6)));

  Future<void> _run(_ManufacturingAction action) async {
    setState(() => _running = true);
    try {
      final repo = ref.read(manufacturingRepositoryProvider);
      final name = await action.run(repo);
      if (!mounted) return;
      _snack('${action.label}: $name');
      final targetKey = action.targetKey;
      if (targetKey != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RecordDetailScreen(
              args: RecordArgs(recordRegistry[targetKey]!, name),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) _snack("Couldn't complete. $e");
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Wrap(
          spacing: AppDimens.sm,
          runSpacing: AppDimens.sm,
          children: [
            for (final action in widget.actions)
              FilledButton.icon(
                onPressed: _running ? null : () => _run(action),
                icon: _running
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.arrow_forward, size: 18),
                label: Text(action.label),
              ),
          ],
        ),
      ),
    );
  }
}

/// Draft Work Order -> "Submit (create Job Cards)". Submitting a Work Order is
/// what makes ERPNext auto-create its Job Cards (one per BOM operation), so this
/// is the shop-floor entry point. After submit we refresh the detail so the
/// Job Cards list + conversion buttons appear.
class _WorkOrderSubmitSection extends ConsumerStatefulWidget {
  const _WorkOrderSubmitSection(
      {required this.workOrder, required this.onSubmitted});
  final String workOrder;
  final VoidCallback onSubmitted;

  @override
  ConsumerState<_WorkOrderSubmitSection> createState() =>
      _WorkOrderSubmitSectionState();
}

class _WorkOrderSubmitSectionState
    extends ConsumerState<_WorkOrderSubmitSection> {
  bool _running = false;

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m, maxLines: 6, overflow: TextOverflow.ellipsis),
        duration: const Duration(seconds: 6)));

  Future<void> _submit() async {
    setState(() => _running = true);
    try {
      final cards = await ref
          .read(manufacturingRepositoryProvider)
          .submitWorkOrder(widget.workOrder);
      if (!mounted) return;
      _snack(cards.isEmpty
          ? 'Work Order submitted. No Job Cards (BOM has no operations).'
          : 'Work Order submitted. ${cards.length} Job Card(s) created.');
      widget.onSubmitted();
    } catch (e) {
      if (mounted) _snack("Couldn't complete. $e");
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Production',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppDimens.xs),
            Text(
              'Submit this Work Order to release it to production. Job Cards '
              'are created automatically for each operation.',
              style: TextStyle(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: AppDimens.sm),
            FilledButton.icon(
              onPressed: _running ? null : _submit,
              icon: _running
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.play_circle_outline, size: 18),
              label: const Text('Submit (create Job Cards)'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Submitted Work Order -> the single next production step, chosen from stock +
/// transfer state so the buttons never overlap:
///  - material already transferred to WIP  -> "Manufacture" only
///  - raw materials all in stock           -> "Transfer Material" only
///  - something short                      -> "Create Material Request" only
class _WorkOrderStockSection extends ConsumerStatefulWidget {
  const _WorkOrderStockSection({
    required this.workOrder,
    required this.orderQty,
    required this.transferredQty,
  });
  final String workOrder;
  final double orderQty;
  final double transferredQty;

  @override
  ConsumerState<_WorkOrderStockSection> createState() =>
      _WorkOrderStockSectionState();
}

class _WorkOrderStockSectionState
    extends ConsumerState<_WorkOrderStockSection> {
  bool _loading = true;
  bool _creating = false;
  bool _running = false;
  String? _error;
  bool _allAvailable = true;
  List<Map<String, dynamic>> _items = const [];

  /// Material has been (fully) issued to WIP, so the only step left is the
  /// Manufacture stock entry - no need to check raw-material stock again.
  bool get _transferDone =>
      widget.orderQty > 0 && widget.transferredQty >= widget.orderQty;

  @override
  void initState() {
    super.initState();
    if (_transferDone) {
      _loading = false;
    } else {
      _load();
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m, maxLines: 6, overflow: TextOverflow.ellipsis),
      duration: const Duration(seconds: 6)));

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ref
          .read(manufacturingRepositoryProvider)
          .workOrderStockStatus(widget.workOrder);
      if (!mounted) return;
      setState(() {
        _allAvailable = data['all_available'] == true;
        _items = ((data['items'] as List?) ?? const [])
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyMessageFor(e).message;
        _loading = false;
      });
    }
  }

  Future<void> _createMaterialRequest() async {
    setState(() => _creating = true);
    try {
      final name = await ref
          .read(manufacturingRepositoryProvider)
          .createMaterialRequestFromWorkOrder(widget.workOrder);
      if (!mounted) return;
      _snack('Material Request created: $name');
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RecordDetailScreen(
            args: RecordArgs(recordRegistry['stock_material_request']!, name),
          ),
        ),
      );
    } catch (e) {
      if (mounted) await showFriendlyError(context, e);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _createStockEntry(String purpose, String label) async {
    setState(() => _running = true);
    try {
      final name = await ref
          .read(manufacturingRepositoryProvider)
          .createStockEntryFromWorkOrder(widget.workOrder, purpose: purpose);
      if (!mounted) return;
      _snack('$label: $name');
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RecordDetailScreen(
            args: RecordArgs(recordRegistry['stock_entry']!, name),
          ),
        ),
      );
    } catch (e) {
      if (mounted) await showFriendlyError(context, e);
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  String _n(dynamic v) {
    final d = v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    return d == d.roundToDouble() ? d.toInt().toString() : d.toString();
  }

  String _str(dynamic v) => v == null ? '' : v.toString();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Raw material stock',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppDimens.xs),
            if (_transferDone) ...[
              Container(
                padding: const EdgeInsets.all(AppDimens.sm),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 18),
                  SizedBox(width: AppDimens.sm),
                  Expanded(
                      child: Text('Materials transferred to WIP. '
                          'Ready to manufacture.')),
                ]),
              ),
              const SizedBox(height: AppDimens.sm),
              FilledButton.icon(
                onPressed: _running
                    ? null
                    : () => _createStockEntry('Manufacture', 'Manufacture'),
                icon: _running
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.precision_manufacturing_outlined,
                        size: 18),
                label: const Text('Manufacture'),
              ),
            ] else if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppDimens.sm),
                child: SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (_error != null) ...[
              Text("Couldn't load stock. $_error",
                  style: const TextStyle(color: Colors.red)),
              const SizedBox(height: AppDimens.sm),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ] else ...[
              for (final it in _items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppDimens.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        (_n(it['shortage_qty']) == '0')
                            ? Icons.check_circle_outline
                            : Icons.error_outline,
                        size: 18,
                        color: (_n(it['shortage_qty']) == '0')
                            ? Colors.green
                            : Colors.orange,
                      ),
                      const SizedBox(width: AppDimens.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_str(it['item_name']).isEmpty
                                ? _str(it['item_code'])
                                : _str(it['item_name'])),
                            Text(
                              'Need ${_n(it['required_qty'])} ${_str(it['uom'])} '
                              '· In stock ${_n(it['available_qty'])}'
                              '${_n(it['shortage_qty']) == '0' ? '' : ' · Short ${_n(it['shortage_qty'])}'}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppDimens.sm),
              if (_allAvailable) ...[
                Container(
                  padding: const EdgeInsets.all(AppDimens.sm),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 18),
                    SizedBox(width: AppDimens.sm),
                    Expanded(
                        child: Text(
                            'All raw materials in stock. Ready to transfer.')),
                  ]),
                ),
                const SizedBox(height: AppDimens.sm),
                FilledButton.icon(
                  onPressed: _running
                      ? null
                      : () => _createStockEntry(
                          'Material Transfer for Manufacture',
                          'Transfer Material'),
                  icon: _running
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.move_down, size: 18),
                  label: const Text('Transfer Material'),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(AppDimens.sm),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.orange, size: 18),
                    SizedBox(width: AppDimens.sm),
                    Expanded(
                        child: Text('Some raw materials are short. Create a '
                            'Material Request to procure them first.')),
                  ]),
                ),
                const SizedBox(height: AppDimens.sm),
                FilledButton.icon(
                  onPressed: _creating ? null : _createMaterialRequest,
                  icon: _creating
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.add_shopping_cart, size: 18),
                  label: const Text('Create Material Request'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Submitted Work Order -> read-only list of its Job Cards, each tappable to
/// open the Job Card (where the operator can assign / start / stop).
class _WorkOrderJobCardsSection extends ConsumerStatefulWidget {
  const _WorkOrderJobCardsSection({required this.workOrder});
  final String workOrder;

  @override
  ConsumerState<_WorkOrderJobCardsSection> createState() =>
      _WorkOrderJobCardsSectionState();
}

class _WorkOrderJobCardsSectionState
    extends ConsumerState<_WorkOrderJobCardsSection> {
  List<Map<String, dynamic>>? _cards;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final cards = await ref
          .read(manufacturingRepositoryProvider)
          .listJobCards(mine: false, workOrder: widget.workOrder);
      if (mounted) {
        setState(() {
          _cards = cards;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Job Cards',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            if (_error != null)
              Text('$_error', style: const TextStyle(color: AppColors.error)),
            if (_cards == null && _error == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppDimens.sm),
                child: Center(child: CircularProgressIndicator()),
              )
            else if ((_cards ?? const []).isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppDimens.sm),
                child: Text('No Job Cards for this Work Order',
                    style: TextStyle(color: AppColors.onSurfaceVariant)),
              )
            else
              for (final c in _cards!)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(c['operation']?.toString() ??
                      c['name']?.toString() ??
                      ''),
                  subtitle: Text(c['status']?.toString() ?? ''),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RecordDetailScreen(
                          args: RecordArgs(
                            recordRegistry['mfg_job_card']!,
                            c['name'].toString(),
                          ),
                        ),
                      ),
                    );
                    _load();
                  },
                ),
          ],
        ),
      ),
    );
  }
}

/// Job Card shop-floor controls: who it is assigned to (assign / unassign via
/// Frappe's standard document assignment), required vs. completed qty, and the
/// Start / Stop timer buttons that drive ERPNext's own time logging.
class _JobCardShopFloorSection extends ConsumerStatefulWidget {
  const _JobCardShopFloorSection({required this.jobCard});
  final String jobCard;

  @override
  ConsumerState<_JobCardShopFloorSection> createState() =>
      _JobCardShopFloorSectionState();
}

class _JobCardShopFloorSectionState
    extends ConsumerState<_JobCardShopFloorSection> {
  Map<String, dynamic>? _detail;
  Object? _error;
  bool _busy = false;

  CrmRef get _ref => CrmRef(doctype: 'Job Card', name: widget.jobCard);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await ref
          .read(manufacturingRepositoryProvider)
          .jobCardDetail(widget.jobCard);
      if (mounted) {
        setState(() {
          _detail = d;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m, maxLines: 6, overflow: TextOverflow.ellipsis),
        duration: const Duration(seconds: 6)));

  Future<void> _start() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(manufacturingRepositoryProvider)
          .startJobCard(widget.jobCard);
      if (!mounted) return;
      _snack('Started');
      await _load();
    } catch (e) {
      if (mounted) await showFriendlyError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(manufacturingRepositoryProvider)
          .completeJobCard(widget.jobCard);
      if (!mounted) return;
      _snack('Stopped and recorded');
      await _load();
    } catch (e) {
      if (mounted) await showFriendlyError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// After the work is stopped/recorded, the Job Card must be SUBMITTED before
  /// the Work Order can be manufactured (ERPNext blocks Manufacture while any
  /// job card is still a draft). Goes through the generic submit endpoint.
  ///
  /// ERPNext refuses to submit until the completed qty adds up to the qty to
  /// manufacture, so if the work has not been recorded yet (still running, or
  /// zero completed) we record it first, then submit - one tap does the whole
  /// finish for the operator.
  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(manufacturingRepositoryProvider);
      final running = _detail?['is_running'] == true;
      final done =
          (_detail?['total_completed_qty'] as num?)?.toDouble() ?? 0;
      if (running || done <= 0) {
        await repo.completeJobCard(widget.jobCard);
      }
      await ref
          .read(recordsRepositoryProvider)
          .submitDoc('Job Card', widget.jobCard);
      if (!mounted) return;
      await showAppMessage(context,
          kind: AppMessageKind.success,
          title: 'Job card submitted',
          message: 'This job card is done. Once every job card of the work '
              'order is submitted, you can record the Manufacture entry.');
      await _load();
    } catch (e) {
      if (mounted) await showFriendlyError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _assign() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _UserSearchSheet(),
    );
    if (picked == null) return;
    try {
      await ref.read(crmCollabRepositoryProvider).addAssignee(_ref, picked);
      ref.invalidate(assigneesProvider(_ref));
      _load();
    } catch (e) {
      if (mounted) _snack('$e');
    }
  }

  Future<void> _unassign(String user) async {
    try {
      await ref.read(crmCollabRepositoryProvider).removeAssignee(_ref, user);
      ref.invalidate(assigneesProvider(_ref));
      _load();
    } catch (e) {
      if (mounted) _snack('$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _detail;
    final assignees = ref.watch(assigneesProvider(_ref));
    final isRunning = d?['is_running'] == true;
    final forQty = (d?['for_quantity'] as num?)?.toDouble() ?? 0;
    final doneQty = (d?['total_completed_qty'] as num?)?.toDouble() ?? 0;
    final status = d?['status']?.toString() ?? '';
    final docstatus = (d?['docstatus'] as num?)?.toInt() ?? 0;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Shop floor',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            if (_error != null)
              Text('$_error', style: const TextStyle(color: AppColors.error)),
            if (d == null && _error == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppDimens.sm),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (d != null) ...[
              const SizedBox(height: AppDimens.xs),
              Row(
                children: [
                  _chip(
                      status.isEmpty ? 'Open' : status,
                      isRunning
                          ? AppColors.primary
                          : AppColors.onSurfaceVariant),
                  const SizedBox(width: AppDimens.sm),
                  Text('Done ${_fmt(doneQty)} / ${_fmt(forQty)}',
                      style: TextStyle(color: AppColors.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: AppDimens.sm),
              Row(
                children: [
                  Expanded(
                    child: Text('Assigned to',
                        style: Theme.of(context).textTheme.labelLarge),
                  ),
                  TextButton.icon(
                    onPressed: _assign,
                    icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                    label: const Text('Assign'),
                  ),
                ],
              ),
              assignees.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppDimens.xs),
                  child: LinearProgressIndicator(),
                ),
                error: (e, _) =>
                    Text('$e', style: const TextStyle(color: AppColors.error)),
                data: (list) => list.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(bottom: AppDimens.xs),
                        child: Text('Nobody assigned yet',
                            style:
                                TextStyle(color: AppColors.onSurfaceVariant)),
                      )
                    : Wrap(
                        spacing: AppDimens.sm,
                        children: [
                          for (final a in list)
                            InputChip(
                              label: Text(a.fullName),
                              onDeleted: () => _unassign(a.user),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: AppDimens.sm),
              if (docstatus == 0)
                if (isRunning)
                  // Work in progress -> only Stop.
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.error),
                      onPressed: _busy ? null : _stop,
                      icon: const Icon(Icons.stop, size: 18),
                      label: const Text('Stop'),
                    ),
                  )
                else if (doneQty > 0)
                  // Work recorded but not submitted yet. Submit is the step
                  // that lets the Work Order be manufactured.
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.success),
                      onPressed: _busy ? null : _submit,
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Submit'),
                    ),
                  )
                else
                  // Not started yet.
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _start,
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text('Start'),
                    ),
                  )
              else
                Row(
                  children: [
                    Icon(Icons.check_circle,
                        color: AppColors.success, size: 18),
                    const SizedBox(width: AppDimens.xs),
                    Text('Job card submitted.',
                        style: TextStyle(color: AppColors.success)),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  Widget _chip(String text, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: AppDimens.sm, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        ),
        child: Text(text,
            style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      );
}
