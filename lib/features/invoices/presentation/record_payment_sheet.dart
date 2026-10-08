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

class RecordPaymentSheet extends ConsumerStatefulWidget {
  const RecordPaymentSheet({super.key, required this.invoice});
  final InvoiceDetail invoice;

  @override
  ConsumerState<RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends ConsumerState<RecordPaymentSheet> {
  late final TextEditingController _amount = TextEditingController(
      text: widget.invoice.outstanding.toStringAsFixed(2));
  final _referenceNo = TextEditingController();
  DateTime _postingDate = DateTime.now();
  DateTime? _referenceDate;
  String? _mode;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _referenceNo.dispose();
    super.dispose();
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

  Future<void> _pickReferenceDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _referenceDate ?? _postingDate,
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
    );
    if (picked != null) setState(() => _referenceDate = picked);
  }

  Future<void> _save() async {
    setState(() => _error = null);
    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    if (amount <= 0) {
      setState(() => _error = 'Amount must be greater than zero.');
      return;
    }
    if (amount > widget.invoice.outstanding + 0.01) {
      setState(() => _error =
          'Amount cannot exceed the outstanding ${money(widget.invoice.outstanding, widget.invoice.currency)}.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(invoicesControllerProvider.notifier).recordPayment(
            invoiceKind: widget.invoice.kind,
            invoiceName: widget.invoice.name,
            paidAmount: amount,
            modeOfPayment: _mode,
            postingDate: _postingDate,
            referenceNo: _referenceNo.text.trim().isEmpty
                ? null
                : _referenceNo.text.trim(),
            referenceDate: _referenceDate,
          );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not record payment.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final modes = ref.watch(modesOfPaymentProvider);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final title = widget.invoice.kind == InvoiceKind.sales
        ? 'Record Receipt'
        : 'Record Payment';
    final modeLabel = widget.invoice.kind == InvoiceKind.sales
        ? 'Mode of payment received'
        : 'Mode of payment used';

    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppDimens.xl, AppDimens.xl, AppDimens.xl, AppDimens.xl + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
                child: Text(title,
                    style: Theme.of(context).textTheme.titleLarge)),
            const SizedBox(height: AppDimens.md),
            Container(
              padding: const EdgeInsets.all(AppDimens.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppDimens.radiusLg),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.invoice.name,
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(
                                  color: AppColors.onSurface,
                                  fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(widget.invoice.partyName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Outstanding',
                        style: Theme.of(context).textTheme.labelSmall),
                    Text(
                        money(widget.invoice.outstanding,
                            widget.invoice.currency),
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 15)),
                  ],
                ),
              ]),
            ),
            const SizedBox(height: AppDimens.lg),

            TextField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: InputDecoration(
                labelText: 'Amount (${widget.invoice.currency})',
              ),
            ),
            const SizedBox(height: AppDimens.lg),

            modes.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(
                  e is ApiException
                      ? e.message
                      : 'Could not load modes of payment.',
                  style: const TextStyle(
                      color: AppColors.error, fontSize: 13)),
              data: (list) {
                if (list.isEmpty) {
                  return Text(
                      'No modes of payment configured. Payment will use the default.',
                      style: Theme.of(context).textTheme.bodySmall);
                }
                return DropdownButtonFormField<String>(
                  initialValue: _mode,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: modeLabel),
                  items: list
                      .map((m) =>
                          DropdownMenuItem(value: m.name, child: Text(m.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _mode = v),
                );
              },
            ),
            const SizedBox(height: AppDimens.lg),

            Row(children: [
              Expanded(
                child: InkWell(
                  onTap: _pickPostingDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Posting date',
                      suffixIcon:
                          Icon(Icons.calendar_today_outlined, size: 18),
                    ),
                    child: Text(_dateFmt.format(_postingDate)),
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: InkWell(
                  onTap: _pickReferenceDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Reference date (optional)',
                      suffixIcon: Icon(Icons.event_outlined, size: 18),
                    ),
                    child: Text(
                        _referenceDate == null
                            ? 'Select'
                            : _dateFmt.format(_referenceDate!),
                        style: TextStyle(
                            color: _referenceDate == null
                                ? AppColors.outline
                                : AppColors.onSurface)),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: AppDimens.lg),

            TextField(
              controller: _referenceNo,
              decoration: const InputDecoration(
                labelText: 'Reference no (cheque / UTR / txn id, optional)',
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: AppDimens.md),
              Text(_error!,
                  style:
                      const TextStyle(color: AppColors.error, fontSize: 13)),
            ],
            const SizedBox(height: AppDimens.xl),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_outline),
              label: const Text('Record & Submit'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.secondaryContainer,
                foregroundColor: AppColors.onSecondaryContainer,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool?> showRecordPaymentSheet(
        BuildContext context, InvoiceDetail invoice) =>
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXl)),
      ),
      builder: (_) => RecordPaymentSheet(invoice: invoice),
    );
