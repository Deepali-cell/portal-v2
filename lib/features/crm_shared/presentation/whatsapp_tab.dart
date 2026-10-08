import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../application/providers.dart';
import '../domain/crm_ref.dart';
import '../domain/models.dart';

/// WhatsApp conversation for a lead/deal.
///
/// When the server has the WhatsApp Business Cloud API configured, send goes
/// out from the company number and the customer's replies land here (polled
/// while the tab is open) — the salesperson never uses their own WhatsApp.
/// Otherwise it falls back to click-to-chat: open wa.me with the message
/// pre-filled and log the text so the team still sees it as chat bubbles.
class WhatsAppTab extends ConsumerStatefulWidget {
  const WhatsAppTab({super.key, required this.crmRef, this.suggestedPhone});
  final CrmRef crmRef;
  final String? suggestedPhone;

  @override
  ConsumerState<WhatsAppTab> createState() => _WhatsAppTabState();
}

// Fixed WhatsApp brand greens so the screen reads as "WhatsApp" regardless of
// the tenant's own palette.
const _waGreen = Color(0xFF25D366);
const _waTeal = Color(0xFF075E54);
const _outBubble = Color(0xFFDCF8C6);

final _time = DateFormat('h:mm a');

class _WhatsAppTabState extends ConsumerState<WhatsAppTab> {
  final _input = TextEditingController();
  bool _sending = false;
  Timer? _poll;

  bool get _cloud => ref.read(whatsAppCloudProvider).value ?? false;

  @override
  void initState() {
    super.initState();
    // Pick up customer replies while the conversation is open (cloud mode).
    _poll = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted && _cloud) ref.invalidate(whatsAppProvider(widget.crmRef));
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _input.dispose();
    super.dispose();
  }

  // Digits-only E.164-ish number for wa.me. Best-effort for India-first data:
  // strip symbols; a bare 10-digit or 0-prefixed number gets the 91 country
  // code. Numbers that already carry a country code are used as-is.
  String? _waNumber() {
    final raw = widget.suggestedPhone?.trim();
    if (raw == null || raw.isEmpty) return null;
    var d = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.length == 11 && d.startsWith('0')) d = d.substring(1);
    if (d.length == 10) d = '91$d';
    return d.isEmpty ? null : d;
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    final number = _waNumber();

    setState(() => _sending = true);
    try {
      if (_cloud) {
        // Sent by the server from the company WhatsApp number.
        await ref
            .read(crmCollabRepositoryProvider)
            .sendWhatsApp(widget.crmRef, message: text);
        ref.invalidate(whatsAppProvider(widget.crmRef));
        _input.clear();
        return;
      }

      // Click-to-chat: 1) Log it first so the record survives even if WhatsApp doesn't open.
      await ref.read(crmCollabRepositoryProvider).logWhatsApp(
            widget.crmRef,
            message: text,
            toNumber: number,
          );
      ref.invalidate(whatsAppProvider(widget.crmRef));
      _input.clear();

      // 2) Open WhatsApp with the number + message pre-filled.
      final q = Uri.encodeComponent(text);
      final uri = Uri.parse(
          number != null ? 'https://wa.me/$number?text=$q' : 'https://wa.me/?text=$q');
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not open WhatsApp on this device.')));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(WhatsAppMessage m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text('This will remove it from the log for everyone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(crmCollabRepositoryProvider).deleteWhatsApp(m.name);
      ref.invalidate(whatsAppProvider(widget.crmRef));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(whatsAppProvider(widget.crmRef));
    final cloud = ref.watch(whatsAppCloudProvider).value ?? false;
    final number = _waNumber();
    return Scaffold(
      backgroundColor: const Color(0xFFECE5DD), // WhatsApp chat backdrop.
      body: Column(
        children: [
          if (number == null) _noNumberBanner(cloud),
          Expanded(
            child: async.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                  child: Text(
                      e is ApiException ? e.message : 'Could not load chat.')),
              data: (msgs) {
                if (msgs.isEmpty) return _empty(cloud);
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(whatsAppProvider(widget.crmRef)),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.md, vertical: AppDimens.md),
                    itemCount: msgs.length,
                    itemBuilder: (_, i) => _Bubble(
                        msg: msgs[i],
                        onDelete: msgs[i].isClickToChat
                            ? () => _delete(msgs[i])
                            : null),
                  ),
                );
              },
            ),
          ),
          _composer(enabled: !cloud || number != null),
        ],
      ),
    );
  }

  Widget _noNumberBanner(bool cloud) => Container(
        width: double.infinity,
        color: AppColors.warning.withValues(alpha: 0.15),
        padding:
            const EdgeInsets.symmetric(horizontal: AppDimens.md, vertical: 8),
        child: Text(
          cloud
              ? 'No mobile number on this record. Add one to send WhatsApp.'
              : 'No phone number on this record — WhatsApp will open the '
                  'contact picker. Add a mobile number to send directly.',
          style: TextStyle(fontSize: 12, color: AppColors.ink),
        ),
      );

  Widget _empty(bool cloud) => ListView(
        children: [
          const SizedBox(height: 80),
          Icon(Icons.chat_bubble_outline, size: 44, color: _waTeal),
          const SizedBox(height: AppDimens.md),
          Center(
            child: Text('No messages yet',
                style: TextStyle(
                    color: _waTeal, fontWeight: FontWeight.w600, fontSize: 15)),
          ),
          const SizedBox(height: 6),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                cloud
                    ? 'Messages go from the company WhatsApp number and the '
                        "customer's replies show up here."
                    : 'Type below and tap send — it opens WhatsApp with the '
                        'message ready, and logs it here for your team.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ),
          ),
        ],
      );

  Widget _composer({required bool enabled}) {
    return Container(
      color: const Color(0xFFF0F0F0),
      padding: EdgeInsets.fromLTRB(
          AppDimens.sm, AppDimens.sm, AppDimens.sm, AppDimens.sm),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.black12),
                ),
                child: TextField(
                  controller: _input,
                  enabled: enabled,
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Type a message',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Material(
              color: enabled ? _waGreen : Colors.black26,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _sending || !enabled ? null : _send,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _sending
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send, color: Colors.white, size: 22),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.msg, this.onDelete});
  final WhatsAppMessage msg;

  /// Null for messages actually sent/received through WhatsApp — those stay.
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final out = msg.isOutgoing;
    return Align(
      alignment: out ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onDelete,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          decoration: BoxDecoration(
            color: out ? _outBubble : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(12),
              topRight: const Radius.circular(12),
              bottomLeft: Radius.circular(out ? 12 : 2),
              bottomRight: Radius.circular(out ? 2 : 12),
            ),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black12, blurRadius: 1, offset: Offset(0, 1)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(msg.ownerName,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _waTeal)),
              const SizedBox(height: 2),
              Text(msg.message,
                  style: const TextStyle(fontSize: 14.5, color: Colors.black87)),
              const SizedBox(height: 2),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_time.format(msg.creation.toLocal()),
                        style: const TextStyle(
                            fontSize: 10, color: Colors.black45)),
                    if (out && !msg.isClickToChat) ...[
                      const SizedBox(width: 3),
                      _StatusTick(status: msg.status),
                    ],
                  ],
                ),
              ),
              if (msg.status == 'Failed' && (msg.error ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('Not delivered: ${msg.error}',
                      style: TextStyle(fontSize: 11, color: AppColors.error)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// WhatsApp-style delivery ticks: ✓ sent, ✓✓ delivered, blue ✓✓ read.
class _StatusTick extends StatelessWidget {
  const _StatusTick({required this.status});
  final String? status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case 'Failed':
        return Icon(Icons.error_outline, size: 14, color: AppColors.error);
      case 'Read':
        return const Icon(Icons.done_all, size: 14, color: Color(0xFF34B7F1));
      case 'Delivered':
        return const Icon(Icons.done_all, size: 14, color: Colors.black45);
      default:
        return const Icon(Icons.done, size: 14, color: Colors.black45);
    }
  }
}
