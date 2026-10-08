import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/format/money.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../shared/widgets/brand_button.dart';
import '../../call_outcome/presentation/call_outcome_sheet.dart';
import '../../crm_shared/domain/crm_ref.dart';
import 'probability_pill.dart';
import '../../crm_shared/presentation/activity_tab.dart';
import '../../crm_shared/presentation/assignees_tab.dart';
import '../../crm_shared/presentation/attachments_tab.dart';
import '../../crm_shared/presentation/calls_tab.dart';
import '../../crm_shared/presentation/emails_tab.dart';
import '../../crm_shared/presentation/events_tab.dart';
import '../../crm_shared/presentation/tasks_tab.dart';
import '../../crm_shared/presentation/whatsapp_tab.dart';
import '../application/deal_controller.dart';
import '../domain/models.dart';

class DealDetailScreen extends ConsumerStatefulWidget {
  const DealDetailScreen({super.key, required this.name});
  final String name;

  @override
  ConsumerState<DealDetailScreen> createState() => _DealDetailScreenState();
}

class _DealDetailScreenState extends ConsumerState<DealDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 9, vsync: this)
    ..addListener(() => setState(() {}));

  bool _editing = false;
  bool _saving = false;
  bool _converting = false;

  final Map<String, TextEditingController> _ctrls = {
    for (final f in [
      'salutation','first_name','last_name','gender',
      'email','mobile_no','phone','website',
      'organization','organization_name','job_title','no_of_employees','industry','source','territory','deal_owner',
      'deal_value','probability','annual_revenue','next_step',
    ]) f: TextEditingController()
  };
  String? _status;

  CrmRef get _ref => CrmRef(doctype: 'Opportunity', name: widget.name);

  @override
  void dispose() {
    _tabs.dispose();
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _prime(Deal d) {
    _ctrls['salutation']!.text = d.salutation ?? '';
    _ctrls['first_name']!.text = d.firstName ?? '';
    _ctrls['last_name']!.text = d.lastName ?? '';
    _ctrls['gender']!.text = d.gender ?? '';
    _ctrls['email']!.text = d.email ?? '';
    _ctrls['mobile_no']!.text = d.mobileNo ?? '';
    _ctrls['phone']!.text = d.phone ?? '';
    _ctrls['website']!.text = d.website ?? '';
    _ctrls['organization']!.text = d.organization ?? '';
    _ctrls['organization_name']!.text = d.organizationName ?? '';
    _ctrls['job_title']!.text = d.jobTitle ?? '';
    _ctrls['no_of_employees']!.text = d.noOfEmployees ?? '';
    _ctrls['industry']!.text = d.industry ?? '';
    _ctrls['source']!.text = d.source ?? '';
    _ctrls['territory']!.text = d.territory ?? '';
    _ctrls['deal_owner']!.text = d.dealOwner ?? '';
    _ctrls['deal_value']!.text = d.dealValue == 0 ? '' : d.dealValue.toString();
    _ctrls['annual_revenue']!.text = d.annualRevenue == 0 ? '' : d.annualRevenue.toString();
    _ctrls['probability']!.text = d.probability == null ? '' : d.probability!.toString();
    _ctrls['next_step']!.text = d.nextStep ?? '';
    _status = d.status;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final fields = <String, dynamic>{
      for (final e in _ctrls.entries)
        e.key: e.value.text.trim().isEmpty ? null : e.value.text.trim(),
      if (_status != null) 'status': _status,
    };
    fields['deal_value'] = double.tryParse((fields['deal_value'] ?? '').toString());
    fields['annual_revenue'] = double.tryParse((fields['annual_revenue'] ?? '').toString());
    fields['probability'] = double.tryParse((fields['probability'] ?? '').toString());
    try {
      await ref.read(dealsControllerProvider.notifier).save(widget.name, fields);
      if (mounted) setState(() => _editing = false);
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _convert() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Convert to Customer?'),
        content: const Text(
            "A Customer will be created from this opportunity — the final step "
            "of the sales flow: Lead → Opportunity → Customer. After that the "
            "regular ERP flow opens up: Customer → Quotation → Sales Order → "
            "Sales Invoice. The opportunity will be marked 'Converted'."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Convert')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _converting = true);
    try {
      final customer = await ref
          .read(dealsControllerProvider.notifier)
          .convertToCustomer(widget.name);
      if (!mounted) return;
      _snack(customer.isNotEmpty
          ? 'Created customer: $customer'
          : 'Opportunity converted');
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _converting = false);
    }
  }

  void _snack(String s) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(s)));

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(dealDetailProvider(widget.name));
    final statuses =
        ref.watch(dealsControllerProvider).value?.statuses ?? const <String>[];
    final onDetailsTab = _tabs.index == 0;
    final deal = async.value;
    // An Opportunity that's already Converted (became a Customer) or Lost
    // shouldn't offer the convert action again.
    final canConvert = deal != null &&
        deal.status != 'Converted' &&
        deal.status != 'Lost';

    return Scaffold(
      appBar: AppBar(
        title: Text(deal?.title ?? 'Opportunity'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () => ref.invalidate(dealDetailProvider(widget.name)),
          ),
          if (onDetailsTab && deal != null && !_editing)
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () {
                _prime(deal);
                setState(() => _editing = true);
              },
            ),
          if (onDetailsTab && _editing) ...[
            TextButton(
              onPressed: _saving ? null : () => setState(() => _editing = false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save'),
            ),
          ],
          if (onDetailsTab && !_editing && canConvert)
            IconButton(
              tooltip: 'Convert to Customer',
              icon: _converting
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.swap_horiz),
              onPressed: _converting ? null : _convert,
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppColors.navy,
          unselectedLabelColor: AppColors.inkMuted,
          indicatorColor: AppColors.navy,
          tabs: [
            const Tab(text: 'Details'),
            const Tab(text: 'WhatsApp'),
            Tab(text: 'Attachments${_count(deal?.counts.attachments)}'),
            Tab(text: 'Email${_count(deal?.counts.emails)}'),
            Tab(text: 'Assign to${_count(deal?.assignees.length)}'),
            const Tab(text: 'Activity'),
            Tab(text: 'Tasks${_count(deal?.counts.tasks)}'),
            Tab(text: 'Calls${_count(deal?.counts.calls)}'),
            Tab(text: 'Events${_count(deal?.counts.events)}'),
          ],
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _err(context, e),
        data: (deal) => TabBarView(
          controller: _tabs,
          children: [
            _DetailsTab(deal: deal, editing: _editing, ctrls: _ctrls, statuses: statuses, status: _status, onStatus: (s) => setState(() => _status = s)),
            WhatsAppTab(
                crmRef: _ref, suggestedPhone: deal.mobileNo ?? deal.phone),
            AttachmentsTab(crmRef: _ref),
            EmailsTab(crmRef: _ref, suggestedTo: deal.email),
            AssigneesTab(crmRef: _ref),
            ActivityTab(crmRef: _ref),
            CrmTasksTab(crmRef: _ref),
            CallsTab(crmRef: _ref, suggestedPhone: deal.mobileNo ?? deal.phone),
            EventsTab(crmRef: _ref),
          ],
        ),
      ),
      bottomNavigationBar: (onDetailsTab && !_editing && canConvert)
          ? Padding(
              padding: const EdgeInsets.fromLTRB(AppDimens.lg, AppDimens.sm,
                  AppDimens.lg, AppDimens.lg),
              child: BrandButton(
                label: 'Convert to Customer',
                icon: Icons.swap_horiz,
                loading: _converting,
                onPressed: _convert,
              ),
            )
          : null,
    );
  }

  String _count(int? n) => (n == null || n == 0) ? '' : '  $n';

  Widget _err(BuildContext context, Object e) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.xl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.error_outline, size: 40, color: AppColors.danger),
            const SizedBox(height: AppDimens.md),
            Text(e is ApiException ? e.message : 'Could not load.',
                textAlign: TextAlign.center),
            const SizedBox(height: AppDimens.lg),
            OutlinedButton(
              onPressed: () => ref.invalidate(dealDetailProvider(widget.name)),
              child: const Text('Retry'),
            ),
          ]),
        ),
      );
}

class _DetailsTab extends StatelessWidget {
  const _DetailsTab({
    required this.deal,
    required this.editing,
    required this.ctrls,
    required this.statuses,
    required this.status,
    required this.onStatus,
  });

  final Deal deal;
  final bool editing;
  final Map<String, TextEditingController> ctrls;
  final List<String> statuses;
  final String? status;
  final ValueChanged<String?> onStatus;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppDimens.screenPadding),
      children: [
        _DealHeader(deal: deal),
        const SizedBox(height: AppDimens.lg),
        _QuickContact(deal: deal),
        const SizedBox(height: AppDimens.xl),
        _oppSection(context),
        _section('Contact', [
          _F('Salutation', deal.salutation, ctrls['salutation']),
          _F('First name', deal.firstName, ctrls['first_name']),
          _F('Last name', deal.lastName, ctrls['last_name']),
          _F('Gender', deal.gender, ctrls['gender']),
          _F('Email', deal.email, ctrls['email'], keyboardType: TextInputType.emailAddress),
          _F('Mobile', deal.mobileNo, ctrls['mobile_no'], keyboardType: TextInputType.phone),
          _F('Phone', deal.phone, ctrls['phone'], keyboardType: TextInputType.phone),
          _F('Website', deal.website, ctrls['website'], keyboardType: TextInputType.url),
        ]),
        _section('Organization', [
          _F('Organization', deal.organization, ctrls['organization']),
          _F('Display name', deal.organizationName, ctrls['organization_name']),
          _F('Job title', deal.jobTitle, ctrls['job_title']),
          _F('Employees', deal.noOfEmployees, ctrls['no_of_employees']),
          _F('Industry', deal.industry, ctrls['industry']),
        ]),
        const SizedBox(height: 80),
      ],
    );
  }

  /// The Opportunity section has special rows (money, probability pill, status
  /// dropdown), so it's built by hand. In view mode only filled values show;
  /// in edit mode every field is editable.
  Widget _oppSection(BuildContext context) {
    if (editing) {
      const numKb = TextInputType.numberWithOptions(decimal: true);
      return _Section(title: 'Opportunity', children: [
        _statusEditor(context),
        _editor(_F('Opportunity value', null, ctrls['deal_value'],
            keyboardType: numKb, numberOnly: true)),
        _editor(_F('Probability %', null, ctrls['probability'],
            keyboardType: numKb, numberOnly: true)),
        _editor(_F('Annual revenue', null, ctrls['annual_revenue'],
            keyboardType: numKb, numberOnly: true)),
        _editor(_F('Next step', null, ctrls['next_step'])),
        _editor(_F('Owner', null, ctrls['deal_owner'])),
        _editor(_F('Source', null, ctrls['source'])),
        _editor(_F('Territory', null, ctrls['territory'])),
      ]);
    }
    final rows = <Widget>[
      if (deal.status.trim().isNotEmpty) _viewRow('Status', deal.status),
      if (deal.dealValue != 0)
        _viewRow('Opportunity value', money(deal.dealValue, deal.currency)),
      if (deal.probability != null)
        _ProbabilityRow(probability: deal.probability),
      if (deal.annualRevenue != 0)
        _viewRow('Annual revenue', money(deal.annualRevenue, deal.currency)),
      if ((deal.nextStep ?? '').trim().isNotEmpty)
        _viewRow('Next step', deal.nextStep!),
      if ((deal.dealOwner ?? '').trim().isNotEmpty)
        _viewRow('Owner', deal.dealOwner!),
      if ((deal.source ?? '').trim().isNotEmpty) _viewRow('Source', deal.source!),
      if ((deal.territory ?? '').trim().isNotEmpty)
        _viewRow('Territory', deal.territory!),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return _Section(title: 'Opportunity', children: rows);
  }

  /// A plain section that, in view mode, shows ONLY filled fields and hides
  /// itself when nothing is filled; in edit mode every field is editable.
  Widget _section(String title, List<_F> fields) {
    if (editing) {
      return _Section(
          title: title, children: [for (final f in fields) _editor(f)]);
    }
    final filled =
        fields.where((f) => (f.value ?? '').trim().isNotEmpty).toList();
    if (filled.isEmpty) return const SizedBox.shrink();
    return _Section(
        title: title,
        children: [for (final f in filled) _viewRow(f.label, f.value!)]);
  }

  Widget _statusEditor(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.xs),
        child: DropdownButtonFormField<String>(
          initialValue: statuses.contains(status) ? status : null,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Status'),
          items: statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: onStatus,
        ),
      );

  Widget _editor(_F f) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.xs),
        child: TextField(
          controller: f.ctrl,
          keyboardType: f.keyboardType,
          inputFormatters: f.numberOnly
              ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
              : null,
          decoration: InputDecoration(labelText: f.label),
        ),
      );

  Widget _viewRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(label,
                  style: TextStyle(color: AppColors.inkMuted, fontSize: 13)),
            ),
            Expanded(
              child: Text(value,
                  style: TextStyle(
                      color: AppColors.ink, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      );
}

/// One editable detail field: its label, current value and the controller the
/// edit form binds to.
class _F {
  const _F(this.label, this.value, this.ctrl,
      {this.keyboardType, this.numberOnly = false});
  final String label;
  final String? value;
  final TextEditingController? ctrl;
  final TextInputType? keyboardType;
  final bool numberOnly;
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppDimens.lg),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppDimens.lg, AppDimens.md, AppDimens.lg, AppDimens.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.toUpperCase(),
                    style: TextStyle(
                        color: AppColors.inkMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        letterSpacing: 0.6)),
                const SizedBox(height: AppDimens.sm),
                ...children,
              ],
            ),
          ),
        ),
      );
}

class _DealHeader extends StatelessWidget {
  const _DealHeader({required this.deal});
  final Deal deal;
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: AppColors.navy,
          child: Text((deal.title.isNotEmpty ? deal.title[0] : '?').toUpperCase(),
              style: TextStyle(
                  color: AppColors.canvas, fontSize: 18, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: AppDimens.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(deal.title,
                  style: Theme.of(context).textTheme.titleLarge,
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              if (deal.dealValue > 0)
                Text(money(deal.dealValue, deal.currency),
                    style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.w700)),
              const SizedBox(height: AppDimens.xs),
              Wrap(spacing: AppDimens.xs, runSpacing: AppDimens.xs, children: [
                _chip(deal.status, AppColors.navy, filled: true),
              ]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, Color c, {bool filled = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.sm, vertical: 3),
        decoration: BoxDecoration(
          color: filled ? c.withValues(alpha: 0.12) : Colors.transparent,
          border: filled ? null : Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        ),
        child: Text(label,
            style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 12)),
      );
}

class _QuickContact extends StatelessWidget {
  const _QuickContact({required this.deal});
  final Deal deal;

  Future<void> _launch(Uri uri, BuildContext context) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No app available to handle this.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final actions = <_Quick>[];
    final callNo = (deal.mobileNo != null && deal.mobileNo!.isNotEmpty)
        ? deal.mobileNo!
        : (deal.phone != null && deal.phone!.isNotEmpty ? deal.phone! : null);
    if (callNo != null) {
      actions.add(_Quick(Icons.phone, 'Call', () => _launch(Uri(scheme: 'tel', path: callNo), context)));
    }
    if (deal.email != null && deal.email!.isNotEmpty) {
      actions.add(_Quick(Icons.mail_outline, 'Email', () => _launch(Uri(scheme: 'mailto', path: deal.email!), context)));
    }
    if (deal.website != null && deal.website!.isNotEmpty) {
      actions.add(_Quick(Icons.public, 'Web', () => _launch(Uri.parse(_norm(deal.website!)), context)));
    }
    actions.add(_Quick(Icons.phone_callback, 'Log call', () async {
      final newId = await showCallOutcomeSheet(
        context,
        referenceDoctype: 'Opportunity',
        referenceDocname: deal.name,
        parentLabel: deal.title,
      );
      if (newId != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Call outcome saved.')));
      }
    }));
    if (actions.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: AppDimens.sm,
      runSpacing: AppDimens.sm,
      children: actions.map((a) => _QuickButton(action: a)).toList(),
    );
  }

  String _norm(String u) => (u.startsWith('http://') || u.startsWith('https://')) ? u : 'https://$u';
}

class _Quick {
  const _Quick(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// Compact quick-action pill: a tinted rounded button with icon + full label.
/// Laid out in a Wrap so 4-5 actions flow onto a second line if needed,
/// keeping every label fully readable (no squeezing or ellipsis).
class _QuickButton extends StatelessWidget {
  const _QuickButton({required this.action});
  final _Quick action;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.navy.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(AppDimens.radiusXl),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: action.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.md, vertical: AppDimens.sm + 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(action.icon, size: 18, color: AppColors.navy),
              const SizedBox(width: AppDimens.xs + 2),
              Text(
                action.label,
                style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Read-only probability row that renders the colour-coded [ProbabilityPill]
/// instead of plain text. Used in the Deal detail screen when NOT editing.
class _ProbabilityRow extends StatelessWidget {
  const _ProbabilityRow({required this.probability});
  final double? probability;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 110,
            child: Text('Probability',
                style: TextStyle(color: AppColors.inkMuted, fontSize: 13)),
          ),
          ProbabilityPill(percent: probability, dense: false),
        ],
      ),
    );
  }
}
