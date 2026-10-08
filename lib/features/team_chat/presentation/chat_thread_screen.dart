import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/nav_history.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../application/providers.dart';
import '../domain/models.dart';

final _time = DateFormat('h:mm a');

/// One direct (1:1) conversation. Bubbles: mine on the right (primary),
/// others on the left (surface) with the sender's name.
class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({super.key, required this.channel});
  final ChatChannel channel;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _input = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(teamChatRepositoryProvider)
          .sendMessage(widget.channel.name, text);
      _input.clear();
      ref.invalidate(chatMessagesProvider(widget.channel.name));
      ref.invalidate(chatChannelsProvider);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(chatMessagesProvider(widget.channel.name));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(),
        backgroundColor: AppColors.surfaceContainerLowest,
        title: Text(widget.channel.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          Expanded(
            child: async.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                  child: Text(e is ApiException
                      ? e.message
                      : 'Could not load chat.')),
              data: (msgs) {
                if (msgs.isEmpty) return _empty();
                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async =>
                      ref.invalidate(chatMessagesProvider(widget.channel.name)),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppDimens.md),
                    itemCount: msgs.length,
                    itemBuilder: (_, i) => _Bubble(
                        msg: msgs[i]),
                  ),
                );
              },
            ),
          ),
          _composer(),
        ],
      ),
    );
  }

  Widget _empty() => ListView(
        children: [
          const SizedBox(height: 90),
          Icon(Icons.forum_outlined, size: 44, color: AppColors.primary),
          const SizedBox(height: 12),
          Center(
            child: Text('No messages yet',
                style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15)),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text('Say hi 👋',
                style: TextStyle(color: AppColors.onSurfaceVariant)),
          ),
        ],
      );

  Widget _composer() {
    return Container(
      color: AppColors.surfaceContainerLowest,
      padding: const EdgeInsets.fromLTRB(
          AppDimens.sm, AppDimens.sm, AppDimens.sm, AppDimens.sm),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Message',
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Material(
              color: AppColors.primary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _sending ? null : _send,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _sending
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.onPrimary))
                      : Icon(Icons.send, color: AppColors.onPrimary, size: 22),
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
  const _Bubble({required this.msg});
  final ChatMessage msg;

  @override
  Widget build(BuildContext context) {
    final mine = msg.mine;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        decoration: BoxDecoration(
          color: mine ? AppColors.primary : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(mine ? 12 : 2),
            bottomRight: Radius.circular(mine ? 2 : 12),
          ),
          border: mine ? null : Border.all(color: AppColors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(msg.message,
                style: TextStyle(
                    fontSize: 14.5,
                    color: mine ? AppColors.onPrimary : AppColors.onSurface)),
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.centerRight,
              child: Text(_time.format(msg.creation.toLocal()),
                  style: TextStyle(
                      fontSize: 10,
                      color: mine
                          ? AppColors.onPrimary.withValues(alpha: 0.75)
                          : AppColors.onSurfaceVariant)),
            ),
          ],
        ),
      ),
    );
  }
}
