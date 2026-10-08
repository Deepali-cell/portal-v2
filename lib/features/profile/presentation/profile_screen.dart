import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/profile.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authControllerProvider.select((s) => s.profile));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => context.pop(),
        ),
        title: const Text('My Profile'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () =>
                ref.read(authControllerProvider.notifier).refresh(),
          ),
          if (profile?.employee != null)
            IconButton(
              tooltip: 'Edit',
              icon: Icon(Icons.edit_outlined, color: AppColors.primary),
              onPressed: () => _openEdit(context, ref, profile!.employee!),
            ),
        ],
      ),
      body: profile == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () =>
                  ref.read(authControllerProvider.notifier).refresh(),
              child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                  AppDimens.screenPadding,
                  AppDimens.md,
                  AppDimens.screenPadding,
                  AppDimens.xl),
              children: [
                _Hero(profile: profile),
                const SizedBox(height: AppDimens.lg),
                if (profile.employee != null) ...[
                  _InfoCard(title: 'Work', rows: [
                    _Row(label: 'Employee ID', value: profile.employee!.name),
                    _Row(label: 'Designation', value: profile.employee!.designation),
                    _Row(label: 'Department', value: profile.employee!.department),
                    _Row(label: 'Company', value: profile.employee!.company),
                    _Row(
                        label: 'Date of Joining',
                        value: profile.employee!.dateOfJoining),
                  ]),
                  const SizedBox(height: AppDimens.md),
                  _InfoCard(title: 'Contact', rows: [
                    _Row(label: 'Company Email', value: profile.employee!.companyEmail),
                    _Row(label: 'Personal Email', value: profile.employee!.personalEmail),
                    _Row(label: 'Mobile', value: profile.employee!.cellNumber),
                    _Row(label: 'Address', value: profile.employee!.currentAddress),
                  ]),
                  const SizedBox(height: AppDimens.md),
                  _InfoCard(title: 'Emergency Contact', rows: [
                    _Row(
                        label: 'Contact name',
                        value: profile.employee!.emergencyContact),
                    _Row(
                        label: 'Phone', value: profile.employee!.emergencyPhone),
                  ]),
                ] else
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimens.lg),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: AppColors.outline),
                          const SizedBox(width: AppDimens.md),
                          Expanded(
                              child: Text(
                                  'No Employee record is linked to your account. Ask HR to link it so you can manage your profile here.',
                                  style: Theme.of(context).textTheme.bodyMedium)),
                        ],
                      ),
                    ),
                  ),
              ],
              ),
            ),
    );
  }

  Future<void> _openEdit(
      BuildContext context, WidgetRef ref, Employee employee) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXl)),
      ),
      builder: (_) => _EditSheet(employee: employee),
    );
    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profile updated.')));
    }
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.profile});
  final Profile profile;
  @override
  Widget build(BuildContext context) {
    final emp = profile.employee;
    return Container(
      padding: const EdgeInsets.all(AppDimens.lg),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
      ),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.secondaryContainer,
            ),
            alignment: Alignment.center,
            child: Text(profile.initials,
                style: TextStyle(
                    color: AppColors.onSecondaryContainer,
                    fontWeight: FontWeight.w700,
                    fontSize: 28)),
          ),
          const SizedBox(height: AppDimens.md),
          Text(profile.fullName,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.onPrimary, fontWeight: FontWeight.w700)),
          if (emp?.designation != null && emp!.designation!.isNotEmpty)
            Text(emp.designation!,
                style: TextStyle(
                    color: AppColors.primaryFixedDim, fontSize: 13)),
          const SizedBox(height: 4),
          Text(profile.user,
              style: TextStyle(
                  color: AppColors.primaryFixedDim, fontSize: 12)),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.rows});
  final String title;
  final List<_Row> rows;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppDimens.md, AppDimens.md, AppDimens.md, AppDimens.sm),
            child: Text(title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(
                  height: 1, indent: 16, color: AppColors.outlineVariant),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.md, vertical: AppDimens.sm + 2),
              child: rows[i],
            ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String? value;
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(label,
              style: Theme.of(context).textTheme.bodySmall),
        ),
        const SizedBox(width: AppDimens.sm),
        Expanded(
          child: Text(value == null || value!.isEmpty ? '-' : value!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.onSurface, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}

class _EditSheet extends ConsumerStatefulWidget {
  const _EditSheet({required this.employee});
  final Employee employee;
  @override
  ConsumerState<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends ConsumerState<_EditSheet> {
  late final TextEditingController _personalEmail =
      TextEditingController(text: widget.employee.personalEmail ?? '');
  late final TextEditingController _cell =
      TextEditingController(text: widget.employee.cellNumber ?? '');
  late final TextEditingController _address =
      TextEditingController(text: widget.employee.currentAddress ?? '');
  late final TextEditingController _emergencyContact =
      TextEditingController(text: widget.employee.emergencyContact ?? '');
  late final TextEditingController _emergencyPhone =
      TextEditingController(text: widget.employee.emergencyPhone ?? '');

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _personalEmail,
      _cell,
      _address,
      _emergencyContact,
      _emergencyPhone,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).updateMyProfile({
        'personal_email': _personalEmail.text.trim(),
        'cell_number': _cell.text.trim(),
        'current_address': _address.text.trim(),
        'emergency_phone_number': _emergencyPhone.text.trim(),
        'person_to_be_contacted': _emergencyContact.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not save. Please try again.');
      }
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
                child: Text('Edit profile',
                    style: Theme.of(context).textTheme.titleLarge)),
            const SizedBox(height: AppDimens.xl),
            TextField(
                controller: _personalEmail,
                keyboardType: TextInputType.emailAddress,
                decoration:
                    const InputDecoration(labelText: 'Personal email')),
            const SizedBox(height: AppDimens.lg),
            TextField(
                controller: _cell,
                keyboardType: TextInputType.phone,
                decoration:
                    const InputDecoration(labelText: 'Mobile number')),
            const SizedBox(height: AppDimens.lg),
            TextField(
                controller: _address,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                    labelText: 'Current address',
                    alignLabelWithHint: true)),
            const SizedBox(height: AppDimens.lg),
            TextField(
                controller: _emergencyContact,
                decoration: const InputDecoration(
                    labelText: 'Emergency contact name')),
            const SizedBox(height: AppDimens.lg),
            TextField(
                controller: _emergencyPhone,
                keyboardType: TextInputType.phone,
                decoration:
                    const InputDecoration(labelText: 'Emergency phone')),
            if (_error != null) ...[
              const SizedBox(height: AppDimens.md),
              Text(_error!,
                  style: const TextStyle(
                      color: AppColors.error, fontSize: 13)),
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
                  : const Icon(Icons.check, size: 18),
              label: const Text('Save changes'),
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
