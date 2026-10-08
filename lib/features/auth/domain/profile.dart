import 'package:flutter/foundation.dart';

@immutable
class Employee {
  const Employee({
    required this.name,
    required this.employeeName,
    this.designation,
    this.department,
    this.company,
    this.image,
    this.dateOfJoining,
    this.companyEmail,
    this.personalEmail,
    this.cellNumber,
    this.currentAddress,
    this.emergencyPhone,
    this.emergencyContact,
  });

  final String name;
  final String employeeName;
  final String? designation;
  final String? department;
  final String? company;
  final String? image;
  final String? dateOfJoining;
  final String? companyEmail;
  final String? personalEmail;
  final String? cellNumber;
  final String? currentAddress;
  final String? emergencyPhone;
  final String? emergencyContact;

  Employee copyWith({
    String? personalEmail,
    String? cellNumber,
    String? currentAddress,
    String? emergencyPhone,
    String? emergencyContact,
  }) =>
      Employee(
        name: name,
        employeeName: employeeName,
        designation: designation,
        department: department,
        company: company,
        image: image,
        dateOfJoining: dateOfJoining,
        companyEmail: companyEmail,
        personalEmail: personalEmail ?? this.personalEmail,
        cellNumber: cellNumber ?? this.cellNumber,
        currentAddress: currentAddress ?? this.currentAddress,
        emergencyPhone: emergencyPhone ?? this.emergencyPhone,
        emergencyContact: emergencyContact ?? this.emergencyContact,
      );

  factory Employee.fromJson(Map<String, dynamic> json) => Employee(
        name: json['name'] as String,
        employeeName: (json['employee_name'] ?? '') as String,
        designation: json['designation'] as String?,
        department: json['department'] as String?,
        company: json['company'] as String?,
        image: json['image'] as String?,
        dateOfJoining: json['date_of_joining'] as String?,
        companyEmail: json['company_email'] as String?,
        personalEmail: json['personal_email'] as String?,
        cellNumber: json['cell_number'] as String?,
        currentAddress: json['current_address'] as String?,
        emergencyPhone: json['emergency_phone_number'] as String?,
        emergencyContact: json['person_to_be_contacted'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'employee_name': employeeName,
        'designation': designation,
        'department': department,
        'company': company,
        'image': image,
        'date_of_joining': dateOfJoining,
        'company_email': companyEmail,
        'personal_email': personalEmail,
        'cell_number': cellNumber,
        'current_address': currentAddress,
        'emergency_phone_number': emergencyPhone,
        'person_to_be_contacted': emergencyContact,
      };
}

@immutable
class Profile {
  const Profile({
    required this.user,
    required this.fullName,
    this.userImage,
    this.roles = const [],
    this.capabilities = const {},
    this.screenPerms = const {},
    this.modules,
    this.disabledScreens = const {},
    this.employee,
  });

  final String user;
  final String fullName;
  final String? userImage;
  final List<String> roles;
  final Set<String> capabilities;

  /// Per-screen action permissions from the backend, e.g.
  /// {'stock_item': {'view','create','write'}}. Powers ERP-native
  /// enable/disable of create/edit/submit/delete buttons inside a screen.
  final Map<String, Set<String>> screenPerms;

  /// Modules this company is licensed for (TCB middleware), e.g. {'hr','crm'}.
  /// Null when the server predates module licensing — treat as all enabled.
  final Set<String>? modules;

  /// Screen ids the site admin switched off, e.g. {'crm.recordings'}.
  final Set<String> disabledScreens;

  final Employee? employee;

  bool get hasEmployee => employee != null;

  bool can(String feature) => capabilities.contains(feature);

  /// Module layer: is [module] (e.g. 'crm') part of this company's licence?
  bool hasModule(String module) => modules?.contains(module) ?? true;

  /// Module + screen layers for a screen id like 'crm.recordings'. `core.*`
  /// screens (Home, Admin) are always on. The role layer is [can].
  bool screenEnabled(String screenId) {
    final module = screenId.split('.').first;
    if (module == 'core') return true;
    return hasModule(module) && !disabledScreens.contains(screenId);
  }

  /// True if the user may perform [action] (view/create/write/submit/delete)
  /// on [screen]. Falls back to the coarse [can] flag when no per-screen data.
  bool canDo(String screen, String action) =>
      screenPerms[screen]?.contains(action) ?? false;

  Profile withEmployee(Employee employee) => Profile(
        user: user,
        fullName: fullName,
        userImage: userImage,
        roles: roles,
        capabilities: capabilities,
        screenPerms: screenPerms,
        modules: modules,
        disabledScreens: disabledScreens,
        employee: employee,
      );

  String get initials {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        user: json['user'] as String,
        fullName: (json['full_name'] ?? json['user']) as String,
        userImage: json['user_image'] as String?,
        roles: (json['roles'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
        capabilities: _capsFromJson(json['capabilities']),
        screenPerms: _screenPermsFromJson(json['screen_perms']),
        modules: (json['modules'] as List?)?.map((e) => e.toString()).toSet(),
        disabledScreens: ((json['disabled_screens'] as List?) ?? const [])
            .map((e) => e.toString())
            .toSet(),
        employee: json['employee'] is Map<String, dynamic>
            ? Employee.fromJson(json['employee'] as Map<String, dynamic>)
            : null,
      );

  static Set<String> _capsFromJson(dynamic raw) {
    if (raw is Map) {
      return raw.entries
          .where((e) => e.value == true)
          .map((e) => e.key.toString())
          .toSet();
    }
    if (raw is List) return raw.map((e) => e.toString()).toSet();
    return const {};
  }

  static Map<String, Set<String>> _screenPermsFromJson(dynamic raw) {
    if (raw is Map) {
      final out = <String, Set<String>>{};
      raw.forEach((screen, perms) {
        if (perms is Map) {
          out[screen.toString()] = perms.entries
              .where((e) => e.value == true)
              .map((e) => e.key.toString())
              .toSet();
        }
      });
      return out;
    }
    return const {};
  }

  Map<String, dynamic> toJson() => {
        'user': user,
        'full_name': fullName,
        'user_image': userImage,
        'roles': roles,
        'capabilities': {for (final c in capabilities) c: true},
        'screen_perms': {
          for (final e in screenPerms.entries)
            e.key: {for (final a in e.value) a: true}
        },
        'modules': modules?.toList(),
        'disabled_screens': disabledScreens.toList(),
        'employee': employee?.toJson(),
      };
}
