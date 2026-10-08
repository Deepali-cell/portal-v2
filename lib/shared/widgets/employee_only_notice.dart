import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';

/// Friendly full-screen placeholder for employee-personal screens (My
/// Timesheet, Leave, Expenses, My Attendance, Payslips) when the signed-in
/// account has no linked Employee record - e.g. an Administrator / System
/// Manager. Shown instead of a raw error or an empty personal view so it is
/// clear the screen is a self-service feature meant for employees.
class EmployeeOnlyNotice extends StatelessWidget {
  const EmployeeOnlyNotice({super.key, this.feature});

  /// Optional feature name to personalise the message, e.g. "Timesheet".
  final String? feature;

  @override
  Widget build(BuildContext context) {
    final what = feature == null ? 'This screen' : feature!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.badge_outlined,
                size: 56, color: AppColors.onSurfaceVariant),
            const SizedBox(height: AppDimens.md),
            Text(
              '$what is for employees',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppDimens.sm),
            Text(
              'Your account is not linked to an Employee record, so there is '
              'nothing personal to show here. This is a self-service feature '
              'that employees use for their own records.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
