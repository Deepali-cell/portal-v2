import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/format/money.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../application/invoices_controller.dart';
import '../domain/models.dart';

final _dateFmt = DateFormat('d MMM yyyy');

class NewInvoiceSheet extends ConsumerStatefulWidget {
  const NewInvoiceSheet({super.key, required this.kind});
  final InvoiceKind kind;

  @override
  ConsumerState<NewInvoiceSheet> createState() => _NewInvoiceSheetState();
}

class _NewInvoiceSheetState extends ConsumerState<NewInvoiceSheet> {
  PartyRef? _party;
  DateTime _postingDate = DateTime.now();
  DateTime? _dueDate;
  final List<InvoiceDraftItem> _items = [InvoiceDraftItem()];
  String _currency = 'INR';
  bool _saving = false;
  bool _saveSubmit = false; // true = clicked Save & Submit; false = Save Draft
  String? _error;

  // Purchase-only — supplier's bill number, date and attached file.
  final _billNo = TextEditingController();
  DateTime? _billDate;
  String? _supplierInvoicePath;
  String? _supplierInvoiceName;

  @override
  void dispose() {
    _billNo.dispose();
    super.dispose();
  }

  Future<void> _pickBillDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _billDate ?? _postingDate,
      firstDate: DateTime(_postingDate.year - 2),
      lastDate: DateTime(_postingDate.year + 1, 12, 31),
    );
    if (picked != null) setState(() => _billDate = picked);
  }

  Future<void> _attachSupplierInvoice() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: false,
    );
    if (picked == null || picked.files.isEmpty) return;
    final f = picked.files.single;
    if (f.path == null) return;
    final size = await File(f.path!).length();
    if (size > 16 * 1024 * 1024) {
      if (!mounted) return;
      setState(() => _error = 'File is too large (max 16 MB).');
      return;
    }
    setState(() {
      _supplierInvoicePath = f.path;
      _supplierInvoiceName = f.name;
      _error = null;
    });
  }

  String get _itemKind =>
      widget.kind == InvoiceKind.sales ? 'sales' : 'purchase';
  String get _partyLabel =>
      widget.kind == InvoiceKind.sales ? 'Customer' : 'Supplier';
  String get _title =>
      widget.kind == InvoiceKind.sales ? 'New Sales Invoice' : 'New Purchase Invoice';

  double get _total => _items.fold(0, (s, i) => s + i.amount);

  Future<void> _pickParty() async {
    final picked = await showModalBottomSheet<PartyRef>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXl)),
      ),
      builder: (_) => _PartyPicker(kind: widget.kind),
    );
    if (picked != null) {
      setState(() {
        _party = picked;
        if (picked.currency != null && picked.currency!.isNotEmpty) {
          _currency = picked.currency!;
        }
      });
    }
  }

  Future<void> _pickItem(int idx) async {
    final picked = await showModalBottomSheet<ItemRef>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXl)),
      ),
      builder: (_) => _ItemPicker(kind: _itemKind),
    );
    if (picked == null) return;
    setState(() {
      _items[idx].itemCode = picked.code;
      _items[idx].itemName = picked.label;
      if (_items[idx].rate == 0 && picked.standardRate > 0) {
        _items[idx].rate = picked.standardRate;
      }
    });
  }

  Future<void> _pickPostingDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _postingDate,
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
    );
    if (picked != null) setState(() => _postingDate = picked);
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? _postingDate.add(const Duration(days: 30)),
      firstDate: _postingDate,
      lastDate: DateTime(_postingDate.year + 2),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save({required bool submit}) async {
    setState(() => _error = null);
    if (_party == null) {
      setState(() => _error = 'Pick a $_partyLabel first.');
      return;
    }
    for (final i in _items) {
      if (i.itemCode == null) {
        setState(() => _error = 'Each row needs an item.');
        return;
      }
      if (i.qty <= 0) {
        setState(() => _error = 'Quantity must be greater than zero.');
        return;
      }
    }

    setState(() {
      _saving = true;
      _saveSubmit = submit;
    });
    try {
      final ctl = ref.read(invoicesControllerProvider.notifier);
      if (widget.kind == InvoiceKind.sales) {
        await ctl.createSales(
          customer: _party!.name,
          items: _items,
          submit: submit,
          dueDate: _dueDate,
          postingDate: _postingDate,
        );
      } else {
        await ctl.createPurchase(
          supplier: _party!.name,
          items: _items,
          submit: submit,
          dueDate: _dueDate,
          postingDate: _postingDate,
          billNo: _billNo.text.trim().isEmpty ? null : _billNo.text.trim(),
          billDate: _billDate,
          supplierInvoicePath: _supplierInvoicePath,
        );
      }
      if (mounted) Navigator.pop(context, submit ? 'submitted' : 'draft');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not create the invoice.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppDimens.xl, AppDimens.xl, AppDimens.xl, AppDimens.xl + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
                child: Text(_title,
                    style: Theme.of(context).textTheme.titleLarge)),
            const SizedBox(height: AppDimens.xl),

            // Party picker
            InkWell(
              onTap: _pickParty,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: _partyLabel,
                  suffixIcon:
                      Icon(Icons.search, color: AppColors.onSurfaceVariant),
                ),
                child: Text(
                  _party?.label ?? 'Select a $_partyLabel',
                  style: TextStyle(
                      color: _party == null
                          ? AppColors.outline
                          : AppColors.onSurface),
                ),
              ),
            ),
            const SizedBox(height: AppDimens.lg),

            // Supplier-bill capture (Purchase only).
            if (widget.kind == InvoiceKind.purchase) ...[
              _SupplierBillBlock(
                billNoController: _billNo,
                billDate: _billDate,
                onPickBillDate: _pickBillDate,
                supplierInvoiceName: _supplierInvoiceName,
                onAttach: _attachSupplierInvoice,
                onClearAttachment: () => setState(() {
                  _supplierInvoicePath = null;
                  _supplierInvoiceName = null;
                }),
              ),
              const SizedBox(height: AppDimens.lg),
            ],

            // Dates
            Row(children: [
              Expanded(
                child: InkWell(
                  onTap: _pickPostingDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Posting date',
                      suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                    ),
                    child: Text(_dateFmt.format(_postingDate)),
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: InkWell(
                  onTap: _pickDueDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Due date (optional)',
                      suffixIcon: Icon(Icons.event_outlined, size: 18),
                    ),
                    child: Text(
                        _dueDate == null ? 'Select' : _dateFmt.format(_dueDate!),
                        style: TextStyle(
                            color: _dueDate == null
                                ? AppColors.outline
                                : AppColors.onSurface)),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: AppDimens.lg),

            // Items
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: AppDimens.sm),
              child: Text('Items',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600)),
            ),
            for (var i = 0; i < _items.length; i++) ...[
              _itemRow(i),
              const SizedBox(height: AppDimens.md),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () =>
                    setState(() => _items.add(InvoiceDraftItem())),
                icon: const Icon(Icons.add),
                label: const Text('Add item'),
              ),
            ),

            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppDimens.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Subtotal',
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(money(_total, _currency),
                      style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
            Text(
                'ERPNext will apply taxes and compute the grand total on save.',
                style: Theme.of(context).textTheme.bodySmall),

            if (_error != null) ...[
              const SizedBox(height: AppDimens.md),
              Text(_error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13)),
            ],
            const SizedBox(height: AppDimens.xl),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : () => _save(submit: false),
                    icon: (_saving && !_saveSubmit)
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save_outlined, size: 18),
                    label: const Text('Save'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: AppColors.primary),
                      foregroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimens.radiusLg),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppDimens.md),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saving ? null : () => _save(submit: true),
                    icon: (_saving && _saveSubmit)
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Save & Submit'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.secondaryContainer,
                      foregroundColor: AppColors.onSecondaryContainer,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimens.radiusLg),
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

  Widget _itemRow(int idx) {
    final it = _items[idx];
    return Container(
      padding: const EdgeInsets.all(AppDimens.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        children: [
          Row(children: [
            Expanded(
              child: InkWell(
                onTap: () => _pickItem(idx),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Item',
                    suffixIcon:
                        Icon(Icons.search, color: AppColors.onSurfaceVariant),
                  ),
                  child: Text(
                      it.itemName ?? it.itemCode ?? 'Select an item',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: it.itemCode == null
                              ? AppColors.outline
                              : AppColors.onSurface)),
                ),
              ),
            ),
            if (_items.length > 1)
              IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.delete_outline,
                    color: AppColors.error),
                onPressed: () => setState(() => _items.removeAt(idx)),
              ),
          ]),
          const SizedBox(height: AppDimens.sm),
          Row(children: [
            Expanded(
              child: TextFormField(
                initialValue: it.qty.toString(),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(labelText: 'Qty'),
                onChanged: (v) => setState(
                    () => it.qty = double.tryParse(v.trim()) ?? 0),
              ),
            ),
            const SizedBox(width: AppDimens.md),
            Expanded(
              child: TextFormField(
                initialValue: it.rate.toString(),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(labelText: 'Rate'),
                onChanged: (v) => setState(
                    () => it.rate = double.tryParse(v.trim()) ?? 0),
              ),
            ),
            const SizedBox(width: AppDimens.md),
            Expanded(
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Amount'),
                child: Text(money(it.amount, _currency),
                    style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// --------- Party picker ---------

class _PartyPicker extends ConsumerStatefulWidget {
  const _PartyPicker({required this.kind});
  final InvoiceKind kind;
  @override
  ConsumerState<_PartyPicker> createState() => _PartyPickerState();
}

class _PartyPickerState extends ConsumerState<_PartyPicker> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  List<PartyRef> _results = const [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _search(value));
  }

  Future<void> _search(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(invoicesRepositoryProvider);
      final list = widget.kind == InvoiceKind.sales
          ? await repo.searchCustomers(query)
          : await repo.searchSuppliers(query);
      if (!mounted) return;
      setState(() {
        _results = list;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.kind == InvoiceKind.sales ? 'customer' : 'supplier';
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppDimens.lg, AppDimens.lg, AppDimens.lg, AppDimens.lg + bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(children: [
          Center(
              child: Text('Pick a $label',
                  style: Theme.of(context).textTheme.titleLarge)),
          const SizedBox(height: AppDimens.md),
          TextField(
            controller: _ctrl,
            autofocus: true,
            onChanged: _onChanged,
            decoration: InputDecoration(
              hintText: 'Search $label by name',
              prefixIcon: const Icon(Icons.search),
            ),
          ),
          const SizedBox(height: AppDimens.sm),
          Expanded(
            child: _loading && _results.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppDimens.lg),
                          child: Text(_error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.error)),
                        ),
                      )
                    : _results.isEmpty
                        ? Center(
                            child: Text('No matches.',
                                style: Theme.of(context).textTheme.bodyMedium))
                        : ListView.separated(
                            itemCount: _results.length,
                            separatorBuilder: (_, _) => Divider(
                                height: 1, color: AppColors.outlineVariant),
                            itemBuilder: (_, i) {
                              final p = _results[i];
                              return ListTile(
                                title: Text(p.label),
                                subtitle: Text(p.name,
                                    style: Theme.of(context).textTheme.bodySmall),
                                onTap: () => Navigator.pop(context, p),
                              );
                            },
                          ),
          ),
        ]),
      ),
    );
  }
}

// --------- Item picker ---------

class _ItemPicker extends ConsumerStatefulWidget {
  const _ItemPicker({required this.kind});
  final String kind; // 'sales' or 'purchase'
  @override
  ConsumerState<_ItemPicker> createState() => _ItemPickerState();
}

class _ItemPickerState extends ConsumerState<_ItemPicker> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  List<ItemRef> _results = const [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _search(value));
  }

  Future<void> _search(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ref
          .read(invoicesRepositoryProvider)
          .searchItems(query, kind: widget.kind);
      if (!mounted) return;
      setState(() {
        _results = list;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppDimens.lg, AppDimens.lg, AppDimens.lg, AppDimens.lg + bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(children: [
          Center(
              child: Text('Pick an item',
                  style: Theme.of(context).textTheme.titleLarge)),
          const SizedBox(height: AppDimens.md),
          TextField(
            controller: _ctrl,
            autofocus: true,
            onChanged: _onChanged,
            decoration: const InputDecoration(
              hintText: 'Search by code or name',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: AppDimens.sm),
          Expanded(
            child: _loading && _results.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppDimens.lg),
                          child: Text(_error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.error)),
                        ),
                      )
                    : _results.isEmpty
                        ? Center(
                            child: Text('No matches.',
                                style: Theme.of(context).textTheme.bodyMedium))
                        : ListView.separated(
                            itemCount: _results.length,
                            separatorBuilder: (_, _) => Divider(
                                height: 1, color: AppColors.outlineVariant),
                            itemBuilder: (_, i) {
                              final it = _results[i];
                              return ListTile(
                                title: Text(it.label),
                                subtitle: Text(
                                    [
                                      it.code,
                                      if (it.uom != null) it.uom,
                                      if (it.standardRate > 0)
                                        '@ ${it.standardRate}',
                                    ].whereType<String>().join(' · '),
                                    style: Theme.of(context).textTheme.bodySmall),
                                onTap: () => Navigator.pop(context, it),
                              );
                            },
                          ),
          ),
        ]),
      ),
    );
  }
}


class _SupplierBillBlock extends StatelessWidget {
  const _SupplierBillBlock({
    required this.billNoController,
    required this.billDate,
    required this.onPickBillDate,
    required this.supplierInvoiceName,
    required this.onAttach,
    required this.onClearAttachment,
  });
  final TextEditingController billNoController;
  final DateTime? billDate;
  final VoidCallback onPickBillDate;
  final String? supplierInvoiceName;
  final VoidCallback onAttach;
  final VoidCallback onClearAttachment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text("Supplier bill",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.primary, fontWeight: FontWeight.w600)),
          const SizedBox(height: AppDimens.sm),
          Row(children: [
            Expanded(
              child: TextField(
                controller: billNoController,
                decoration: const InputDecoration(
                    labelText: "Bill no (optional)"),
              ),
            ),
            const SizedBox(width: AppDimens.md),
            Expanded(
              child: InkWell(
                onTap: onPickBillDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: "Bill date (optional)",
                    suffixIcon: Icon(Icons.event_outlined, size: 18),
                  ),
                  child: Text(
                      billDate == null
                          ? "Select"
                          : DateFormat("d MMM yyyy").format(billDate!),
                      style: TextStyle(
                          color: billDate == null
                              ? AppColors.outline
                              : AppColors.onSurface)),
                ),
              ),
            ),
          ]),
          const SizedBox(height: AppDimens.md),
          if (supplierInvoiceName == null)
            OutlinedButton.icon(
              onPressed: onAttach,
              icon: const Icon(Icons.attach_file, size: 18),
              label: const Text("Attach supplier invoice (PDF / image)"),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: AppColors.primary),
                foregroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.md, vertical: AppDimens.sm),
              decoration: BoxDecoration(
                color: AppColors.tertiaryFixed.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppDimens.radiusLg),
              ),
              child: Row(children: [
                Icon(Icons.check_circle,
                    color: AppColors.onTertiaryFixedVariant, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(supplierInvoiceName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: AppColors.onTertiaryFixedVariant,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  tooltip: "Remove",
                  visualDensity: VisualDensity.compact,
                  onPressed: onClearAttachment,
                  icon: Icon(Icons.close,
                      color: AppColors.onTertiaryFixedVariant, size: 18),
                ),
              ]),
            ),
        ],
      ),
    );
  }
}
