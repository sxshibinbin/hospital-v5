import 'dart:io';
import 'package:flutter/material.dart';

class AppConfig {
  // 资质齐全后关闭此开关，重新发布 iOS。
  static const bool iosLimitedModeEnabled = true;
  @visibleForTesting
  static bool? debugLimitedModeOverride;

  static bool get iosLimitedMode {
    var limited = Platform.isIOS && iosLimitedModeEnabled;
    assert(() {
      limited = debugLimitedModeOverride ?? limited;
      return true;
    }());
    return limited;
  }

  static bool hidesMessage(String text) =>
      hidesMetric(text) ||
      (iosLimitedMode && RegExp(r'偏高|偏低|心率异常|呼吸异常|异常心率|异常呼吸').hasMatch(text));
  static const neutralColor = Color(0xFF5B57F7);

  static bool hidesMetric(String name) =>
      iosLimitedMode &&
      [
        '血压',
        '收缩压',
        '舒张压',
        '血氧',
        '体温',
        '温度',
        'bloodpressure',
        'systolic',
        'diastolic',
        'spo2',
        'temperature',
      ].any((word) => name.toLowerCase().contains(word));

  static String message(String text) => iosLimitedMode
      ? text
            .replaceAll('报警', '消息')
            .replaceAll('警告', '消息')
            .replaceAll('告警', '消息')
            .replaceAll('预警', '消息')
            .replaceAll('接警人员', '接收人员')
      : text;
}

// 同时处理固定文案与接口返回文案，不修改原始数据和协议值。
class DeviceMessageText extends Text {
  const DeviceMessageText(
    super.data, {
    super.key,
    super.style,
    super.textAlign,
    super.maxLines,
    super.overflow,
    super.softWrap,
    super.textWidthBasis,
  });

  @override
  String? get data =>
      super.data == null ? null : AppConfig.message(super.data!);
}
