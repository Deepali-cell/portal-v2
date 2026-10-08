import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/router/nav_history.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../data/recording_repository.dart';

/// Global CRM "Recordings" screen: lists every call recording the signed-in
/// user can see (their own, or all when admin/HR) and plays them inline.
///
/// Recordings are private files on the server, so playback first downloads the
/// bytes through the authenticated API (RecordingRepository.downloadRecording)
/// to a temp file, then feeds that local path to a single shared [AudioPlayer].
class RecordingsScreen extends ConsumerStatefulWidget {
  const RecordingsScreen({super.key});

  @override
  ConsumerState<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends ConsumerState<RecordingsScreen> {
  final AudioPlayer _player = AudioPlayer();

  late Future<List<CallRecording>> _future;

  /// Local temp paths for recordings already downloaded this session, keyed by
  /// recording name — so re-playing one doesn't re-download it.
  final Map<String, String> _paths = {};

  String? _playingName; // recording currently loaded into the player
  String? _busyName; // recording currently downloading
  PlayerState _state = PlayerState.stopped;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;

  RecordingRepository get _repo => RecordingRepository(ref.read(dioProvider));

  @override
  void initState() {
    super.initState();
    _future = _repo.listMine();
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _dur = d);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _pos = p);
    });
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _state = s);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _state = PlayerState.completed;
          _pos = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final f = _repo.listMine();
    setState(() => _future = f);
    await f;
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _togglePlay(CallRecording r) async {
    // Tapping the recording already loaded just pauses/resumes it.
    if (_playingName == r.name) {
      if (_state == PlayerState.playing) {
        await _player.pause();
      } else {
        await _player.resume();
      }
      return;
    }

    setState(() => _busyName = r.name);
    try {
      final path = _paths[r.name] ??= await _repo.downloadRecording(r.name);
      await _player.stop();
      if (!mounted) return;
      setState(() {
        _playingName = r.name;
        _pos = Duration.zero;
        _dur = Duration.zero;
      });
      await _player.play(DeviceFileSource(path));
    } on ApiException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('Could not play this recording.');
    } finally {
      if (mounted) setState(() => _busyName = null);
    }
  }

  Future<void> _seek(double seconds) async {
    await _player.seek(Duration(milliseconds: (seconds * 1000).round()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.canvas,
        leading: AppBackButton(color: AppColors.canvas),
        title: const Text('Recordings'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<CallRecording>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return _message(
                icon: Icons.error_outline,
                title: 'Could not load recordings',
                detail: snap.error is ApiException
                    ? (snap.error as ApiException).message
                    : 'Please try again.',
              );
            }
            final items = snap.data ?? const <CallRecording>[];
            if (items.isEmpty) {
              return _message(
                icon: Icons.mic_none,
                title: 'No recordings yet',
                detail:
                    'Call recordings that match a lead or deal will appear here.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppDimens.md),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppDimens.sm),
              itemBuilder: (_, i) => _RecordingCard(
                r: items[i],
                isCurrent: _playingName == items[i].name,
                isPlaying: _playingName == items[i].name &&
                    _state == PlayerState.playing,
                isBusy: _busyName == items[i].name,
                position: _pos,
                duration: _dur,
                onPlayPause: () => _togglePlay(items[i]),
                onSeek: _seek,
                onTranscript: () => _showTranscript(items[i]),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _showTranscript(CallRecording r) async {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _TranscriptSheet(recordingName: r.name, repo: _repo),
    );
  }

  Widget _message({
    required IconData icon,
    required String title,
    required String detail,
  }) {
    // Wrapped in a scroll view so pull-to-refresh works even when empty.
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.22),
        Icon(icon, size: 48, color: AppColors.inkFaint),
        const SizedBox(height: AppDimens.md),
        Center(
          child: Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: AppColors.ink)),
        ),
        const SizedBox(height: AppDimens.xs),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.xl),
          child: Text(detail,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.inkFaint)),
        ),
      ],
    );
  }
}

String _fmtDuration(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

Color _statusColor(String status) {
  switch (status) {
    case 'Ready':
      return AppColors.success;
    case 'Failed':
      return AppColors.danger;
    default:
      return AppColors.warning; // Uploaded / Transcribing / Summarizing
  }
}

class _RecordingCard extends StatelessWidget {
  const _RecordingCard({
    required this.r,
    required this.isCurrent,
    required this.isPlaying,
    required this.isBusy,
    required this.position,
    required this.duration,
    required this.onPlayPause,
    required this.onSeek,
    required this.onTranscript,
  });

  final CallRecording r;
  final bool isCurrent;
  final bool isPlaying;
  final bool isBusy;
  final Duration position;
  final Duration duration;
  final VoidCallback onPlayPause;
  final ValueChanged<double> onSeek;
  final VoidCallback onTranscript;

  @override
  Widget build(BuildContext context) {
    final title = (r.matchedDisplay != null && r.matchedDisplay!.isNotEmpty)
        ? r.matchedDisplay!
        : (r.phoneNumber != null && r.phoneNumber!.isNotEmpty)
            ? r.phoneNumber!
            : 'Unknown number';
    final sub = <String>[];
    if (r.matchedDisplay != null &&
        r.matchedDisplay!.isNotEmpty &&
        r.phoneNumber != null &&
        r.phoneNumber!.isNotEmpty) {
      sub.add(r.phoneNumber!);
    }
    if (r.capturedAt != null) {
      sub.add(DateFormat('d MMM, h:mm a').format(r.capturedAt!.toLocal()));
    }
    if ((r.durationSeconds ?? 0) > 0) {
      sub.add(_fmtDuration(Duration(seconds: r.durationSeconds!)));
    }

    final hasAudio = r.recordingFile != null && r.recordingFile!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      padding: const EdgeInsets.all(AppDimens.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _playButton(hasAudio),
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _directionIcon(),
                        Expanded(
                          child: Text(title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink)),
                        ),
                      ],
                    ),
                    if (sub.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(sub.join('  •  '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, color: AppColors.inkFaint)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppDimens.sm),
              _statusBadge(),
            ],
          ),
          if (isCurrent) ...[
            const SizedBox(height: AppDimens.sm),
            _seekBar(context),
          ],
          if (r.summary != null && r.summary!.trim().isNotEmpty) ...[
            const SizedBox(height: AppDimens.sm),
            Text(r.summary!.trim(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13, color: AppColors.onSurfaceVariant)),
          ],
          if (r.isReady || (r.transcript?.isNotEmpty ?? false)) ...[
            const SizedBox(height: AppDimens.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onTranscript,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.notes, size: 18),
                label: const Text('View summary & transcript'),
              ),
            ),
          ],
          if (r.isFailed && (r.errorMessage?.isNotEmpty ?? false)) ...[
            const SizedBox(height: AppDimens.xs),
            Text(r.errorMessage!,
                style: TextStyle(fontSize: 12, color: AppColors.danger)),
          ],
        ],
      ),
    );
  }

  Widget _playButton(bool hasAudio) {
    if (isBusy) {
      return const SizedBox(
        width: 44,
        height: 44,
        child: Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return InkWell(
      onTap: hasAudio ? onPlayPause : null,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: hasAudio ? AppColors.navyTint : AppColors.line,
        ),
        child: Icon(
          isPlaying ? Icons.pause : Icons.play_arrow,
          color: hasAudio ? AppColors.navy : AppColors.inkFaint,
        ),
      ),
    );
  }

  Widget _seekBar(BuildContext context) {
    final total =
        duration.inMilliseconds > 0 ? duration.inMilliseconds / 1000.0 : 0.0;
    final cur = position.inMilliseconds / 1000.0;
    final value = total > 0 ? cur.clamp(0.0, total) : 0.0;
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: Slider(
            value: value,
            max: total > 0 ? total : 1,
            activeColor: AppColors.navy,
            inactiveColor: AppColors.line,
            onChanged: total > 0 ? onSeek : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmtDuration(position),
                  style: TextStyle(fontSize: 11, color: AppColors.inkFaint)),
              Text(_fmtDuration(duration),
                  style: TextStyle(fontSize: 11, color: AppColors.inkFaint)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _directionIcon() {
    final d = (r.direction ?? '').toLowerCase();
    if (d != 'incoming' && d != 'outgoing') return const SizedBox.shrink();
    final incoming = d == 'incoming';
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Icon(
        incoming ? Icons.call_received : Icons.call_made,
        size: 15,
        color: incoming ? AppColors.success : AppColors.navy,
      ),
    );
  }

  Widget _statusBadge() {
    final c = _statusColor(r.status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(r.status,
          style:
              TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c)),
    );
  }
}

/// Lazily loads the full recording (transcript + key points) via get(name) and
/// shows summary, sentiment, key points and the transcript.
class _TranscriptSheet extends StatefulWidget {
  const _TranscriptSheet({required this.recordingName, required this.repo});

  final String recordingName;
  final RecordingRepository repo;

  @override
  State<_TranscriptSheet> createState() => _TranscriptSheetState();
}

class _TranscriptSheetState extends State<_TranscriptSheet> {
  late Future<CallRecording> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repo.get(widget.recordingName);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, controller) => FutureBuilder<CallRecording>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            );
          }
          if (snap.hasError || !snap.hasData) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('Could not load the transcript.'),
              ),
            );
          }
          final r = snap.data!;
          return ListView(
            controller: controller,
            padding: const EdgeInsets.all(AppDimens.lg),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppDimens.md),
              if (r.summary != null && r.summary!.trim().isNotEmpty) ...[
                Text('Summary',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: AppColors.ink)),
                const SizedBox(height: 4),
                Text(r.summary!.trim(),
                    style: TextStyle(color: AppColors.onSurfaceVariant)),
                const SizedBox(height: AppDimens.md),
              ],
              if (r.keyPoints.isNotEmpty) ...[
                Text('Key points',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: AppColors.ink)),
                const SizedBox(height: 4),
                for (final k in r.keyPoints)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('•  '),
                        Expanded(
                            child: Text(k,
                                style: TextStyle(
                                    color: AppColors.onSurfaceVariant))),
                      ],
                    ),
                  ),
                const SizedBox(height: AppDimens.md),
              ],
              Text('Transcript',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: AppColors.ink)),
              const SizedBox(height: 4),
              Text(
                (r.transcript != null && r.transcript!.trim().isNotEmpty)
                    ? r.transcript!.trim()
                    : 'No transcript available.',
                style: TextStyle(height: 1.4, color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: AppDimens.xl),
            ],
          );
        },
      ),
    );
  }
}
