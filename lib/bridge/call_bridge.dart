import 'dart:async';

import 'package:flutter/services.dart';

/// Flutter ↔ Kotlin bridge for the CallVault critical recording prototype.
class CallBridge {
  CallBridge._();

  static const MethodChannel _methods =
      MethodChannel('com.callvault.prototype/bridge');
  static const EventChannel _events =
      EventChannel('com.callvault.prototype/events');

  static StreamSubscription<dynamic>? _subscription;
  static final _controller = StreamController<Map<String, dynamic>>.broadcast();

  static Stream<Map<String, dynamic>> get events => _controller.stream;

  static Future<void> listen() async {
    await _subscription?.cancel();
    try {
      _subscription = _events.receiveBroadcastStream().listen(
        (event) {
          if (event is Map) {
            _controller.add(Map<String, dynamic>.from(event));
          }
        },
        onError: (Object error) {
          _controller.addError(error);
        },
      );
    } on MissingPluginException {
      // Expected in widget tests / non-Android hosts.
    }
  }

  static Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  static Future<Map<String, dynamic>> ping() async {
    final result = await _methods.invokeMethod<dynamic>('ping');
    return Map<String, dynamic>.from(result as Map);
  }

  static Future<Map<String, bool>> checkPermissions() async {
    final result = await _methods.invokeMethod<dynamic>('checkPermissions');
    return (result as Map).map((k, v) => MapEntry(k.toString(), v == true));
  }

  static Future<void> requestPermissions() async {
    await _methods.invokeMethod<dynamic>('requestPermissions');
  }

  static Future<void> openAppSettings() async {
    await _methods.invokeMethod<dynamic>('openAppSettings');
  }

  static Future<Map<String, dynamic>> startCallMonitor() async {
    final result = await _methods.invokeMethod<dynamic>('startCallMonitor');
    return Map<String, dynamic>.from(result as Map);
  }

  static Future<Map<String, dynamic>> stopCallMonitor() async {
    final result = await _methods.invokeMethod<dynamic>('stopCallMonitor');
    return Map<String, dynamic>.from(result as Map);
  }

  static Future<Map<String, dynamic>> startRecording() async {
    final result = await _methods.invokeMethod<dynamic>('startRecording');
    return Map<String, dynamic>.from(result as Map);
  }

  static Future<Map<String, dynamic>> stopRecording() async {
    final result = await _methods.invokeMethod<dynamic>('stopRecording');
    return Map<String, dynamic>.from(result as Map);
  }

  static Future<String?> getLastRecordingPath() async {
    return _methods.invokeMethod<String>('getLastRecordingPath');
  }

  static Future<List<Map<String, dynamic>>> listRecordings() async {
    final result = await _methods.invokeMethod<dynamic>('listRecordings');
    if (result is! List) return const [];
    return result
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static Future<Map<String, dynamic>> getShizukuStatus() async {
    final result = await _methods.invokeMethod<dynamic>('getShizukuStatus');
    return Map<String, dynamic>.from(result as Map);
  }

  static Future<Map<String, dynamic>> requestShizukuPermission() async {
    final result = await _methods.invokeMethod<dynamic>('requestShizukuPermission');
    return Map<String, dynamic>.from(result as Map);
  }

  static Future<bool> openShizukuApp() async {
    final result = await _methods.invokeMethod<dynamic>('openShizukuApp');
    return result == true;
  }

  static Future<void> setUseShizuku(bool enabled) async {
    await _methods.invokeMethod<dynamic>('setUseShizuku', {'enabled': enabled});
  }

  static Future<bool> getUseShizuku() async {
    final result = await _methods.invokeMethod<dynamic>('getUseShizuku');
    return (result as Map)['useShizuku'] == true;
  }

  static Future<List<Map<String, dynamic>>> listSmsInbox({int limit = 100}) async {
    final result = await _methods.invokeMethod<dynamic>('listSmsInbox', {'limit': limit});
    if (result is! List) return const [];
    return result
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static Future<Map<String, dynamic>> setSmsRead({
    required int id,
    required bool read,
  }) async {
    final result = await _methods.invokeMethod<dynamic>('setSmsRead', {
      'id': id,
      'read': read,
    });
    return Map<String, dynamic>.from(result as Map);
  }

  static Future<Map<String, dynamic>> setSmsThreadRead({
    required String address,
    required bool read,
  }) async {
    final result = await _methods.invokeMethod<dynamic>('setSmsThreadRead', {
      'address': address,
      'read': read,
    });
    return Map<String, dynamic>.from(result as Map);
  }

  static Future<List<Map<String, dynamic>>> listSmsConversations({
    int limit = 80,
  }) async {
    final result =
        await _methods.invokeMethod<dynamic>('listSmsConversations', {'limit': limit});
    if (result is! List) return const [];
    return result
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> listSmsThread(String address) async {
    final result = await _methods.invokeMethod<dynamic>('listSmsThread', {
      'address': address,
      'limit': 200,
    });
    if (result is! List) return const [];
    return result
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> listSims() async {
    final result = await _methods.invokeMethod<dynamic>('listSims');
    if (result is! List) return const [];
    return result
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static Future<Map<String, dynamic>> sendSms({
    required String address,
    required String body,
    int subscriptionId = -1,
  }) async {
    final result = await _methods.invokeMethod<dynamic>('sendSms', {
      'address': address,
      'body': body,
      'subscriptionId': subscriptionId,
    });
    return Map<String, dynamic>.from(result as Map);
  }

  static Future<Map<String, dynamic>> sendSmsBlast({
    required List<String> addresses,
    required String body,
    int subscriptionId = -1,
    bool allSims = false,
    String? blastId,
  }) async {
    final result = await _methods.invokeMethod<dynamic>('sendSmsBlast', {
      'addresses': addresses,
      'body': body,
      'subscriptionId': subscriptionId,
      'allSims': allSims,
      'blastId': blastId,
    });
    return Map<String, dynamic>.from(result as Map);
  }

  static Future<void> cancelSmsBlast() async {
    await _methods.invokeMethod<dynamic>('cancelSmsBlast');
  }

  static Future<List<Map<String, dynamic>>> listContacts({int limit = 500}) async {
    final result = await _methods.invokeMethod<dynamic>('listContacts', {'limit': limit});
    if (result is! List) return const [];
    return result
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static Future<String?> resolveContactName(String address) async {
    if (address.trim().isEmpty) return null;
    final result = await _methods.invokeMethod<dynamic>('resolveContactName', {
      'address': address,
    });
    if (result is! Map) return null;
    final name = result['name']?.toString().trim();
    if (name == null || name.isEmpty) return null;
    return name;
  }

  static Future<bool> isDefaultSmsApp() async {
    final result = await _methods.invokeMethod<dynamic>('isDefaultSmsApp');
    return (result as Map)['isDefault'] == true;
  }

  static Future<bool> requestDefaultSmsRole() async {
    final result = await _methods.invokeMethod<dynamic>('requestDefaultSmsRole');
    return (result as Map)['requested'] == true;
  }

  static Future<bool> openMmsComposer({
    required List<String> addresses,
    String body = '',
  }) async {
    final result = await _methods.invokeMethod<dynamic>('openMmsComposer', {
      'addresses': addresses,
      'body': body,
    });
    return (result as Map)['ok'] == true;
  }

  static Future<Map<String, dynamic>> scheduleSmsBlast({
    required List<String> addresses,
    required String body,
    required int triggerAtMs,
    int subscriptionId = -1,
    bool allSims = false,
    String priority = 'Low',
  }) async {
    final result = await _methods.invokeMethod<dynamic>('scheduleSmsBlast', {
      'addresses': addresses,
      'body': body,
      'triggerAtMs': triggerAtMs,
      'subscriptionId': subscriptionId,
      'allSims': allSims,
      'priority': priority,
    });
    return Map<String, dynamic>.from(result as Map);
  }

  static Future<List<Map<String, dynamic>>> listScheduledBlasts() async {
    final result = await _methods.invokeMethod<dynamic>('listScheduledBlasts');
    if (result is! List) return const [];
    return result
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}
