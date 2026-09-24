import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

/// Opens a modal player for a local recording file.
Future<void> showRecordingPlaybackModal(
  BuildContext context, {
  required String path,
  required String title,
  required AudioPlayer player,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return RecordingPlaybackModal(
        path: path,
        title: title,
        player: player,
      );
    },
  );
}

class RecordingPlaybackModal extends StatefulWidget {
  const RecordingPlaybackModal({
    super.key,
    required this.path,
    required this.title,
    required this.player,
  });

  final String path;
  final String title;
  final AudioPlayer player;

  @override
  State<RecordingPlaybackModal> createState() => _RecordingPlaybackModalState();
}

class _RecordingPlaybackModalState extends State<RecordingPlaybackModal> {
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<void>? _completeSub;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  PlayerState _playerState = PlayerState.stopped;
  bool _loading = true;
  bool _seeking = false;
  String? _error;

  bool get _isPlaying => _playerState == PlayerState.playing;

  @override
  void initState() {
    super.initState();
    _bindPlayer();
    _startPlayback();
  }

  void _bindPlayer() {
    _positionSub = widget.player.onPositionChanged.listen((pos) {
      if (!_seeking && mounted) {
        setState(() => _position = pos);
      }
    });
    _durationSub = widget.player.onDurationChanged.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });
    _stateSub = widget.player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playerState = state);
    });
    _completeSub = widget.player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playerState = PlayerState.completed;
          _position = _duration;
        });
      }
    });
  }

  Future<void> _startPlayback() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.player.stop();
      await widget.player.setReleaseMode(ReleaseMode.stop);
      await widget.player.setVolume(1.0);
      await widget.player.play(DeviceFileSource(widget.path));
      final dur = await widget.player.getDuration();
      if (mounted) {
        setState(() {
          _duration = dur ?? Duration.zero;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Playback failed: $e';
        });
      }
    }
  }

  Future<void> _togglePlayPause() async {
    try {
      if (_isPlaying) {
        await widget.player.pause();
      } else if (_playerState == PlayerState.completed ||
          (_duration > Duration.zero && _position >= _duration)) {
        await widget.player.seek(Duration.zero);
        await widget.player.resume();
      } else if (_playerState == PlayerState.paused) {
        await widget.player.resume();
      } else {
        await widget.player.play(DeviceFileSource(widget.path));
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _skip(Duration offset) async {
    final target = _position + offset;
    final clamped = Duration(
      milliseconds: target.inMilliseconds
          .clamp(0, _duration.inMilliseconds > 0 ? _duration.inMilliseconds : 0),
    );
    await widget.player.seek(clamped);
    if (mounted) setState(() => _position = clamped);
  }

  Future<void> _onSeekStart(double _) async {
    _seeking = true;
  }

  Future<void> _onSeekEnd(double valueMs) async {
    final target = Duration(milliseconds: valueMs.round());
    await widget.player.seek(target);
    if (mounted) {
      setState(() {
        _position = target;
        _seeking = false;
      });
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _stateSub?.cancel();
    _completeSub?.cancel();
    widget.player.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxMs = _duration.inMilliseconds > 0
        ? _duration.inMilliseconds.toDouble()
        : 1.0;
    final posMs = _position.inMilliseconds
        .clamp(0, _duration.inMilliseconds > 0 ? _duration.inMilliseconds : 0)
        .toDouble();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Now playing',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              widget.path,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(),
              )
            else ...[
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ),
              Slider(
                value: posMs.clamp(0, maxMs),
                max: maxMs,
                onChangeStart: _onSeekStart,
                onChanged: (v) {
                  setState(() => _position = Duration(milliseconds: v.round()));
                },
                onChangeEnd: _onSeekEnd,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_format(_position), style: theme.textTheme.bodySmall),
                  Text(_format(_duration), style: theme.textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Back 10 seconds',
                    iconSize: 36,
                    onPressed: () => _skip(const Duration(seconds: -10)),
                    icon: const Icon(Icons.replay_10),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _togglePlayPause,
                    style: FilledButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(18),
                    ),
                    child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 36,
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    tooltip: 'Forward 10 seconds',
                    iconSize: 36,
                    onPressed: () => _skip(const Duration(seconds: 10)),
                    icon: const Icon(Icons.forward_10),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _format(Duration d) {
    final total = d.inSeconds;
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
