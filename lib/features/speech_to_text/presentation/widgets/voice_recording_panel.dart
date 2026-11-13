import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/recording_phase.dart';

class VoiceRecordingPanel extends StatefulWidget {
  const VoiceRecordingPanel({
    super.key,
    required this.listening,
    required this.processing,
    required this.level,
    required this.onTap,
    this.phase = RecordingPhase.idle,
    this.audioSaved = false,
  });
  final bool listening;
  final bool processing;
  final double level;
  final VoidCallback onTap;
  final RecordingPhase phase;
  final bool audioSaved;
  @override
  State<VoiceRecordingPanel> createState() => _VoiceRecordingPanelState();
}

class _VoiceRecordingPanelState extends State<VoiceRecordingPanel> {
  Timer? _timer;
  int _seconds = 0;
  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(VoiceRecordingPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listening != widget.listening) {
      if (widget.listening) _seconds = 0;
      _syncTimer();
    }
  }

  void _syncTimer() {
    _timer?.cancel();
    if (widget.listening) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _seconds++);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = widget.listening || widget.processing;
    final minutes = (_seconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_seconds % 60).toString().padLeft(2, '0');
    return Semantics(
      button: true,
      enabled: !widget.processing,
      label: widget.processing
          ? 'Finishing transcription'
          : widget.listening
          ? 'Stop recording'
          : 'Start recording',
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(26),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.processing ? null : widget.onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (active)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        widget.processing
                            ? Icons.auto_awesome_outlined
                            : Icons.circle,
                        size: 12,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.processing
                            ? switch (widget.phase) {
                                RecordingPhase.preparing => 'PREPARING',
                                RecordingPhase.saving => 'SAVING',
                                RecordingPhase.transcribing =>
                                  'TRANSCRIBING · MICROPHONE OFF',
                                _ => 'FINISHING',
                              }
                            : 'RECORDING',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                if (active) ...[
                  const SizedBox(height: 12),
                  if (widget.listening)
                    Text(
                      '$minutes:$seconds',
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  SizedBox(
                    height: 70,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _WavePainter(
                        level: widget.level,
                        listening: widget.listening,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.mic_rounded,
                      size: 42,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                if (widget.processing) ...[
                  CircularProgressIndicator(color: scheme.primary),
                  const SizedBox(height: 14),
                ],
                Text(
                  widget.processing
                      ? widget.phase == RecordingPhase.preparing
                            ? 'Preparing microphone…'
                            : 'Finishing your note…'
                      : widget.listening
                      ? 'Listening to your thoughts'
                      : 'Tap to record',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  widget.processing
                      ? widget.audioSaved
                            ? 'Microphone off. Your audio is kept in Saved recordings.'
                            : 'Your text will save automatically.'
                      : widget.listening
                      ? 'Tap Stop when you are finished.'
                      : 'Your voice. Your words. Saved after Stop.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.level,
    required this.listening,
    required this.color,
  });
  final double level;
  final bool listening;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final amplitude = listening ? (level.abs() / 10).clamp(.15, 1.0) : .12;
    final paint = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const count = 45;
    for (var i = 0; i < count; i++) {
      final x = size.width * (i + .5) / count;
      final envelope = math.sin(math.pi * i / (count - 1));
      final wave = (.25 + .75 * math.sin(i * 1.7).abs()) * envelope;
      final height = 3 + wave * amplitude * (size.height - 10);
      paint.color = color;
      canvas.drawLine(
        Offset(x, (size.height - height) / 2),
        Offset(x, (size.height + height) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) =>
      oldDelegate.level != level ||
      oldDelegate.listening != listening ||
      oldDelegate.color != color;
}
