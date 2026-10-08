import 'package:flutter/foundation.dart';

@immutable
class Deal {
  const Deal({
    required this.name,
    required this.status,
    this.organization,
    this.organizationName,
    this.leadName,
    this.dealValue = 0,
    this.annualRevenue = 0,
    this.currency = 'INR',
    this.probability,
    this.email,
    this.mobileNo,
    this.phone,
    this.website,
    this.jobTitle,
    this.salutation,
    this.firstName,
    this.lastName,
    this.gender,
    this.noOfEmployees,
    this.industry,
    this.source,
    this.territory,
    this.dealOwner,
    this.nextStep,
    this.lead,
    this.assignees = const [],
    this.counts = const DealCounts(),
  });

  final String name;
  final String status;
  final String? organization;
  final String? organizationName;
  final String? leadName;
  final double dealValue;
  final double annualRevenue;
  final String currency;
  final double? probability;
  final String? email;
  final String? mobileNo;
  final String? phone;
  final String? website;
  final String? jobTitle;
  final String? salutation;
  final String? firstName;
  final String? lastName;
  final String? gender;
  final String? noOfEmployees;
  final String? industry;
  final String? source;
  final String? territory;
  final String? dealOwner;
  final String? nextStep;
  final String? lead;
  final List<String> assignees;
  final DealCounts counts;

  String get title {
    for (final v in [organizationName, organization, leadName]) {
      if (v != null && v.trim().isNotEmpty) return v;
    }
    return name;
  }

  factory Deal.fromJson(Map<String, dynamic> j) => Deal(
        name: j['name'] as String,
        status: (j['status'] ?? '') as String,
        organization: j['organization'] as String?,
        organizationName: j['organization_name'] as String?,
        leadName: j['lead_name'] as String?,
        dealValue: (j['deal_value'] as num?)?.toDouble() ?? 0,
        annualRevenue: (j['annual_revenue'] as num?)?.toDouble() ?? 0,
        currency: (j['currency'] ?? 'INR') as String,
        probability: (j['probability'] as num?)?.toDouble(),
        email: j['email'] as String?,
        mobileNo: j['mobile_no'] as String?,
        phone: j['phone'] as String?,
        website: j['website'] as String?,
        jobTitle: j['job_title'] as String?,
        salutation: j['salutation'] as String?,
        firstName: j['first_name'] as String?,
        lastName: j['last_name'] as String?,
        gender: j['gender'] as String?,
        noOfEmployees: j['no_of_employees'] as String?,
        industry: j['industry'] as String?,
        source: j['source'] as String?,
        territory: j['territory'] as String?,
        dealOwner: j['deal_owner'] as String?,
        nextStep: j['next_step'] as String?,
        lead: j['lead'] as String?,
        assignees:
            ((j['assignees'] as List?) ?? []).map((e) => e.toString()).toList(),
        counts: DealCounts.fromJson(j['counts'] as Map<String, dynamic>?),
      );
}

@immutable
class DealCounts {
  const DealCounts({
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

  factory DealCounts.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const DealCounts();
    return DealCounts(
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
class DealsContext {
  const DealsContext({required this.deals, required this.statuses});
  final List<Deal> deals;
  final List<String> statuses;

  factory DealsContext.fromJson(Map<String, dynamic> j) => DealsContext(
        deals: ((j['deals'] as List?) ?? [])
            .map((e) => Deal.fromJson(e as Map<String, dynamic>))
            .toList(),
        statuses:
            ((j['statuses'] as List?) ?? []).map((e) => e.toString()).toList(),
      );
}
