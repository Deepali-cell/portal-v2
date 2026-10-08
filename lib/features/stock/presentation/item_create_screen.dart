import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../application/stock_controller.dart';

/// Create-a-new-Item form. Reached only from the Items list FAB, which is
/// itself gated on `profile.canDo('stock_item','create')`. The backend re-checks
/// Frappe's create permission, so this is defence-in-depth, not a parallel gate.
class ItemCreateScreen extends ConsumerStatefulWidget {
  const ItemCreateScreen({super.key});

  @override
  ConsumerState<ItemCreateScreen> createState() => _ItemCreateScreenState();
}

class _ItemCreateScreenState extends ConsumerState<ItemCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _itemCode = TextEditingController();
  final _itemName = TextEditingController();
  final _standardRate = TextEditingController();
  final _description = TextEditingController();

  String? _itemGroup;
  String? _stockUom;
  String? _gstHsnCode;
  bool _isStockItem = true;
  bool _isSalesItem = true;
  bool _isPurchaseItem = true;
  bool _saving = false;

  @override
  void dispose() {
    _itemCode.dispose();
    _itemName.dispose();
    _standardRate.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickLink(String doctype, ValueChanged<String> onPicked) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => LinkSearchSheet(doctype: doctype),
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_itemGroup == null || _stockUom == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item Group and Stock UOM are required')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(stockRepositoryProvider).createItem(
            itemCode: _itemCode.text.trim(),
            itemName: _itemName.text.trim(),
            itemGroup: _itemGroup,
            stockUom: _stockUom,
            isStockItem: _isStockItem,
            isSalesItem: _isSalesItem,
            isPurchaseItem: _isPurchaseItem,
            standardRate: double.tryParse(_standardRate.text.trim()),
            description: _description.text.trim(),
            gstHsnCode: _gstHsnCode,
          );
      // Refresh the list so the new Item shows immediately.
      await ref.read(itemsControllerProvider.notifier).reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item created')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final msg = e is ApiException ? e.message : '$e';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('New Item')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppDimens.md),
          children: [
            TextFormField(
              controller: _itemCode,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Item Code *',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: AppDimens.md),
            TextFormField(
              controller: _itemName,
              decoration: const InputDecoration(
                labelText: 'Item Name',
                helperText: 'Defaults to Item Code if left blank',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppDimens.md),
            LinkField(
              label: 'Item Group *',
              value: _itemGroup,
              onTap: () =>
                  _pickLink('Item Group', (v) => setState(() => _itemGroup = v)),
            ),
            const SizedBox(height: AppDimens.md),
            LinkField(
              label: 'Stock UOM *',
              value: _stockUom,
              onTap: () =>
                  _pickLink('UOM', (v) => setState(() => _stockUom = v)),
            ),
            const SizedBox(height: AppDimens.md),
            LinkField(
              label: 'HSN Code',
              value: _gstHsnCode,
              onTap: () => _pickLink(
                  'GST HSN Code', (v) => setState(() => _gstHsnCode = v)),
              onClear: () => setState(() => _gstHsnCode = null),
            ),
            const SizedBox(height: AppDimens.md),
            TextFormField(
              controller: _standardRate,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Standard Rate',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppDimens.md),
            TextFormField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppDimens.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Maintain Stock'),
              value: _isStockItem,
              onChanged: (v) => setState(() => _isStockItem = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Sales Item'),
              value: _isSalesItem,
              onChanged: (v) => setState(() => _isSalesItem = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Purchase Item'),
              value: _isPurchaseItem,
              onChanged: (v) => setState(() => _isPurchaseItem = v),
            ),
            const SizedBox(height: AppDimens.lg),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create Item'),
            ),
          ],
        ),
      ),
    );
  }
}

class LinkField extends StatelessWidget {
  const LinkField({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });
  final String label;
  final String? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: (onClear != null && value != null)
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: onClear,
                )
              : const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          value ?? 'Select…',
          style: value == null
              ? TextStyle(color: AppColors.onSurfaceVariant)
              : null,
        ),
      ),
    );
  }
}

class LinkSearchSheet extends ConsumerStatefulWidget {
  const LinkSearchSheet({required this.doctype});
  final String doctype;

  @override
  ConsumerState<LinkSearchSheet> createState() => LinkSearchSheetState();
}

class LinkSearchSheetState extends ConsumerState<LinkSearchSheet> {
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
      final r = await ref
          .read(stockRepositoryProvider)
          .searchLink(widget.doctype, txt: txt);
      if (mounted) setState(() => _results = r);
    } catch (_) {
      // Silent: empty results render as "no options".
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
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search ${widget.doctype}…',
                  border: const OutlineInputBorder(),
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
                    subtitle: (r['label'] != r['value'])
                        ? Text(r['value'] ?? '')
                        : null,
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
