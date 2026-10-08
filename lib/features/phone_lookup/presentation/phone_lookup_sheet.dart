import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../data/lookup_repository.dart';

/// Modal sheet to look up a CRM Lead/Deal by phone number using the
/// Phase D.1 backend endpoint. Triggered manually from the Leads screen
/// FAB. Phase D.2 will trigger the same lookup automatically when the
/// phone rings (native Android module pending).
Future<void> showPhoneLookupSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceContainerLowest,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXl)),
    ),
    builder: (_) => const _PhoneLookupSheet(),
  );
}

class _PhoneLookupSheet extends ConsumerStatefulWidget {
  const _PhoneLookupSheet();
  @override
  ConsumerState<_PhoneLookupSheet> createState() => _PhoneLookupSheetState();
}

enum _State { idle, searching, matched, noMatch, error }

class _PhoneLookupSheetState extends ConsumerState<_PhoneLookupSheet> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  _State _state = _State.idle;
  PhoneLookupResult? _result;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    // Auto-focus the input when the sheet opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _canSearch =>
      _state != _State.searching && _ctrl.text.trim().isNotEmpty;

  Future<void> _search() async {
    if (!_canSearch) return;
    final number = _ctrl.text.trim();
    setState(() {
      _state = _State.searching;
      _result = null;
      _errorMsg = null;
    });
    try {
      final repo = PhoneLookupRepository(ref.read(dioProvider));
      final r = await repo.lookup(number);
      if (!mounted) return;
      setState(() {
        _result = r;
        _state = r.matched ? _State.matched : _State.noMatch;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _State.error;
        _errorMsg = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _State.error;
        _errorMsg = "Couldn't reach the server. Try again.";
      });
    }
  }

  void _openResult() {
    final r = _result;
    if (r == null || !r.matched || r.name == null) return;
    Navigator.of(context).pop();
    if (r.isLead) {
      context.push(Routes.leadDetail, extra: r.name);
    } else if (r.isDeal) {
      context.push(Routes.dealDetail, extra: r.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppDimens.xl, AppDimens.xl, AppDimens.xl, AppDimens.xl + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Text('Find by phone',
                style: Theme.of(context).textTheme.titleLarge),
          ),
          const SizedBox(height: 2),
          Center(
            child: Text(
              "Type a number to find the matching lead or deal.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: AppDimens.lg),
          TextField(
            controller: _ctrl,
            focusNode: _focus,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            onChanged: (_) => setState(() {}),
            inputFormatters: [
              // Allow + at start, digits, spaces, dashes, parens elsewhere —
              // backend normalises anyway.
              FilteringTextInputFormatter.allow(RegExp(r'[\d\s\-\(\)\+]')),
            ],
            decoration: InputDecoration(
              labelText: 'Phone number',
              hintText: '+91 98765 43210',
              prefixIcon: const Icon(Icons.phone),
              suffixIcon: _ctrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _ctrl.clear();
                        setState(() {
                          _state = _State.idle;
                          _result = null;
                          _errorMsg = null;
                        });
                      },
                    ),
            ),
          ),
          const SizedBox(height: AppDimens.md),
          FilledButton.icon(
            onPressed: _canSearch ? _search : null,
            icon: _state == _State.searching
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.search, size: 18),
            label: Text(_state == _State.searching ? 'Searching…' : 'Search'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.secondaryContainer,
              foregroundColor: AppColors.onSecondaryContainer,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusLg),
              ),
            ),
          ),
          const SizedBox(height: AppDimens.lg),
          _ResultArea(
            state: _state,
            result: _result,
            errorMsg: _errorMsg,
            onTap: _openResult,
          ),
        ],
      ),
    );
  }
}

class _ResultArea extends StatelessWidget {
  const _ResultArea({
    required this.state,
    required this.result,
    required this.errorMsg,
    required this.onTap,
  });
  final _State state;
  final PhoneLookupResult? result;
  final String? errorMsg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case _State.idle:
      case _State.searching:
        return const SizedBox.shrink();
      case _State.matched:
        return _MatchCard(result: result!, onTap: onTap);
      case _State.noMatch:
        return _NoMatch(query: result?.normalizedQuery);
      case _State.error:
        return _ErrorState(message: errorMsg ?? 'Lookup failed.');
    }
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.result, required this.onTap});
  final PhoneLookupResult result;
  final VoidCallback onTap;

  String _initials() {
    final name = result.displayName ?? '';
    final parts = name.split(RegExp(r'\s+')).where((s) => s.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Color _typeAccent() => result.isDeal ? AppColors.tertiaryFixedDim : AppColors.secondary;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      child: Container(
        padding: const EdgeInsets.all(AppDimens.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.secondaryFixed,
              backgroundImage: (result.image == null || result.image!.isEmpty)
                  ? null
                  : NetworkImage(result.image!),
              child: (result.image == null || result.image!.isEmpty)
                  ? Text(_initials(),
                      style: TextStyle(
                          color: AppColors.onSecondaryFixed,
                          fontWeight: FontWeight.w700))
                  : null,
            ),
            const SizedBox(width: AppDimens.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                        result.displayName ?? result.name ?? '',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _typeAccent().withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        result.isDeal ? 'Deal' : 'Lead',
                        style: TextStyle(
                          color: _typeAccent(),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (result.status != null) result.status!,
                      if (result.ownerFullName != null) result.ownerFullName!,
                      if (result.daysSinceContact != null)
                        '${result.daysSinceContact} days since last contact',
                    ].where((s) => s.isNotEmpty).join(' · '),
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppDimens.xs),
            Icon(Icons.chevron_right, color: AppColors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _NoMatch extends StatelessWidget {
  const _NoMatch({this.query});
  final String? query;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      ),
      child: Row(
        children: [
          Icon(Icons.search_off, color: AppColors.onSurfaceVariant),
          const SizedBox(width: AppDimens.md),
          Expanded(
            child: Text(
              query == null || query!.isEmpty
                  ? "No matching lead or deal found."
                  : "No match for $query.",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.md),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.onErrorContainer),
          const SizedBox(width: AppDimens.md),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: AppColors.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
