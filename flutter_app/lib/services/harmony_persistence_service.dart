import 'dart:io' show Platform;

import 'package:flutter/services.dart';

class HarmonyPersistenceService {
  HarmonyPersistenceService._();

  static const _channel = MethodChannel('hospital/persistence');

  static bool get isSupported {
    final os = Platform.operatingSystem.toLowerCase();
    return os.contains('ohos') || os.contains('openharmony') || os.contains('harmony');
  }

  static Future<String?> readString(String key) async {
    if (!isSupported) return null;
    final value = await _channel.invokeMethod<String>('readString', {'key': key});
    return value == null || value.isEmpty ? null : value;
  }

  static Future<void> writeString(String key, String value) async {
    if (!isSupported) return;
    await _channel.invokeMethod<void>('writeString', {'key': key, 'value': value});
  }

  static Future<bool?> readBool(String key) async {
    if (!isSupported) return null;
    return _channel.invokeMethod<bool>('readBool', {'key': key});
  }

  static Future<void> writeBool(String key, bool value) async {
    if (!isSupported) return;
    await _channel.invokeMethod<void>('writeBool', {'key': key, 'value': value});
  }
}
