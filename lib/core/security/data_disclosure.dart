import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../router/app_router.dart';

/// Google Play "prominent disclosure": before the app asks Android for a
/// sensitive permission it must say, in its own UI, what it collects and why,
/// and get an explicit yes. Each disclosure is shown once; the answer is
/// remembered so the user is not asked again on every launch.
enum DataDisclosure {
  /// Calls: phone state, call log, contacts and call recordings.
  calls(
    title: 'Call logging for your leads',
    body:
        'This app reads your phone state, call log and contacts to recognise '
        'when you call or are called by a lead or customer. After such a '
        'call it uploads the call details and the recording saved by your '
        "phone's recorder to your company's ERP, where it is transcribed and "
        'summarised for the lead.\n\n'
        'This also works when the app is closed. Personal calls that do not '
        'match a lead or customer are not uploaded. You can turn call logging '
        'off any time in Settings → Call detection.',
  ),

  /// Background location for sales field tracking.
  backgroundLocation(
    title: 'Location while you are on duty',
    body:
        "This app collects your location to show your manager your field "
        'visits and route during working hours, even when the app is closed '
        'or not in use.\n\n'
        "Location is sent only to your company's ERP and only while tracking "
        'is on. A notification is always shown while it runs, and tracking '
        'stops when you sign out.',
  );

  const DataDisclosure({required this.title, required this.body});
  final String title;
  final String body;

  String get _key => 'disclosure_${name}_v1';
}

const _boxName = 'tcb_onboarding';

Future<Box> _box() async =>
    Hive.isBoxOpen(_boxName) ? Hive.box(_boxName) : Hive.openBox(_boxName);

/// The user's earlier answer: true accepted, false declined, null not asked.
Future<bool?> disclosureAnswer(DataDisclosure d) async =>
    (await _box()).get(d._key) as bool?;

/// Shows [d] (once) and returns whether the user agreed. Returns the stored
/// answer without showing anything when it was already answered, and false
/// when no screen is available to show it on.
Future<bool> ensureDisclosureAccepted(DataDisclosure d) async {
  final previous = await disclosureAnswer(d);
  if (previous != null) return previous;

  final context = rootNavigatorKey.currentContext;
  if (context == null || !context.mounted) return false;
  final accepted = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _DisclosureDialog(disclosure: d),
      ) ??
      false;
  await (await _box()).put(d._key, accepted);
  return accepted;
}

/// Lets Settings offer the disclosure again after the user declined it.
Future<void> resetDisclosure(DataDisclosure d) async =>
    (await _box()).delete(d._key);

class _DisclosureDialog extends StatelessWidget {
  const _DisclosureDialog({required this.disclosure});
  final DataDisclosure disclosure;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(disclosure.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(disclosure.body),
            if (AppConfig.privacyPolicyUrl.isNotEmpty)
              TextButton(
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: () => launchUrl(
                  Uri.parse(AppConfig.privacyPolicyUrl),
                  mode: LaunchMode.externalApplication,
                ),
                child: const Text('Privacy policy'),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('No thanks'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Agree and continue'),
        ),
      ],
    );
  }
}
