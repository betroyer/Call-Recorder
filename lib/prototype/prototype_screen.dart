import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../bridge/call_bridge.dart';
import 'playback_modal.dart';

class PrototypeScreen extends StatefulWidget {
  const PrototypeScreen({super.key});

  @override
  State<PrototypeScreen> createState() => _PrototypeScreenState();
}

class _PrototypeScreenState extends State<PrototypeScreen> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<Map<String, dynamic>>? _eventsSub;

  Map<String, bool> _permissions = const {
    'microphone': false,
    'phone': false,
    'notifications': false,
  };

  String _callState = 'idle';
  String _recordingState = 'idle';
  String? _lastError;
  String? _recordingSource;
  String? _lastPath;
  String? _bridgeInfo;
  bool _monitoring = false;
  bool _autoRecord = true;
  bool _autoRecordAttemptedForCall = false;
  bool _busy = false;
  bool _heardSelf = false;
  bool _heardRemote = false;
  bool _heardBoth = false;
  bool _useShizuku = false;
  Map<String, dynamic> _shizuku = const {};

  List<Map<String, dynamic>> _recordings = const [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await CallBridge.listen();
    _eventsSub = CallBridge.events.listen(_onNativeEvent);
    try {
      final ping = await CallBridge.ping();
      _bridgeInfo =
          'Native ok · SDK ${ping['sdkInt']} · ${ping['platform']}';
    } catch (e) {
      _bridgeInfo = 'Bridge error: $e';
    }
    await _refreshPermissions();
    await _refreshShizuku();
    await _refreshRecordings();
    if (mounted) setState(() {});
  }

  void _onNativeEvent(Map<String, dynamic> event) {
    final type = event['type']?.toString();
    if (type == 'onCallState') {
      final state = event['state']?.toString() ?? 'unknown';
      setState(() => _callState = state);
      _handleAutoRecord(state);
    } else if (type == 'onShizukuState') {
      _refreshShizuku();
    } else if (type == 'onRecordingState') {
      setState(() {
        _recordingState = event['state']?.toString() ?? _recordingState;
        _lastError = event['error']?.toString();
        _recordingSource = event['source']?.toString() ?? _recordingSource;
        final path = event['path']?.toString();
        if (path != null && path.isNotEmpty) {
          _lastPath = path;
        }
      });
      if (_recordingState == 'stopped' || _recordingState == 'failed') {
        _refreshRecordings();
      }
    }
  }

  Future<void> _handleAutoRecord(String callState) async {
    if (!_autoRecord || _busy) return;

    final active = callState == 'connected' || callState == 'offhook';
    if (active) {
      if (!_autoRecordAttemptedForCall && _recordingState != 'recording') {
        _autoRecordAttemptedForCall = true;
        await _startRecording(manual: false);
      }
    } else if (callState == 'idle') {
      if (_recordingState == 'recording') {
        await _stopRecording(manual: false);
      }
      _autoRecordAttemptedForCall = false;
    }
  }

  Future<void> _refreshPermissions() async {
    try {
      final perms = await CallBridge.checkPermissions();
      if (mounted) setState(() => _permissions = perms);
    } catch (e) {
      setState(() => _lastError = e.toString());
    }
  }

  Future<void> _refreshShizuku() async {
    try {
      final status = await CallBridge.getShizukuStatus();
      final enabled = await CallBridge.getUseShizuku();
      if (mounted) {
        setState(() {
          _shizuku = status;
          _useShizuku = enabled;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _shizuku = {'error': e.toString()};
        });
      }
    }
  }

  Future<void> _setUseShizuku(bool enabled) async {
    await CallBridge.setUseShizuku(enabled);
    if (mounted) setState(() => _useShizuku = enabled);
  }

  Future<void> _refreshRecordings() async {
    try {
      final list = await CallBridge.listRecordings();
      final last = await CallBridge.getLastRecordingPath();
      if (mounted) {
        setState(() {
          _recordings = list;
          _lastPath = last ?? _lastPath;
        });
      }
    } catch (e) {
      setState(() => _lastError = e.toString());
    }
  }

  Future<void> _requestPermissions() async {
    await CallBridge.requestPermissions();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await _refreshPermissions();
  }

  Future<void> _startMonitor() async {
    setState(() {
      _busy = true;
      _lastError = null;
    });
    try {
      await CallBridge.startCallMonitor();
      setState(() => _monitoring = true);
    } catch (e) {
      setState(() => _lastError = e.toString());
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _stopMonitor() async {
    setState(() => _busy = true);
    try {
      await CallBridge.stopCallMonitor();
      setState(() => _monitoring = false);
    } catch (e) {
      setState(() => _lastError = e.toString());
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _startRecording({required bool manual}) async {
    if (_busy && manual) return;
    setState(() {
      _busy = true;
      _lastError = null;
    });
    try {
      final result = await CallBridge.startRecording();
      setState(() {
        final started = result['recordingStarted'] == true;
        _recordingState = started ? 'recording' : 'failed';
        _recordingSource = result['recordingSourceTried']?.toString();
        _lastPath = result['path']?.toString() ?? _lastPath;
        _lastError = result['error']?.toString();
      });
    } catch (e) {
      setState(() {
        _recordingState = 'failed';
        _lastError = e.toString();
      });
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _stopRecording({required bool manual}) async {
    if (_busy && manual) return;
    setState(() => _busy = true);
    try {
      final result = await CallBridge.stopRecording();
      setState(() {
        _recordingState = result['error'] == null ? 'stopped' : 'failed';
        _lastPath = result['path']?.toString() ?? _lastPath;
        _recordingSource = result['recordingSourceTried']?.toString();
        _lastError = result['error']?.toString();
      });
      await _refreshRecordings();
    } catch (e) {
      setState(() {
        _recordingState = 'failed';
        _lastError = e.toString();
      });
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _playPath(String? path) async {
    if (path == null || path.isEmpty) {
      setState(() => _lastError = 'No recording file to play');
      return;
    }
    if (!mounted) return;
    final name = path.split(RegExp(r'[/\\]')).last;
    try {
      await showRecordingPlaybackModal(
        context,
        path: path,
        title: name,
        player: _player,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _lastError = 'Playback failed: $e');
      }
    }
  }

  @override
  void dispose() {
    _eventsSub?.cancel();
    CallBridge.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('CallVault Prototype'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Two-way call audio is not guaranteed; verify by listening. '
                'Android restricts ordinary apps from capturing voice-call audio.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(_bridgeInfo ?? 'Connecting to native…',
              style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),
          _sectionTitle('Permissions'),
          _permRow('Microphone', _permissions['microphone'] == true),
          _permRow('Phone state', _permissions['phone'] == true),
          _permRow('Notifications', _permissions['notifications'] == true),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: _busy ? null : _requestPermissions,
                child: const Text('Request permissions'),
              ),
              OutlinedButton(
                onPressed: () => CallBridge.openAppSettings(),
                child: const Text('Open Settings'),
              ),
              OutlinedButton(
                onPressed: _refreshPermissions,
                child: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _sectionTitle('Shizuku (elevated recording)'),
          Text(
            'Install Shizuku, enable Wireless Debugging, start Shizuku, then grant this app. '
            'Tries VOICE_CALL / uplink / downlink in a shell process.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Text('Installed: ${_yesNo(_shizuku['installed'])}'),
          Text('Running: ${_yesNo(_shizuku['running'])}'),
          Text('Permission: ${_yesNo(_shizuku['permission'])}'),
          if (_shizuku['uidHint'] != null) Text('Ping: ${_shizuku['uidHint']}'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Use Shizuku recorder'),
            subtitle: Text(
              _useShizuku
                  ? 'Elevated shell capture (.wav)'
                  : 'Normal in-app MediaRecorder (.m4a)',
            ),
            value: _useShizuku,
            onChanged: (v) => _setUseShizuku(v),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: () async {
                  await CallBridge.requestShizukuPermission();
                  await _refreshShizuku();
                },
                child: const Text('Grant Shizuku'),
              ),
              OutlinedButton(
                onPressed: () async {
                  final ok = await CallBridge.openShizukuApp();
                  if (!ok && mounted) {
                    setState(() => _lastError = 'Shizuku app not installed');
                  }
                },
                child: const Text('Open Shizuku'),
              ),
              OutlinedButton(
                onPressed: _refreshShizuku,
                child: const Text('Refresh status'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _sectionTitle('Call monitor'),
          Text('Call state: $_callState'),
          Text('Monitoring: ${_monitoring ? 'on' : 'off'}'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto-record when call active'),
            subtitle: const Text('Starts on connected/offhook, stops on idle'),
            value: _autoRecord,
            onChanged: (v) => setState(() => _autoRecord = v),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: _busy || _monitoring ? null : _startMonitor,
                child: const Text('Start monitor'),
              ),
              OutlinedButton(
                onPressed: _busy || !_monitoring ? null : _stopMonitor,
                child: const Text('Stop monitor'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _sectionTitle('Recording'),
          Text('State: $_recordingState'),
          Text('Source: ${_recordingSource ?? '—'}'),
          Text('Last path: ${_lastPath ?? '—'}'),
          if (_lastError != null && _lastError!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Error: $_lastError',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: _busy || _recordingState == 'recording'
                    ? null
                    : () => _startRecording(manual: true),
                child: const Text('Start recording'),
              ),
              FilledButton.tonal(
                onPressed: _busy || _recordingState != 'recording'
                    ? null
                    : () => _stopRecording(manual: true),
                child: const Text('Stop recording'),
              ),
              OutlinedButton(
                onPressed: () => _playPath(_lastPath),
                child: const Text('Play last file'),
              ),
              OutlinedButton(
                onPressed: _refreshRecordings,
                child: const Text('Refresh files'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _sectionTitle('Listen checklist (manual)'),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Your voice recorded'),
            value: _heardSelf,
            onChanged: (v) => setState(() => _heardSelf = v ?? false),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Other person’s voice recorded'),
            value: _heardRemote,
            onChanged: (v) => setState(() => _heardRemote = v ?? false),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Both sides recorded'),
            value: _heardBoth,
            onChanged: (v) => setState(() => _heardBoth = v ?? false),
          ),
          const SizedBox(height: 12),
          _sectionTitle('Saved recordings'),
          if (_recordings.isEmpty)
            const Text('No recordings yet.')
          else
            ..._recordings.map((r) {
              final path = r['path']?.toString() ?? '';
              final name = r['name']?.toString() ?? path;
              final bytes = r['bytes'];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(name),
                subtitle: Text('$bytes bytes\n$path'),
                isThreeLine: true,
                trailing: IconButton(
                  icon: const Icon(Icons.play_arrow),
                  onPressed: () => _playPath(path),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }

  Widget _permRow(String label, bool granted) {
    return Row(
      children: [
        Icon(
          granted ? Icons.check_circle : Icons.cancel,
          color: granted ? Colors.green : Colors.orange,
          size: 18,
        ),
        const SizedBox(width: 8),
        Text('$label: ${granted ? 'granted' : 'denied'}'),
      ],
    );
  }

  String _yesNo(Object? value) => value == true ? 'yes' : 'no';
}
