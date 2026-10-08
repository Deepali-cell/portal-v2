import 'package:flutter/foundation.dart';

/// One editable field returned by portal_forms.get_meta.
@immutable
class FieldMeta {
  const FieldMeta({
    required this.fieldname,
    required this.label,
    required this.fieldtype,
    this.options,
    this.reqd = false,
    this.readOnly = false,
    this.defaultValue,
    this.fetchFrom,
    this.childFields = const [],
  });

  final String fieldname;
  final String label;
  final String fieldtype;
  final String? options;
  final bool reqd;
  final bool readOnly;
  final String? defaultValue;

  /// "link_fieldname.source_field" - when that Link is picked this field is
  /// auto-filled from the source doc (ERPNext fetch_from).
  final String? fetchFrom;
  final List<FieldMeta> childFields;

  bool get isTable => fieldtype == 'Table';

  factory FieldMeta.fromJson(Map<String, dynamic> j) => FieldMeta(
        fieldname: j['fieldname'] as String,
        label: (j['label'] ?? j['fieldname']) as String,
        fieldtype: j['fieldtype'] as String,
        options: j['options'] as String?,
        reqd: (j['reqd'] ?? 0) == 1,
        readOnly: (j['read_only'] ?? 0) == 1,
        defaultValue: j['default']?.toString(),
        fetchFrom: (j['fetch_from'] as String?)?.isNotEmpty == true
            ? j['fetch_from'] as String
            : null,
        childFields: ((j['child_fields'] as List?) ?? const [])
            .map((e) => FieldMeta.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

@immutable
class FormMeta {
  const FormMeta({
    required this.doctype,
    required this.isSubmittable,
    required this.fields,
    this.autonamePrompt = false,
  });

  final String doctype;
  final bool isSubmittable;
  final List<FieldMeta> fields;

  /// True when the doctype is named by prompt (e.g. Shift Type): the create
  /// form must collect the document name (sent as `__newname`).
  final bool autonamePrompt;

  factory FormMeta.fromJson(Map<String, dynamic> j) => FormMeta(
        doctype: j['doctype'] as String,
        isSubmittable: (j['is_submittable'] ?? 0) == 1,
        autonamePrompt: (j['autoname_prompt'] ?? false) == true,
        fields: ((j['fields'] as List?) ?? const [])
            .map((e) => FieldMeta.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}
