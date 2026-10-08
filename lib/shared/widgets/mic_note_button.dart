import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';

/// Reusable mic-button that dictates speech into a [TextEditingController].
///
/// Behaviour:
///   * Tap → request mic + speech permission, then start listening.
///   * Tap again while listening → stop and commit whatever was recognised.
///   * Recognised text is APPENDED to [controller] (with a leading space if
///     existing text doesn't end in whitespace).
///   * If the device has no speech recognizer or permission is denied,
///     the button shows a friendly snackbar — never blocks the underlying
///     UI.
///
/// Wire next to any TextField where dictation helps (call summaries, lead
/// notes, etc.). Lightweight — uses one [SpeechToText] instance per button.
class MicNoteButton extends StatefulWidget {
  const MicNoteButton({
    super.key,
    required this.controller,
    this.tooltip = 'Dictate',
    this.localeId,
  });

  /// Controller whose text gets the dictated content appended.
  final TextEditingController controller;
  final String tooltip;

  /// Optional BCP-47 locale (e.g. "en_IN"). Defaults to the system locale
  /// chosen by [SpeechToText].
  final String? localeId;

  @override
  State<MicNoteButton> createState() => _MicNoteButtonState();
}

class _MicNoteButtonState extends State<MicNoteButton> {
  final _stt = SpeechToText();
  bool _ready = false;
  bool _listening = false;
  String _liveDraft = '';

  @override
  void dispose() {
    _stt.cancel();
    super.dispose();
  }

  Future<bool> _ensurePermission() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                "Microphone permission is needed to dictate. Enable it in Settings to use voice notes."),
          ),
        );
      }
      return false;
    }
    return true;
  }

  Future<void> _initIfNeeded() async {
    if (_ready) return;
    final ok = await _stt.initialize(
      onError: (_) {
        if (mounted) setState(() => _listening = false);
      },
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() => _listening = false);
        }
      },
    );
    if (mounted) setState(() => _ready = ok);
  }

  Future<void> _start() async {
    if (!await _ensurePermission()) return;
    await _initIfNeeded();
    if (!_ready) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  "Voice recognition is not available on this device.")),
        );
      }
      return;
    }
    _liveDraft = '';
    setState(() => _listening = true);
    await _stt.listen(
      onResult: (r) {
        _liveDraft = r.recognizedWords;
        if (r.finalResult) {
          _commit(r.recognizedWords);
        }
      },
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: false,
        listenMode: ListenMode.dictation,
        localeId: widget.localeId,
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _stop() async {
    await _stt.stop();
    if (_liveDraft.isNotEmpty) {
      _commit(_liveDraft);
    }
    if (mounted) setState(() => _listening = false);
  }

  void _commit(String text) {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return;
    final existing = widget.controller.text;
    final separator = existing.isEmpty || existing.endsWith(' ') ||
            existing.endsWith('\n')
        ? ''
        : ' ';
    widget.controller.text = '$existing$separator$cleaned';
    // Move cursor to end so the user can keep typing if they want.
    widget.controller.selection = TextSelection.collapsed(
        offset: widget.controller.text.length);
    _liveDraft = '';
  }

  @override
  Widget build(BuildContext context) {
    final color = _listening ? AppColors.error : AppColors.primary;
    return Tooltip(
      message: _listening ? 'Tap to stop' : widget.tooltip,
      child: InkWell(
        onTap: _listening ? _stop : _start,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.all(AppDimens.xs),
          decoration: BoxDecoration(
            color: _listening
                ? AppColors.error.withValues(alpha: 0.12)
                : AppColors.surfaceContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            _listening ? Icons.stop_circle_outlined : Icons.mic_none,
            color: color,
            size: 22,
          ),
        ),
      ),
    );
  }
}
