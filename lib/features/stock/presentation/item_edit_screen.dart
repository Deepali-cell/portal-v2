import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../application/stock_controller.dart';
import '../domain/models.dart';
import 'item_create_screen.dart' show LinkField, LinkSearchSheet;

/// Edit-an-existing-Item form. Reached only from the Item detail screen's
/// Edit action, which is itself gated on `profile.canDo('stock_item','write')`.
/// The backend re-checks Frappe's write permission, so this is defence-in-depth,
/// not a parallel gate.
class ItemEditScreen extends ConsumerStatefulWidget {
  const ItemEditScreen({super.key, required this.item});
  final ItemDetail item;

  @override
  ConsumerState<ItemEditScreen> createState() => _ItemEditScreenState();
}

class _ItemEditScreenState extends ConsumerState<ItemEditScreen> {
  late final TextEditingController _itemName =
      TextEditingController(text: widget.item.itemName);
  late final TextEditingController _standardRate = TextEditingController(
      text: widget.item.standardRate?.toString() ?? '');
  late final TextEditingController _description =
      TextEditingController(text: widget.item.description ?? '');

  late String? _itemGroup = widget.item.itemGroup;
  late String? _stockUom = widget.item.stockUom;
  late String? _gstHsnCode = widget.item.gstHsnCode;
  late bool _isStockItem = widget.item.isStockItem;
  late bool _isSalesItem = widget.item.isSalesItem;
  late bool _isPurchaseItem = widget.item.isPurchaseItem;
  bool _saving = false;

  @override
  void dispose() {
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
    setState(() => _saving = true);
    try {
      await ref.read(stockRepositoryProvider).updateItem(
            name: widget.item.name,
            itemName: _itemName.text.trim(),
            itemGroup: _itemGroup,
            stockUom: _stockUom,
            isStockItem: _isStockItem,
            isSalesItem: _isSalesItem,
            isPurchaseItem: _isPurchaseItem,
            standardRate: double.tryParse(_standardRate.text.trim()),
            description: _description.text.trim(),
            gstHsnCode: _gstHsnCode ?? '',
          );
      ref.invalidate(itemDetailProvider(widget.item.name));
      await ref.read(itemsControllerProvider.notifier).reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item updated')),
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
      appBar: AppBar(title: Text('Edit ${widget.item.itemCode}')),
      body: ListView(
        padding: const EdgeInsets.all(AppDimens.md),
        children: [
          TextFormField(
            controller: _itemName,
            decoration: const InputDecoration(
              labelText: 'Item Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppDimens.md),
          LinkField(
            label: 'Item Group',
            value: _itemGroup,
            onTap: () =>
                _pickLink('Item Group', (v) => setState(() => _itemGroup = v)),
          ),
          const SizedBox(height: AppDimens.md),
          LinkField(
            label: 'Stock UOM',
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
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                : const Text('Save'),
          ),
        ],
      ),
    );
  }
}
