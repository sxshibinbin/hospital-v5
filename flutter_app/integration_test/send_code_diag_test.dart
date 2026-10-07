// 诊断测试：在【无后端】（本机 8000 无监听）环境下复现「发送验证码」的报错表现，
// 并逐字抓取 app UI 上出现的提示文案，用于向用户报告确切的报错内容。
// 前置：8000 端口无后端（复现连接失败路径）。
// 运行: flutter test integration_test/send_code_diag_test.dart -d <模拟器UDID>
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:flutter_app/main.dart';
import 'package:flutter_app/providers/auth_provider.dart';
import 'package:flutter_app/providers/hot_questions_provider.dart';
import 'package:flutter_app/services/api_service.dart';
import 'package:flutter_app/services/question_service.dart';

/// 轮询等待 finder 出现（避免 pumpAndSettle 被常驻定时器卡死）。
Future<bool> _pollVisible(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) {
      return true;
    }
  }
  return false;
}

/// 扫描当前可见 Text，返回第一条匹配任一 pattern 的文案。
String? _captureToast(WidgetTester tester, List<Pattern> patterns) {
  for (final widget in tester.widgetList<Text>(find.byType(Text))) {
    final data = widget.data;
    if (data == null) {
      continue;
    }
    for (final p in patterns) {
      if (p is RegExp ? p.hasMatch(data) : data.contains(p as String)) {
        return data;
      }
    }
  }
  return null;
}

/// 轮询抓取 toast 文案。
Future<String?> _waitForToast(
  WidgetTester tester,
  List<Pattern> patterns, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    final text = _captureToast(tester, patterns);
    if (text != null) {
      return text;
    }
  }
  return null;
}

Future<void> _acceptAgreement(WidgetTester tester) async {
  final tileFinder = find.byType(CheckboxListTile);
  if (tileFinder.evaluate().isEmpty) {
    return;
  }
  try {
    await tester.scrollUntilVisible(
      tileFinder.last,
      150,
      scrollable: find.byType(Scrollable).first,
      duration: const Duration(milliseconds: 300),
    );
  } catch (_) {}
  await tester.pump(const Duration(milliseconds: 300));

  Checkbox checkboxOf(Finder tile) => tester.widget<Checkbox>(
        find.descendant(of: tile, matching: find.byType(Checkbox)).first,
      );

  if (checkboxOf(tileFinder.last).value == true) {
    return;
  }
  await tester.tap(
    find.descendant(of: tileFinder.last, matching: find.byType(Checkbox)).first,
    warnIfMissed: false,
  );
  await tester.pump(const Duration(milliseconds: 300));
  if (checkboxOf(tileFinder.last).value != true) {
    await tester.tap(tileFinder.last, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('发送验证码报错诊断（无后端）', (tester) async {
    // 过滤登录页已知的 1.8px RenderFlex 溢出（纯视觉，debug 断言会判死测试）
    final bindingReporter = FlutterError.onError;
    FlutterError.onError = (details) {
      final isOverflow =
          details.exception.toString().contains('RenderFlex overflowed');
      if (!isOverflow) {
        bindingReporter?.call(details);
      }
    };

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          Provider(create: (_) => ApiService()),
          ChangeNotifierProxyProvider<AuthProvider, HotQuestionsProvider>(
            create: (context) => HotQuestionsProvider(
              questionService:
                  QuestionService(authProvider: context.read<AuthProvider>()),
            ),
            update: (context, authProvider, previous) =>
                previous ??
                HotQuestionsProvider(
                  questionService:
                      QuestionService(authProvider: authProvider),
                ),
          ),
        ],
        child: const MyApp(),
      ),
    );

    final loginReady = await _pollVisible(
      tester,
      find.text('其他手机号登录'),
      timeout: const Duration(seconds: 25),
    );
    if (!loginReady) {
      fail('登录页未渲染出「其他手机号登录」入口');
    }

    // ============ 路径 1：未勾选协议就点发送 → 协议拦截提示 ============
    // 先看协议当前状态（可能已被持久化为已接受）
    var agreementChecked = false;
    final tileFinder = find.byType(CheckboxListTile);
    if (tileFinder.evaluate().isNotEmpty) {
      final cb = tester.widget<Checkbox>(
        find.descendant(of: tileFinder.last, matching: find.byType(Checkbox)).first,
      );
      agreementChecked = cb.value == true;
    }
    debugPrint('DIAG: 协议初始状态 checked=$agreementChecked');

    await tester.tap(find.text('其他手机号登录'));
    final sheetOpen = await _pollVisible(
      tester,
      find.widgetWithText(TextField, '手机号'),
    );
    if (!sheetOpen) {
      fail('「其他手机号登录」底部弹层未打开');
    }
    await tester.pump(const Duration(seconds: 2));

    // 确保有合法手机号（尊重预填，空则输入）
    final phoneField = find.widgetWithText(TextField, '手机号');
    final prefill = find.descendant(
      of: phoneField,
      matching: find.textContaining(RegExp(r'^1\d{10}$')),
    );
    if (prefill.evaluate().isEmpty) {
      await tester.enterText(phoneField, '13800138000');
      await tester.pump(const Duration(milliseconds: 300));
    }

    if (!agreementChecked) {
      await tester.tap(find.text('发送验证码'));
      final warn = await _waitForToast(
        tester,
        ['请先阅读并同意'],
        timeout: const Duration(seconds: 10),
      );
      debugPrint('DIAG_PATH1_TOAST=『${warn ?? '（未捕获到提示）'}』');
    } else {
      debugPrint('DIAG_PATH1_TOAST=（协议已默认接受，路径1跳过）');
    }

    // ============ 路径 2：勾选协议后点发送，但 8000 无后端 → 连接失败提示 ============
    // 关闭底部弹层
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pump(const Duration(seconds: 1));
    await _acceptAgreement(tester);

    // 重新打开弹层
    await tester.tap(find.text('其他手机号登录'));
    final sheetOpen2 = await _pollVisible(
      tester,
      find.widgetWithText(TextField, '手机号'),
    );
    if (!sheetOpen2) {
      fail('第二次打开底部弹层失败');
    }
    await tester.pump(const Duration(seconds: 2));
    final phoneField2 = find.widgetWithText(TextField, '手机号');
    final prefill2 = find.descendant(
      of: phoneField2,
      matching: find.textContaining(RegExp(r'^1\d{10}$')),
    );
    if (prefill2.evaluate().isEmpty) {
      await tester.enterText(phoneField2, '13800138000');
      await tester.pump(const Duration(milliseconds: 300));
    }

    await tester.tap(find.text('发送验证码'));
    final err = await _waitForToast(
      tester,
      ['发送失败', 'SocketException', '拒绝', '连接', '超时'],
      timeout: const Duration(seconds: 25),
    );
    if (err == null) {
      // 兜底：把当前所有可见文案倒出来辅助定位
      final allTexts = tester
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data)
          .whereType<String>()
          .take(40)
          .toList();
      debugPrint('DIAG_PATH2_VISIBLE_TEXTS=$allTexts');
    }
    debugPrint('DIAG_PATH2_TOAST=『${err ?? '（未捕获到报错文案，见 DIAG_PATH2_VISIBLE_TEXTS）'}』');

    await tester.pump(const Duration(seconds: 1));
  });
}
