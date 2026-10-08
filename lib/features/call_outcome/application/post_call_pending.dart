import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks a "user just tapped a call icon — when they return to the app,
/// open the post-call outcome sheet for this lead/deal" intent (Runo R.1).
///
/// The intent is auto-cleared after [kPostCallWindow]; if the user takes
/// longer than that to return, we assume they cancelled or got distracted.
@immutable
class PostCallIntent {
  const PostCallIntent({
    required this.referenceDoctype,
    required this.referenceDocname,
    required this.parentLabel,
    required this.tappedAt,
  });

  final String referenceDoctype;
  final String referenceDocname;
  final String parentLabel;
  final DateTime tappedAt;

  bool isExpired(Duration window) =>
      DateTime.now().difference(tappedAt) > window;
}

/// Max wait between tapping the call icon and returning to the app for the
/// post-call sheet to auto-open. Tuned for a typical conversation.
const Duration kPostCallWindow = Duration(minutes: 5);

class PostCallPendingNotifier extends Notifier<PostCallIntent?> {
  @override
  PostCallIntent? build() => null;

  void register({
    required String referenceDoctype,
    required String referenceDocname,
    required String parentLabel,
  }) {
    state = PostCallIntent(
      referenceDoctype: referenceDoctype,
      referenceDocname: referenceDocname,
      parentLabel: parentLabel,
      tappedAt: DateTime.now(),
    );
  }

  void clear() => state = null;
}

final postCallPendingProvider =
    NotifierProvider<PostCallPendingNotifier, PostCallIntent?>(
  PostCallPendingNotifier.new,
);
