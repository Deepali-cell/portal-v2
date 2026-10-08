import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../application/providers.dart';
import '../domain/crm_ref.dart';
import '../domain/models.dart';

final _ts = DateFormat('d MMM, h:mm a');

class CommentsTab extends ConsumerStatefulWidget {
  const CommentsTab({super.key, required this.crmRef});
  final CrmRef crmRef;
  @override
  ConsumerState<CommentsTab> createState() => _CommentsTabState();
}

class _CommentsTabState extends ConsumerState<CommentsTab> {
  final _input = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(crmCollabRepositoryProvider)
          .createComment(widget.crmRef, text);
      _input.clear();
      ref.invalidate(commentsProvider(widget.crmRef));
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
    final async = ref.watch(commentsProvider(widget.crmRef));
    return Column(
      children: [
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text(e is ApiException ? e.message : 'Could not load.'),
            ),
            data: (comments) {
              if (comments.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppDimens.xl),
                    child: Text('No comments yet. Start the conversation.'),
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(commentsProvider(widget.crmRef)),
                child: ListView.separated(
                  reverse: true,
                  padding: const EdgeInsets.all(AppDimens.screenPadding),
                  itemCount: comments.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppDimens.sm),
                  itemBuilder: (_, i) => _CommentBubble(comment: comments[i]),
                ),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(
                AppDimens.md, AppDimens.sm, AppDimens.md, AppDimens.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(
                      hintText: 'Write a comment…',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: AppDimens.sm),
                IconButton.filled(
                  onPressed: _sending ? null : _send,
                  style: IconButton.styleFrom(backgroundColor: AppColors.navy),
                  icon: _sending
                      ? SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.canvas))
                      : Icon(Icons.send, color: AppColors.canvas),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CommentBubble extends ConsumerWidget {
  const _CommentBubble({required this.comment});
  final CrmComment comment;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.navyTint,
                child: Text(
                  (comment.owner.isNotEmpty ? comment.owner[0] : '?').toUpperCase(),
                  style: TextStyle(
                      color: AppColors.navy, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
              const SizedBox(width: AppDimens.sm),
              Expanded(
                child: Text(comment.owner,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              Text(_ts.format(comment.creation.toLocal()),
                  style: TextStyle(color: AppColors.inkFaint, fontSize: 12)),
            ],
          ),
          const SizedBox(height: AppDimens.sm),
          Text(_stripHtml(comment.content)),
        ],
      ),
    );
  }

  String _stripHtml(String s) =>
      s.replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}
