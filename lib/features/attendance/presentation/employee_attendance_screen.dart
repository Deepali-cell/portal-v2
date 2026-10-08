import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'widgets/month_calendar_view.dart';

/// One employee's monthly attendance calendar. Opened from the All-Attendance
/// or HR-Management roster. [canManage] enables the HR mark actions.
class EmployeeAttendanceScreen extends StatelessWidget {
  const EmployeeAttendanceScreen({
    super.key,
    required this.employee,
    required this.employeeName,
    this.canManage = false,
  });

  final String employee;
  final String employeeName;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(employeeName.isNotEmpty ? employeeName : employee),
      ),
      body: MonthCalendarView(employee: employee, canManage: canManage),
    );
  }
}
