import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/config/app_config.dart';

void main() {
  tearDown(() => AppConfig.debugLimitedModeOverride = null);

  test('iOS hides sensitive metrics and health assessment messages', () {
    AppConfig.debugLimitedModeOverride = true;
    for (final name in ['血压', '血氧饱和度', '体温', '收缩压', 'spo2']) {
      expect(AppConfig.hidesMetric(name), isTrue, reason: name);
    }
    for (final name in ['心率', '呼吸', '步数', '睡眠状态']) {
      expect(AppConfig.hidesMetric(name), isFalse, reason: name);
    }
    expect(AppConfig.hidesMessage('心率偏高报警'), isTrue);
    expect(AppConfig.hidesMessage('血氧饱和度报警'), isTrue);
    expect(AppConfig.hidesMessage('跌倒报警'), isFalse);
  });

  testWidgets('iOS renders server and fixed warning text as messages', (
    tester,
  ) async {
    AppConfig.debugLimitedModeOverride = true;
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: DeviceMessageText('跌倒报警 / 睡眠警告 / 离床告警')),
      ),
    );
    expect(find.text('跌倒消息 / 睡眠消息 / 离床消息'), findsOneWidget);
    expect(find.textContaining('报警'), findsNothing);
  });

  testWidgets('other platforms retain original labels and metric access', (
    tester,
  ) async {
    AppConfig.debugLimitedModeOverride = false;
    expect(AppConfig.hidesMetric('血压'), isFalse);
    expect(AppConfig.hidesMessage('心率偏高报警'), isFalse);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: DeviceMessageText('跌倒报警'))),
    );
    expect(find.text('跌倒报警'), findsOneWidget);
  });
}
