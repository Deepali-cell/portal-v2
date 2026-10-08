import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_exception.dart';
import '../../../shared/widgets/followup_gap_badge.dart';
import '../../call_outcome/presentation/call_outcome_sheet.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../shared/widgets/brand_button.dart';
import '../../crm_shared/domain/crm_ref.dart';
import '../../crm_shared/presentation/activity_tab.dart';
import '../../crm_shared/presentation/assignees_tab.dart';
import '../../crm_shared/presentation/attachments_tab.dart';
import '../../crm_shared/presentation/calls_tab.dart';
import '../../crm_shared/presentation/emails_tab.dart';
import '../../crm_shared/presentation/events_tab.dart';
import '../../crm_shared/presentation/tasks_tab.dart';
import '../../crm_shared/presentation/whatsapp_tab.dart';
import '../application/lead_controller.dart';
import '../domain/models.dart';

class LeadDetailScreen extends ConsumerStatefulWidget {
  const LeadDetailScreen({super.key, required this.name});
  final String name;

  @override
  ConsumerState<LeadDetailScreen> createState() => _LeadDetailScreenState();
}

class _LeadDetailScreenState extends ConsumerState<LeadDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 9, vsync: this)
    ..addListener(() => setState(() {}));

  bool _editing = false;
  bool _saving = false;
  bool _converting = false;

  final Map<String, TextEditingController> _ctrls = {
    for (final f in [
      'salutation',
      'first_name',
      'middle_name',
      'last_name',
      'gender',
      'email',
      'mobile_no',
      'phone',
      'website',
      'organization',
      'job_title',
      'no_of_employees',
      'industry',
      'source',
      'territory',
      'lead_owner',
      'annual_revenue',
    ])
      f: TextEditingController(),
  };
  String? _status;

  CrmRef get _ref => CrmRef(doctype: 'Lead', name: widget.name);

  @override
  void dispose() {
    _tabs.dispose();
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _prime(Lead l) {
    _ctrls['salutation']!.text = l.salutation ?? '';
    _ctrls['first_name']!.text = l.firstName ?? '';
    _ctrls['middle_name']!.text = l.middleName ?? '';
    _ctrls['last_name']!.text = l.lastName ?? '';
    _ctrls['gender']!.text = l.gender ?? '';
    _ctrls['email']!.text = l.email ?? '';
    _ctrls['mobile_no']!.text = l.mobileNo ?? '';
    _ctrls['phone']!.text = l.phone ?? '';
    _ctrls['website']!.text = l.website ?? '';
    _ctrls['organization']!.text = l.organization ?? '';
    _ctrls['job_title']!.text = l.jobTitle ?? '';
    _ctrls['no_of_employees']!.text = l.noOfEmployees ?? '';
    _ctrls['industry']!.text = l.industry ?? '';
    _ctrls['source']!.text = l.source ?? '';
    _ctrls['territory']!.text = l.territory ?? '';
    _ctrls['lead_owner']!.text = l.leadOwner ?? '';
    _ctrls['annual_revenue']!.text =
        l.annualRevenue == null || l.annualRevenue == 0
        ? ''
        : l.annualRevenue.toString();
    _status = l.status;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    // Send the field value as the user typed it, INCLUDING empty strings.
    // Previously we mapped empty to null, but the backend patch endpoint
    // treats `None` as "no change to this field" — so clearing mobile/phone
    // saved 200 but silently kept the old value (user saw 'Saved' then
    // reopen restored the original). Empty string = "clear this field".
    final fields = <String, dynamic>{
      for (final e in _ctrls.entries) e.key: e.value.text.trim(),
      if (_status != null) 'status': _status,
    };
    // annual_revenue is numeric — empty means "clear", non-empty parses.
    final revText = (fields['annual_revenue'] as String?)?.trim() ?? '';
    fields['annual_revenue'] = revText.isEmpty
        ? 0
        : (double.tryParse(revText) ?? 0);
    try {
      await ref
          .read(leadsControllerProvider.notifier)
          .save(widget.name, fields);
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
        title: const Text('Convert to Opportunity?'),
        content: const Text(
          "An Opportunity will be created from this lead. That's the first "
          "step of the sales flow: Lead → Opportunity → Customer. Open the "
          "Opportunity later to convert it into a Customer. The lead will be "
          "marked 'Converted'.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Convert'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _converting = true);
    try {
      final opportunity = await ref
          .read(leadsControllerProvider.notifier)
          .convertToOpportunity(widget.name);
      if (!mounted) return;
      _snack(
        opportunity.isNotEmpty
            ? 'Created opportunity: $opportunity'
            : 'Lead converted',
      );
      // Keep the user on the lead screen; the status now shows Converted and
      // the new Opportunity appears on the Opportunities tab.
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
    final async = ref.watch(leadDetailProvider(widget.name));
    final statuses =
        ref.watch(leadsControllerProvider).value?.statuses ?? const <String>[];
    final onDetailsTab = _tabs.index == 0;
    final lead = async.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(lead?.title ?? 'Lead'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () => ref.invalidate(leadDetailProvider(widget.name)),
          ),
          if (onDetailsTab && lead != null && !_editing)
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () {
                _prime(lead);
                setState(() => _editing = true);
              },
            ),
          if (onDetailsTab && _editing) ...[
            TextButton(
              onPressed: _saving
                  ? null
                  : () => setState(() => _editing = false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save'),
            ),
          ],
          if (onDetailsTab && lead != null && !_editing && !lead.converted)
            IconButton(
              tooltip: 'Convert to Opportunity',
              icon: _converting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
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
            // Order tweaked 2026-06-25: Calls pulled left so the most-used
            // tabs (Activity, Calls, Notes, Tasks) cluster early.
            const Tab(text: 'Activity'),
            Tab(text: 'Calls${_count(lead?.counts.calls)}'),
            const Tab(text: 'WhatsApp'),
            Tab(text: 'Tasks${_count(lead?.counts.tasks)}'),
            Tab(text: 'Attachments${_count(lead?.counts.attachments)}'),
            Tab(text: 'Email${_count(lead?.counts.emails)}'),
            Tab(text: 'Assign to${_count(lead?.assignees.length)}'),
            Tab(text: 'Events${_count(lead?.counts.events)}'),
          ],
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _err(context, e),
        data: (lead) => TabBarView(
          controller: _tabs,
          children: [
            _DetailsTab(
              lead: lead,
              editing: _editing,
              ctrls: _ctrls,
              statuses: statuses,
              status: _status,
              onStatus: (s) => setState(() => _status = s),
            ),
            ActivityTab(crmRef: _ref),
            CallsTab(crmRef: _ref, suggestedPhone: lead.mobileNo ?? lead.phone),
            WhatsAppTab(
              crmRef: _ref,
              suggestedPhone: lead.mobileNo ?? lead.phone,
            ),
            CrmTasksTab(crmRef: _ref),
            AttachmentsTab(crmRef: _ref),
            EmailsTab(crmRef: _ref, suggestedTo: lead.email),
            AssigneesTab(crmRef: _ref),
            EventsTab(crmRef: _ref),
          ],
        ),
      ),
      bottomNavigationBar:
          (onDetailsTab && !_editing && lead != null && !lead.converted)
          ? Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.lg,
                AppDimens.sm,
                AppDimens.lg,
                AppDimens.lg,
              ),
              child: BrandButton(
                label: 'Convert to Opportunity',
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 40, color: AppColors.danger),
          const SizedBox(height: AppDimens.md),
          Text(
            e is ApiException ? e.message : 'Could not load.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimens.lg),
          OutlinedButton(
            onPressed: () => ref.invalidate(leadDetailProvider(widget.name)),
            child: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}

class _DetailsTab extends StatelessWidget {
  const _DetailsTab({
    required this.lead,
    required this.editing,
    required this.ctrls,
    required this.statuses,
    required this.status,
    required this.onStatus,
  });

  final Lead lead;
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
        _Header(lead: lead),
        const SizedBox(height: AppDimens.lg),
        _QuickContact(lead: lead),
        const SizedBox(height: AppDimens.xl),
        _section('Identity', [
          _F('Salutation', lead.salutation, ctrls['salutation']),
          _F('First name', lead.firstName, ctrls['first_name']),
          _F('Middle name', lead.middleName, ctrls['middle_name']),
          _F('Last name', lead.lastName, ctrls['last_name']),
          _F('Gender', lead.gender, ctrls['gender']),
        ]),
        _section('Contact', [
          _F(
            'Email',
            lead.email,
            ctrls['email'],
            keyboardType: TextInputType.emailAddress,
          ),
          _F(
            'Mobile',
            lead.mobileNo,
            ctrls['mobile_no'],
            keyboardType: TextInputType.phone,
          ),
          _F(
            'Phone',
            lead.phone,
            ctrls['phone'],
            keyboardType: TextInputType.phone,
          ),
          _F(
            'Website',
            lead.website,
            ctrls['website'],
            keyboardType: TextInputType.url,
          ),
        ]),
        _section('Organization', [
          _F('Organization', lead.organization, ctrls['organization']),
          _F('Job title', lead.jobTitle, ctrls['job_title']),
          _F('Employees', lead.noOfEmployees, ctrls['no_of_employees']),
          _F('Industry', lead.industry, ctrls['industry']),
          _F(
            'Annual revenue',
            lead.annualRevenue == null || lead.annualRevenue == 0
                ? null
                : lead.annualRevenue.toString(),
            ctrls['annual_revenue'],
            keyboardType: TextInputType.number,
          ),
        ]),
        _salesSection(context),
        const SizedBox(height: 80),
      ],
    );
  }

  /// A section that, in view mode, shows ONLY filled fields and hides itself
  /// entirely when nothing is filled; in edit mode every field is editable so
  /// empties can be filled in (and then they start showing on view).
  Widget _section(String title, List<_F> fields) {
    if (editing) {
      return _Section(
        title: title,
        children: [for (final f in fields) _editor(f)],
      );
    }
    final filled = fields
        .where((f) => (f.value ?? '').trim().isNotEmpty)
        .toList();
    if (filled.isEmpty) return const SizedBox.shrink();
    return _Section(
      title: title,
      children: [for (final f in filled) _viewRow(f.label, f.value!)],
    );
  }

  Widget _salesSection(BuildContext context) {
    if (editing) {
      return _Section(
        title: 'Sales',
        children: [
          _statusEditor(context),
          _editor(_F('Source', null, ctrls['source'])),
          _editor(_F('Territory', null, ctrls['territory'])),
          _editor(_F('Owner', null, ctrls['lead_owner'])),
        ],
      );
    }
    final rows = <Widget>[
      if (lead.status.trim().isNotEmpty) _viewRow('Status', lead.status),
      if ((lead.source ?? '').trim().isNotEmpty)
        _viewRow('Source', lead.source!),
      if ((lead.territory ?? '').trim().isNotEmpty)
        _viewRow('Territory', lead.territory!),
      if ((lead.leadOwner ?? '').trim().isNotEmpty)
        _viewRow('Owner', lead.leadOwner!),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return _Section(title: 'Sales', children: rows);
  }

  Widget _statusEditor(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppDimens.xs),
    child: DropdownButtonFormField<String>(
      initialValue: statuses.contains(status) ? status : null,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Status'),
      items: statuses
          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
          .toList(),
      onChanged: onStatus,
    ),
  );

  Widget _editor(_F f) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppDimens.xs),
    child: TextField(
      controller: f.ctrl,
      keyboardType: f.keyboardType,
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
          child: Text(
            label,
            style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
  );
}

/// One editable detail field: its label, current value and the controller the
/// edit form binds to.
class _F {
  const _F(this.label, this.value, this.ctrl, {this.keyboardType});
  final String label;
  final String? value;
  final TextEditingController? ctrl;
  final TextInputType? keyboardType;
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
          AppDimens.lg,
          AppDimens.md,
          AppDimens.lg,
          AppDimens.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: TextStyle(
                color: AppColors.inkMuted,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: AppDimens.sm),
            ...children,
          ],
        ),
      ),
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.lead});
  final Lead lead;
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: AppColors.navy,
          child: Text(
            lead.initials,
            style: TextStyle(
              color: AppColors.canvas,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: AppDimens.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lead.title,
                style: Theme.of(context).textTheme.titleLarge,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (lead.organization != null &&
                  lead.organization!.isNotEmpty &&
                  lead.organization != lead.title)
                Text(
                  lead.organization!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: AppDimens.xs),
              Wrap(
                spacing: AppDimens.xs,
                runSpacing: AppDimens.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _chip(lead.status, AppColors.navy, filled: true),
                  // Only show a separate "Converted" chip when the status text
                  // isn't already "Converted" — otherwise the header showed the
                  // same badge twice.
                  if (lead.converted &&
                      lead.status.trim().toLowerCase() != 'converted')
                    _chip('Converted', AppColors.success, filled: true),
                  if (lead.daysSinceContact != null &&
                      lead.daysSinceContact! >= 1)
                    FollowupGapBadge(days: lead.daysSinceContact!),
                ],
              ),
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
    child: Text(
      label,
      style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 12),
    ),
  );
}

class _QuickContact extends StatelessWidget {
  const _QuickContact({required this.lead});
  final Lead lead;

  Future<void> _launch(Uri uri, BuildContext context) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No app available to handle this.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final actions = <_Quick>[];
    // Single Call button — dials mobile if present, else the office phone.
    // The two used to render as separate quick actions ("Call" + "Phone"),
    // but that made the row look duplicated and users kept mis-tapping.
    // The secondary number is still visible in the CONTACT section for
    // long-press copy.
    final primaryDialable = (lead.mobileNo?.isNotEmpty == true)
        ? lead.mobileNo!
        : (lead.phone?.isNotEmpty == true ? lead.phone! : null);
    if (primaryDialable != null) {
      actions.add(
        _Quick(
          Icons.phone,
          'Call',
          () => _launch(Uri(scheme: 'tel', path: primaryDialable), context),
        ),
      );
    }
    if (lead.email != null && lead.email!.isNotEmpty) {
      actions.add(
        _Quick(
          Icons.mail_outline,
          'Email',
          () => _launch(Uri(scheme: 'mailto', path: lead.email!), context),
        ),
      );
    }
    if (lead.website != null && lead.website!.isNotEmpty) {
      actions.add(
        _Quick(
          Icons.public,
          'Web',
          () => _launch(Uri.parse(_norm(lead.website!)), context),
        ),
      );
    }
    // Log-outcome action is always available — works even for leads with no
    // contact info, since outcomes can capture "No answer" or "Wrong number".
    actions.add(
      _Quick(Icons.phone_callback, 'Log call', () async {
        final newId = await showCallOutcomeSheet(
          context,
          referenceDoctype: 'Lead',
          referenceDocname: lead.name,
          parentLabel: lead.title,
        );
        if (newId != null && context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Call outcome saved.')));
        }
      }),
    );
    if (actions.isEmpty) return const SizedBox.shrink();
    return Row(
      children: actions
          .map((a) => Expanded(child: _QuickButton(action: a)))
          .toList(),
    );
  }

  String _norm(String u) =>
      (u.startsWith('http://') || u.startsWith('https://')) ? u : 'https://$u';
}

class _Quick {
  const _Quick(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _QuickButton extends StatelessWidget {
  const _QuickButton({required this.action});
  final _Quick action;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: OutlinedButton.icon(
        onPressed: action.onTap,
        icon: Icon(action.icon, size: 18),
        label: Text(action.label),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(44),
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.sm),
        ),
      ),
    );
  }
}
