import 'package:flutter/foundation.dart';

@immutable
class DirectoryEntry {
  const DirectoryEntry({
    required this.name,
    required this.employeeName,
    this.designation,
    this.department,
    this.company,
    this.companyEmail,
    this.cellNumber,
    this.image,
  });

  final String name;
  final String employeeName;
  final String? designation;
  final String? department;
  final String? company;
  final String? companyEmail;
  final String? cellNumber;
  final String? image;

  String get initials {
    final parts = employeeName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  factory DirectoryEntry.fromJson(Map<String, dynamic> j) => DirectoryEntry(
        name: j['name'] as String,
        employeeName: (j['employee_name'] ?? j['name']) as String,
        designation: j['designation'] as String?,
        department: j['department'] as String?,
        company: j['company'] as String?,
        companyEmail: j['company_email'] as String?,
        cellNumber: j['cell_number'] as String?,
        image: j['image'] as String?,
      );
}
