import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../data/records_repository.dart';
import '../domain/form_meta.dart';

/// Metadata-driven form for any allowlisted doctype. Renders inputs (incl.
/// child-table rows), then saves/submits through portal_forms (ERP perms +
/// validations apply). Pop result is the created/updated doc name (String) on
/// success, so the caller can refresh.
class DynamicFormScreen extends ConsumerStatefulWidget {
  const DynamicFormScreen({
    super.key,
    required this.doctype,
    required this.title,
    this.name,
    this.initialValues = const {},
  });

  final String doctype;
  final String title;
  final String? name;
  final Map<String, dynamic> initialValues;

  @override
  ConsumerState<DynamicFormScreen> createState() => _DynamicFormScreenState();
}

class _DynamicFormScreenState extends ConsumerState<DynamicFormScreen> {
  FormMeta? _meta;
  Object? _error;
  bool _loading = true;
  bool _saving = false;

  final Map<String, dynamic> _values = {};
  final Map<String, TextEditingController> _controllers = {};

  /// For prompt-named doctypes (e.g. Shift Type) on create: the document name
  /// the user types, sent to the backend as `__newname`.
  TextEditingController? _newNameCtrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _newNameCtrl?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(recordsRepositoryProvider);
      final meta = await repo.getFormMeta(widget.doctype);
      // When editing an existing record, pull the FULL saved values (all
      // editable fields + child rows). `initialValues` from the detail screen
      // only carries the trimmed display fields, so on its own the edit form
      // would show blank. New records (name == null) skip this.
      Map<String, dynamic> saved = const {};
      if (widget.name != null) {
        try {
          saved = await repo.getFormValues(widget.doctype, widget.name!);
        } catch (_) {
          // fall back to the trimmed initialValues if the fetch fails
        }
      }
      for (final f in meta.fields) {
        dynamic init = saved.containsKey(f.fieldname)
            ? saved[f.fieldname]
            : widget.initialValues[f.fieldname];
        if (f.fieldtype == 'Table') {
          // Normalise child rows to List<Map<String, dynamic>>.
          final rows = (init as List?) ?? const [];
          _values[f.fieldname] = rows
              .map((e) => (e as Map).cast<String, dynamic>())
              .toList();
          continue;
        }
        init ??= _defaultFor(f);
        if (init != null) _values[f.fieldname] = init;
        if (_isTextType(f.fieldtype)) {
          _controllers[f.fieldname] =
              TextEditingController(text: init?.toString() ?? '');
        }
      }
      if (meta.autonamePrompt && widget.name == null) {
        _newNameCtrl = TextEditingController();
      }
      if (mounted) setState(() => _meta = meta);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  dynamic _defaultFor(FieldMeta f) {
    if (f.defaultValue == null) return f.fieldtype == 'Table' ? <Map>[] : null;
    if (f.fieldtype == 'Check') return f.defaultValue == '1' ? 1 : 0;
    return f.defaultValue;
  }

  bool _isTextType(String t) => const {
        'Data',
        'Small Text',
        'Text',
        'Long Text',
        'Text Editor',
        'Int',
        'Float',
        'Currency',
        'Percent',
      }.contains(t);

  Future<void> _save({required bool submit}) async {
    final meta = _meta;
    if (meta == null) return;
    // Prompt-named create: the document name is required up front.
    String? newName;
    if (_newNameCtrl != null) {
      newName = _newNameCtrl!.text.trim();
      if (newName.isEmpty) {
        _snack('Required: Name');
        return;
      }
    }
    // Pull text controllers into values.
    for (final f in meta.fields) {
      if (_isTextType(f.fieldtype)) {
        final raw = _controllers[f.fieldname]?.text.trim() ?? '';
        _values[f.fieldname] = raw.isEmpty ? null : _coerce(f.fieldtype, raw);
      }
    }
    // Required check.
    final missing = meta.fields
        .where((f) => f.reqd && !f.readOnly && _isEmpty(_values[f.fieldname]))
        .map((f) => f.label)
        .toList();
    if (missing.isNotEmpty) {
      _snack('Required: ${missing.join(', ')}');
      return;
    }

    final payload = <String, dynamic>{};
    for (final f in meta.fields) {
      if (f.readOnly) continue;
      final v = _values[f.fieldname];
      if (v == null) continue;
      if (f.isTable && v is List && v.isEmpty) continue;
      payload[f.fieldname] = v;
    }
    if (newName != null) payload['__newname'] = newName;

    setState(() => _saving = true);
    try {
      final res = await ref.read(recordsRepositoryProvider).saveDoc(
            widget.doctype,
            payload,
            name: widget.name,
            submit: submit,
          );
      if (mounted) {
        _snack('Saved: ${res['name']}');
        Navigator.of(context).pop(res['name']?.toString());
      }
    } catch (e) {
      if (mounted) _snack("Couldn't save. $e");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  dynamic _coerce(String type, String raw) {
    if (type == 'Int') return int.tryParse(raw) ?? raw;
    if (type == 'Float' || type == 'Currency' || type == 'Percent') {
      return double.tryParse(raw) ?? raw;
    }
    return raw;
  }

  bool _isEmpty(dynamic v) =>
      v == null || (v is String && v.isEmpty) || (v is List && v.isEmpty);

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m, maxLines: 6, overflow: TextOverflow.ellipsis),
        duration: const Duration(seconds: 6),
      ));

  /// Public rebuild hook for the child field widgets below.
  void update(VoidCallback fn) => setState(fn);

  /// Clear any Dynamic Link field that points at [changedField] (its target
  /// doctype just changed, so the previously-picked value is no longer valid).
  void _clearDependentDynamicLinks(String changedField) {
    final meta = _meta;
    if (meta == null) return;
    for (final df in meta.fields) {
      if (df.fieldtype == 'Dynamic Link' && df.options == changedField) {
        _values[df.fieldname] = null;
      }
    }
  }

  /// When [linkField] is picked, fetch source-doc values for any field whose
  /// `fetch_from` starts with `linkField.fieldname.` and fill them in.
  Future<void> applyFetch(FieldMeta linkField, String value) async {
    final meta = _meta;
    if (meta == null) return;
    final prefix = '${linkField.fieldname}.';
    final targets = <String, String>{}; // source field -> target fieldname
    for (final f in meta.fields) {
      final ff = f.fetchFrom;
      if (ff != null && ff.startsWith(prefix)) {
        targets[ff.substring(prefix.length)] = f.fieldname;
      }
    }
    final srcDoctype = linkField.options;
    if (targets.isEmpty || srcDoctype == null || srcDoctype.isEmpty) return;
    try {
      final vals = await ref
          .read(recordsRepositoryProvider)
          .fetchLinkValues(srcDoctype, value, targets.keys.toList());
      if (!mounted) return;
      setState(() {
        targets.forEach((src, target) {
          final v = vals[src];
          if (v == null) return;
          _values[target] = v;
          final c = _controllers[target];
          if (c != null) c.text = v.toString();
        });
      });
    } catch (_) {
      // Auto-fill is best-effort; ignore failures.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('${widget.name == null ? 'New' : 'Edit'} ${widget.title}'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimens.lg),
                    child: Text('$_error', textAlign: TextAlign.center),
                  ),
                )
              : _form(),
      bottomNavigationBar: (_meta == null) ? null : _actions(),
    );
  }

  Widget _actions() {
    final meta = _meta!;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _saving ? null : () => _save(submit: false),
                child: const Text('Save Draft'),
              ),
            ),
            if (meta.isSubmittable) ...[
              const SizedBox(width: AppDimens.sm),
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : () => _save(submit: true),
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save & Submit'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _form() {
    final meta = _meta!;
    return ListView(
      padding: const EdgeInsets.all(AppDimens.md),
      children: [
        if (_newNameCtrl != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppDimens.md),
            child: TextFormField(
              controller: _newNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name *',
                helperText: 'A unique name for this record',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
        for (final f in meta.fields) _field(f),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _field(FieldMeta f) {
    final pad = const EdgeInsets.only(bottom: AppDimens.md);
    switch (f.fieldtype) {
      case 'Check':
        return Padding(
          padding: pad,
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(f.label),
            value: (_values[f.fieldname] == 1 || _values[f.fieldname] == true),
            onChanged: f.readOnly
                ? null
                : (v) => setState(() => _values[f.fieldname] = v ? 1 : 0),
          ),
        );
      case 'Select':
        final opts = (f.options ?? '')
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        return Padding(
          padding: pad,
          child: DropdownButtonFormField<String>(
            initialValue: (_values[f.fieldname] as String?)?.isNotEmpty == true
                ? _values[f.fieldname] as String
                : null,
            isExpanded: true,
            decoration: _dec(f),
            items: opts
                .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                .toList(),
            onChanged: f.readOnly
                ? null
                : (v) => setState(() {
                      _values[f.fieldname] = v;
                      _clearDependentDynamicLinks(f.fieldname);
                    }),
          ),
        );
      case 'Link':
        return Padding(padding: pad, child: _LinkTile(field: f, state: this));
      case 'Dynamic Link':
        return Padding(padding: pad, child: _DynLinkTile(field: f, state: this));
      case 'Date':
      case 'Datetime':
      case 'Time':
        return Padding(padding: pad, child: _DateTile(field: f, state: this));
      case 'Table':
        return Padding(padding: pad, child: _TableSection(field: f, state: this));
      default:
        final multiline = f.fieldtype != 'Data' &&
            f.fieldtype != 'Int' &&
            f.fieldtype != 'Float' &&
            f.fieldtype != 'Currency' &&
            f.fieldtype != 'Percent';
        final numeric = f.fieldtype == 'Int' ||
            f.fieldtype == 'Float' ||
            f.fieldtype == 'Currency' ||
            f.fieldtype == 'Percent';
        return Padding(
          padding: pad,
          child: TextFormField(
            controller: _controllers[f.fieldname],
            readOnly: f.readOnly,
            maxLines: multiline ? 3 : 1,
            keyboardType: numeric
                ? const TextInputType.numberWithOptions(decimal: true)
                : null,
            inputFormatters: numeric
                ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))]
                : null,
            decoration: _dec(f),
          ),
        );
    }
  }

  InputDecoration _dec(FieldMeta f) => InputDecoration(
        labelText: f.reqd ? '${f.label} *' : f.label,
        border: const OutlineInputBorder(),
        isDense: true,
      );
}

/// Link picker: tap opens a searchable bottom sheet.
class _LinkTile extends StatelessWidget {
  const _LinkTile({required this.field, required this.state});
  final FieldMeta field;
  final _DynamicFormScreenState state;

  @override
  Widget build(BuildContext context) {
    final value = state._values[field.fieldname] as String?;
    return InkWell(
      onTap: field.readOnly
          ? null
          : () async {
              final picked = await showModalBottomSheet<String>(
                context: context,
                isScrollControlled: true,
                builder: (_) => _LinkSearchSheetRow(doctype: field.options ?? ''),
              );
              if (picked != null) {
                state.update(() {
                  state._values[field.fieldname] = picked;
                  state._clearDependentDynamicLinks(field.fieldname);
                });
                state.applyFetch(field, picked);
              }
            },
      child: InputDecorator(
        decoration: state._dec(field),
        child: Text(
          value?.isNotEmpty == true ? value! : 'Tap to select',
          style: value?.isNotEmpty == true
              ? null
              : TextStyle(color: AppColors.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// Dynamic Link picker: its target doctype comes from another field's current
/// value (e.g. Holiday List Assignment.assigned_to follows `applicable_for`,
/// which is "Employee" or "Company"). Until that field is set, the picker is
/// disabled and prompts for it.
class _DynLinkTile extends StatelessWidget {
  const _DynLinkTile({required this.field, required this.state});
  final FieldMeta field;
  final _DynamicFormScreenState state;

  @override
  Widget build(BuildContext context) {
    final value = state._values[field.fieldname] as String?;
    // `options` on a Dynamic Link is the fieldname whose value is the doctype.
    final refField = field.options ?? '';
    final targetDoctype = state._values[refField] as String?;
    final ready = targetDoctype != null && targetDoctype.isNotEmpty;
    final refLabel = _refLabel(refField);
    return InkWell(
      onTap: (field.readOnly || !ready)
          ? null
          : () async {
              final picked = await showModalBottomSheet<String>(
                context: context,
                isScrollControlled: true,
                builder: (_) => _LinkSearchSheetRow(doctype: targetDoctype),
              );
              if (picked != null) {
                state.update(() => state._values[field.fieldname] = picked);
              }
            },
      child: InputDecorator(
        decoration: state._dec(field),
        child: Text(
          value?.isNotEmpty == true
              ? value!
              : (ready ? 'Tap to select' : 'Select $refLabel first'),
          style: value?.isNotEmpty == true
              ? null
              : TextStyle(color: AppColors.onSurfaceVariant),
        ),
      ),
    );
  }

  String _refLabel(String refField) {
    final meta = state._meta;
    if (meta == null) return refField;
    for (final f in meta.fields) {
      if (f.fieldname == refField) return f.label;
    }
    return refField;
  }
}

/// Date / Datetime / Time picker tile.
class _DateTile extends StatelessWidget {
  const _DateTile({required this.field, required this.state});
  final FieldMeta field;
  final _DynamicFormScreenState state;

  @override
  Widget build(BuildContext context) {
    final value = state._values[field.fieldname] as String?;
    return InkWell(
      onTap: field.readOnly ? null : () => _pick(context),
      child: InputDecorator(
        decoration: state._dec(field),
        child: Text(
          value?.isNotEmpty == true ? value! : 'Tap to select',
          style: value?.isNotEmpty == true
              ? null
              : TextStyle(color: AppColors.onSurfaceVariant),
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    String two(int n) => n.toString().padLeft(2, '0');
    if (field.fieldtype == 'Time') {
      final t = await showTimePicker(
          context: context, initialTime: TimeOfDay.now());
      if (t != null) {
        state.update(() => state._values[field.fieldname] =
            '${two(t.hour)}:${two(t.minute)}:00');
      }
      return;
    }
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null) return;
    final ds = '${d.year}-${two(d.month)}-${two(d.day)}';
    if (field.fieldtype == 'Date') {
      state.update(() => state._values[field.fieldname] = ds);
    } else {
      if (!context.mounted) return;
      final t = await showTimePicker(
          context: context, initialTime: TimeOfDay.now());
      final ts = t == null ? '00:00:00' : '${two(t.hour)}:${two(t.minute)}:00';
      state.update(() => state._values[field.fieldname] = '$ds $ts');
    }
  }
}

/// Child-table section: list of rows + add/edit via a nested sheet.
class _TableSection extends StatelessWidget {
  const _TableSection({required this.field, required this.state});
  final FieldMeta field;
  final _DynamicFormScreenState state;

  List<Map<String, dynamic>> get _rows {
    final v = state._values[field.fieldname];
    if (v is List) {
      return v.map((e) => (e as Map).cast<String, dynamic>()).toList();
    }
    return [];
  }

  void _commit(List<Map<String, dynamic>> rows) {
    state.update(() => state._values[field.fieldname] = rows);
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${field.label}${field.reqd ? ' *' : ''}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                TextButton.icon(
                  onPressed: () => _editRow(context, null),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                ),
              ],
            ),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppDimens.sm),
                child: Text('No rows',
                    style: TextStyle(color: AppColors.onSurfaceVariant)),
              ),
            for (int i = 0; i < rows.length; i++)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(_summary(rows[i])),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    final copy = [...rows]..removeAt(i);
                    _commit(copy);
                  },
                ),
                onTap: () => _editRow(context, i),
              ),
          ],
        ),
      ),
    );
  }

  String _summary(Map<String, dynamic> row) {
    final parts = field.childFields
        .take(3)
        .map((c) => row[c.fieldname])
        .where((v) => v != null && v.toString().isNotEmpty)
        .map((v) => v.toString())
        .toList();
    return parts.isEmpty ? '(empty row)' : parts.join('  •  ');
  }

  Future<void> _editRow(BuildContext context, int? index) async {
    final rows = _rows;
    final initial = index == null ? <String, dynamic>{} : rows[index];
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RowEditor(fields: field.childFields, initial: initial),
    );
    if (result == null) return;
    final copy = [...rows];
    if (index == null) {
      copy.add(result);
    } else {
      copy[index] = result;
    }
    _commit(copy);
  }
}

/// A mini-form for one child-table row (no nested tables).
class _RowEditor extends ConsumerStatefulWidget {
  const _RowEditor({required this.fields, required this.initial});
  final List<FieldMeta> fields;
  final Map<String, dynamic> initial;

  @override
  ConsumerState<_RowEditor> createState() => _RowEditorState();
}

class _RowEditorState extends ConsumerState<_RowEditor> {
  final Map<String, dynamic> _row = {};
  final Map<String, TextEditingController> _ctrls = {};

  @override
  void initState() {
    super.initState();
    for (final f in widget.fields) {
      _row[f.fieldname] = widget.initial[f.fieldname];
      if (_isText(f.fieldtype)) {
        _ctrls[f.fieldname] =
            TextEditingController(text: widget.initial[f.fieldname]?.toString() ?? '');
      }
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool _isText(String t) => const {
        'Data', 'Small Text', 'Text', 'Long Text', 'Text Editor',
        'Int', 'Float', 'Currency', 'Percent',
      }.contains(t);

  bool _numeric(String t) => const {'Int', 'Float', 'Currency', 'Percent'}.contains(t);

  /// Auto-fill row fields whose fetch_from points at the just-picked Link.
  Future<void> _applyFetch(FieldMeta linkField, String value) async {
    final prefix = '${linkField.fieldname}.';
    final targets = <String, String>{}; // source field -> target fieldname
    for (final f in widget.fields) {
      final ff = f.fetchFrom;
      if (ff != null && ff.startsWith(prefix)) {
        targets[ff.substring(prefix.length)] = f.fieldname;
      }
    }
    final srcDoctype = linkField.options;
    if (targets.isEmpty || srcDoctype == null || srcDoctype.isEmpty) return;
    try {
      final vals = await ref
          .read(recordsRepositoryProvider)
          .fetchLinkValues(srcDoctype, value, targets.keys.toList());
      if (!mounted) return;
      setState(() {
        targets.forEach((src, target) {
          final v = vals[src];
          if (v == null) return;
          _row[target] = v;
          final c = _ctrls[target];
          if (c != null) c.text = v.toString();
        });
      });
    } catch (_) {
      // Best-effort.
    }
  }

  Future<void> _pickDate(BuildContext context, FieldMeta f) async {
    String two(int n) => n.toString().padLeft(2, '0');
    if (f.fieldtype == 'Time') {
      final t =
          await showTimePicker(context: context, initialTime: TimeOfDay.now());
      if (t != null) {
        setState(() =>
            _row[f.fieldname] = '${two(t.hour)}:${two(t.minute)}:00');
      }
      return;
    }
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null) return;
    final ds = '${d.year}-${two(d.month)}-${two(d.day)}';
    if (f.fieldtype == 'Date') {
      setState(() => _row[f.fieldname] = ds);
    } else {
      if (!context.mounted) return;
      final t =
          await showTimePicker(context: context, initialTime: TimeOfDay.now());
      final ts = t == null ? '00:00:00' : '${two(t.hour)}:${two(t.minute)}:00';
      setState(() => _row[f.fieldname] = '$ds $ts');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: AppDimens.md,
        right: AppDimens.md,
        top: AppDimens.md,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            const Text('Row', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppDimens.sm),
            Expanded(
              child: ListView(
                children: [for (final f in widget.fields) _child(context, f)],
              ),
            ),
            SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AppDimens.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        for (final f in widget.fields) {
                          if (_isText(f.fieldtype)) {
                            final raw = _ctrls[f.fieldname]?.text.trim() ?? '';
                            _row[f.fieldname] = raw.isEmpty
                                ? null
                                : (_numeric(f.fieldtype)
                                    ? (num.tryParse(raw) ?? raw)
                                    : raw);
                          }
                        }
                        Navigator.of(context).pop(_row);
                      },
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _child(BuildContext context, FieldMeta f) {
    final pad = const EdgeInsets.only(bottom: AppDimens.md);
    if (f.fieldtype == 'Check') {
      return Padding(
        padding: pad,
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(f.label),
          value: _row[f.fieldname] == 1 || _row[f.fieldname] == true,
          onChanged: (v) => setState(() => _row[f.fieldname] = v ? 1 : 0),
        ),
      );
    }
    if (f.fieldtype == 'Select') {
      final opts = (f.options ?? '')
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      return Padding(
        padding: pad,
        child: DropdownButtonFormField<String>(
          initialValue: (_row[f.fieldname] as String?)?.isNotEmpty == true
              ? _row[f.fieldname] as String
              : null,
          isExpanded: true,
          decoration: InputDecoration(
              labelText: f.reqd ? '${f.label} *' : f.label,
              border: const OutlineInputBorder(),
              isDense: true),
          items: opts
              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
          onChanged: (v) => setState(() => _row[f.fieldname] = v),
        ),
      );
    }
    if (f.fieldtype == 'Link') {
      final value = _row[f.fieldname] as String?;
      return Padding(
        padding: pad,
        child: InkWell(
          onTap: () async {
            final picked = await showModalBottomSheet<String>(
              context: context,
              isScrollControlled: true,
              builder: (_) => _LinkSearchSheetRow(doctype: f.options ?? ''),
            );
            if (picked != null) {
              setState(() => _row[f.fieldname] = picked);
              _applyFetch(f, picked);
            }
          },
          child: InputDecorator(
            decoration: InputDecoration(
                labelText: f.reqd ? '${f.label} *' : f.label,
                border: const OutlineInputBorder(),
                isDense: true),
            child: Text(value?.isNotEmpty == true ? value! : 'Tap to select',
                style: value?.isNotEmpty == true
                    ? null
                    : TextStyle(color: AppColors.onSurfaceVariant)),
          ),
        ),
      );
    }
    if (f.fieldtype == 'Date' ||
        f.fieldtype == 'Datetime' ||
        f.fieldtype == 'Time') {
      final value = _row[f.fieldname] as String?;
      return Padding(
        padding: pad,
        child: InkWell(
          onTap: () => _pickDate(context, f),
          child: InputDecorator(
            decoration: InputDecoration(
                labelText: f.reqd ? '${f.label} *' : f.label,
                border: const OutlineInputBorder(),
                isDense: true),
            child: Text(value?.isNotEmpty == true ? value! : 'Tap to select',
                style: value?.isNotEmpty == true
                    ? null
                    : TextStyle(color: AppColors.onSurfaceVariant)),
          ),
        ),
      );
    }
    // text / numeric
    return Padding(
      padding: pad,
      child: TextFormField(
        controller: _ctrls[f.fieldname],
        keyboardType: _numeric(f.fieldtype)
            ? const TextInputType.numberWithOptions(decimal: true)
            : null,
        inputFormatters: _numeric(f.fieldtype)
            ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))]
            : null,
        decoration: InputDecoration(
            labelText: f.reqd ? '${f.label} *' : f.label,
            border: const OutlineInputBorder(),
            isDense: true),
      ),
    );
  }
}

/// Link search sheet used inside a row editor (own Consumer scope).
class _LinkSearchSheetRow extends ConsumerStatefulWidget {
  const _LinkSearchSheetRow({required this.doctype});
  final String doctype;

  @override
  ConsumerState<_LinkSearchSheetRow> createState() =>
      _LinkSearchSheetRowState();
}

class _LinkSearchSheetRowState extends ConsumerState<_LinkSearchSheetRow> {
  List<Map<String, String>> _results = const [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  Future<void> _search(String txt) async {
    setState(() => _loading = true);
    try {
      final r = await ref
          .read(recordsRepositoryProvider)
          .searchLink(widget.doctype, txt: txt);
      if (mounted) setState(() => _results = r);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppDimens.md),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search ${widget.doctype}…',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: _search,
              ),
            ),
            if (_loading) const LinearProgressIndicator(),
            Expanded(
              child: ListView.separated(
                itemCount: _results.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final r = _results[i];
                  return ListTile(
                    title: Text(r['label'] ?? ''),
                    subtitle: (r['label'] != r['value'])
                        ? Text(r['value'] ?? '')
                        : null,
                    onTap: () => Navigator.of(context).pop(r['value']),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
