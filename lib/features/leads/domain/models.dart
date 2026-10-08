import 'package:flutter/foundation.dart';

@immutable
class Lead {
  const Lead({
    required this.name,
    required this.status,
    this.leadName,
    this.salutation,
    this.firstName,
    this.middleName,
    this.lastName,
    this.gender,
    this.organization,
    this.email,
    this.mobileNo,
    this.phone,
    this.website,
    this.jobTitle,
    this.noOfEmployees,
    this.annualRevenue,
    this.industry,
    this.source,
    this.territory,
    this.leadOwner,
    this.image,
    this.converted = false,
    this.assignees = const [],
    this.counts = const LeadCounts(),
    this.lastContactAt,
    this.daysSinceContact,
  });

  final String name;
  final String status;
  final String? leadName;
  final String? salutation;
  final String? firstName;
  final String? middleName;
  final String? lastName;
  final String? gender;
  final String? organization;
  final String? email;
  final String? mobileNo;
  final String? phone;
  final String? website;
  final String? jobTitle;
  final String? noOfEmployees;
  final double? annualRevenue;
  final String? industry;
  final String? source;
  final String? territory;
  final String? leadOwner;
  final String? image;
  final bool converted;
  final List<String> assignees;
  final LeadCounts counts;
  final DateTime? lastContactAt;
  final int? daysSinceContact;

  String get title => (leadName?.trim().isNotEmpty ?? false)
      ? leadName!
      : (organization ?? name);

  /// Returns a copy with selected fields overridden — used by the Kanban
  /// optimistic-update flow.
  Lead copyWith({String? status}) => Lead(
    name: name,
    status: status ?? this.status,
    leadName: leadName,
    salutation: salutation,
    firstName: firstName,
    middleName: middleName,
    lastName: lastName,
    gender: gender,
    organization: organization,
    email: email,
    mobileNo: mobileNo,
    phone: phone,
    website: website,
    jobTitle: jobTitle,
    noOfEmployees: noOfEmployees,
    annualRevenue: annualRevenue,
    industry: industry,
    source: source,
    territory: territory,
    leadOwner: leadOwner,
    image: image,
    converted: converted,
    assignees: assignees,
    counts: counts,
    lastContactAt: lastContactAt,
    daysSinceContact: daysSinceContact,
  );

  String get initials {
    final source = title.trim();
    if (source.isEmpty) return '?';
    final parts = source.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  factory Lead.fromJson(Map<String, dynamic> j) => Lead(
    name: j['name'] as String,
    status: (j['status'] ?? '') as String,
    leadName: j['lead_name'] as String?,
    salutation: j['salutation'] as String?,
    firstName: j['first_name'] as String?,
    middleName: j['middle_name'] as String?,
    lastName: j['last_name'] as String?,
    gender: j['gender'] as String?,
    organization: j['organization'] as String?,
    email: j['email'] as String?,
    mobileNo: j['mobile_no'] as String?,
    phone: j['phone'] as String?,
    website: j['website'] as String?,
    jobTitle: j['job_title'] as String?,
    noOfEmployees: j['no_of_employees'] as String?,
    annualRevenue: (j['annual_revenue'] as num?)?.toDouble(),
    industry: j['industry'] as String?,
    source: j['source'] as String?,
    territory: j['territory'] as String?,
    leadOwner: j['lead_owner'] as String?,
    image: j['image'] as String?,
    converted: (j['converted'] as num?)?.toInt() == 1,
    assignees: ((j['assignees'] as List?) ?? [])
        .map((e) => e.toString())
        .toList(),
    counts: LeadCounts.fromJson(j['counts'] as Map<String, dynamic>?),
    lastContactAt: _parseDate(j['last_contact_at']),
    daysSinceContact: (j['days_since_contact'] as num?)?.toInt(),
  );
}

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  final s = v.toString();
  if (s.isEmpty) return null;
  return DateTime.tryParse(s);
}

@immutable
class LeadCounts {
  const LeadCounts({
    this.notes = 0,
    this.tasks = 0,
    this.calls = 0,
    this.comments = 0,
    this.attachments = 0,
    this.emails = 0,
    this.events = 0,
  });

  final int notes;
  final int tasks;
  final int calls;
  final int comments;
  final int attachments;
  final int emails;
  final int events;

  factory LeadCounts.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const LeadCounts();
    return LeadCounts(
      notes: (j['notes'] as num?)?.toInt() ?? 0,
      tasks: (j['tasks'] as num?)?.toInt() ?? 0,
      calls: (j['calls'] as num?)?.toInt() ?? 0,
      comments: (j['comments'] as num?)?.toInt() ?? 0,
      attachments: (j['attachments'] as num?)?.toInt() ?? 0,
      emails: (j['emails'] as num?)?.toInt() ?? 0,
      events: (j['events'] as num?)?.toInt() ?? 0,
    );
  }
}

@immutable
class LeadsContext {
  const LeadsContext({required this.leads, required this.statuses});
  final List<Lead> leads;
  final List<String> statuses;

  factory LeadsContext.fromJson(Map<String, dynamic> j) => LeadsContext(
    leads: ((j['leads'] as List?) ?? [])
        .map((e) => Lead.fromJson(e as Map<String, dynamic>))
        .toList(),
    statuses: ((j['statuses'] as List?) ?? [])
        .map((e) => e.toString())
        .toList(),
  );
}
