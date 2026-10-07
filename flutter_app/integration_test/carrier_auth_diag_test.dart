// iOS 一键登录（ali_auth 插件）适配诊断测试
//
// 目的：在无 SIM 卡的模拟器上验证原生插件链路完整：
//   1. listen 建立事件通道（原生发 500004 版本事件）
//   2. initSdk 方法通道必须回包（安卓模式对齐：code=500002），不再永久悬挂
//   3. initSdk 后原生事件流依次到达（setAuthSDKInfo/checkEnv/加速 等码）
//   4. login 在环境不可用时回包 + 事件 500003/500005
//   5. quitPage/hideLoading 回包（不悬挂）
//
// 注意：使用占位 SK（格式合法的假密钥）；模拟器无蜂窝网络，取号必然失败，
// 只验证插件↔SDK 通信链路与回包契约，真实取号需真机验证。
// 跑完本测试后必须重新 `flutter build ios --simulator --debug` 才能装正式包
//（integration test 会把 Runner.app 覆盖成测试构建）。

import 'dart:async';

import 'package:ali_auth/ali_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const String kDummyIosSk = 'eeSgOZ%2FaGXtC9dXtLWnzDuZg3URkg9C0GRGqUqBChUI1zDocumentationOnlyPlaceholderSK==';

Future<Map<String, dynamic>> _nextEvent(
  StreamSubscription<dynamic> sub,
  List<Map<String, dynamic>> sink,
  Duration timeout,
) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (sink.isNotEmpty) {
      return sink.removeAt(0);
    }
  }
  return <String, dynamic>{'code': 'TIMEOUT'};
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('ali_auth iOS 插件链路诊断', (WidgetTester tester) async {
    final events = <Map<String, dynamic>>[];

    // 1. 建立事件监听（loginListen 内部自持订阅，dispose() 统一释放）
    final listenDone = Completer<void>();
    AliAuth.loginListen(
      type: true,
      onEvent: (event) {
        if (event is Map) {
          events.add(event.map<String, dynamic>(
            (k, v) => MapEntry(k.toString(), v),
          ));
        }
        if (!listenDone.isCompleted) {
          listenDone.complete();
        }
      },
      onError: (Object? e) {
        if (!listenDone.isCompleted) {
          listenDone.completeError(e ?? 'listen error');
        }
      },
    );
    await listenDone.future.timeout(const Duration(seconds: 10));
    debugPrint('DIAG_LISTEN_OK');

    // 2. initSdk：关键回归点——必须回包（安卓模式 code=500002）
    final initWatch = Stopwatch()..start();
    dynamic initResult;
    Object? initError;
    try {
      initResult = await AliAuth.initSdk(
        AliAuthModel(
          'dummy_android_sk',
          kDummyIosSk,
          pageType: PageType.fullPort,
          isDebug: true,
          isDelay: false,
          navHidden: true,
          logoHidden: true,
          switchAccHidden: true,
          checkboxHidden: true,
          privacyState: true,
          lightColor: true,
          statusBarColor: '#F8F3FF',
          bottomNavColor: '#F8F3FF',
          numberColor: '#2F266F',
          sloganText: '运营商提供认证服务',
          sloganTextColor: '#8F88AE',
          logBtnText: '本机号码一键登录',
          logBtnTextColor: '#FFFFFF',
          logBtnMarginLeftAndRight: 28,
          logBtnHeight: 50,
          privacyTextSize: 12,
          privacyMargin: 28,
          privacyBefore: '登录即同意',
          privacyEnd: '并授权获取本机号码',
          vendorPrivacyPrefix: '《',
          vendorPrivacySuffix: '》',
          autoHideLoginLoading: true,
        ),
      ).timeout(const Duration(seconds: 20));
    } catch (e) {
      initError = e;
    }
    initWatch.stop();
    debugPrint('DIAG_INIT_RESULT=$initResult error=$initError elapsed=${initWatch.elapsedMilliseconds}ms');

    final initMap = <String, dynamic>{};
    if (initResult is Map) {
      initResult.forEach((k, v) => initMap[k.toString()] = v);
    }
    debugPrint('DIAG_INIT_CODE=${initMap['code']}');

    // 3. 收集 initSdk 之后 3 秒内的事件流
    await Future<void>.delayed(const Duration(seconds: 3));
    debugPrint('DIAG_EVENTS=${events.map((e) => e['code']).toList()}');
    for (final e in events) {
      debugPrint('DIAG_EVENT_DETAIL=$e');
    }

    // 4. quitPage / hideLoading 回包检查（核心回归：不悬挂）
    var quitElapsed = -1;
    try {
      final w = Stopwatch()..start();
      await AliAuth.quitPage().timeout(const Duration(seconds: 5));
      quitElapsed = w.elapsedMilliseconds;
    } catch (_) {}
    var hideElapsed = -1;
    try {
      final w = Stopwatch()..start();
      await AliAuth.hideLoading().timeout(const Duration(seconds: 5));
      hideElapsed = w.elapsedMilliseconds;
    } catch (_) {}
    debugPrint('DIAG_QUIT_MS=$quitElapsed DIAG_HIDE_MS=$hideElapsed');

    // 5. login 回包检查（未初始化成功环境下预期事件 500003/500005 或正常拉起后回包）
    var loginElapsed = -1;
    Object? loginError;
    try {
      final w = Stopwatch()..start();
      await AliAuth.login(timeout: 3000).timeout(const Duration(seconds: 10));
      loginElapsed = w.elapsedMilliseconds;
    } catch (e) {
      loginError = e;
    }
    debugPrint('DIAG_LOGIN_MS=$loginElapsed error=$loginError');
    debugPrint('DIAG_EVENTS_FINAL=${events.map((e) => e['code']).toList()}');

    AliAuth.dispose();

    // 断言：核心修复点
    expect(listenDone.isCompleted, isTrue, reason: '事件监听应建立成功');
    expect(
      initError,
      isNull,
      reason: 'initSdk 不应抛异常（超时说明方法通道未回包——旧版 bug）',
    );
    expect(initMap['code']?.toString(), '500002',
        reason: 'initSdk 回包 code 应为 500002（与安卓模式对齐）');
    expect(quitElapsed, greaterThanOrEqualTo(0),
        reason: 'quitPage 应在超时内回包');
    expect(hideElapsed, greaterThanOrEqualTo(0),
        reason: 'hideLoading 应在超时内回包');
    expect(loginElapsed, greaterThanOrEqualTo(0),
        reason: 'login 应在超时内回包（旧版会永久悬挂）');
  });
}
