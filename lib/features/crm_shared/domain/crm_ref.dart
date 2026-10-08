import 'package:flutter/foundation.dart';

/// Identifies a CRM parent (Lead or Opportunity) for which we're reading or
/// mutating collaboration data (notes, tasks, comments, attachments, assignees).
/// Used as the FutureProvider.family key, so it must be value-equatable.
@immutable
class CrmRef {
  const CrmRef({required this.doctype, required this.name});
  final String doctype; // "Lead" or "Opportunity"
  final String name;

  Map<String, dynamic> get queryParams =>
      {'reference_doctype': doctype, 'reference_docname': name};

  Map<String, dynamic> get bodyFields =>
      {'reference_doctype': doctype, 'reference_docname': name};

  @override
  bool operator ==(Object other) =>
      other is CrmRef && other.doctype == doctype && other.name == name;

  @override
  int get hashCode => Object.hash(doctype, name);
}
