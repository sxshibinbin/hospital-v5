import 'dart:io' show Platform;

import 'package:flutter/services.dart';

const _systemChannel = MethodChannel('hospital/system');

Future<bool> openExternalUrl(String url) async {
  final operatingSystem = Platform.operatingSystem.toLowerCase();
  final isHarmonyOS = operatingSystem.contains('ohos') ||
      operatingSystem.contains('openharmony') ||
      operatingSystem.contains('harmony');
  if (!isHarmonyOS) {
    return false;
  }

  await _systemChannel.invokeMethod<void>('openUrl', <String, dynamic>{
    'url': url,
  });
  return true;
}

