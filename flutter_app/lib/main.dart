import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/hot_questions_provider.dart';
import 'providers/launch_consent_provider.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'services/question_service.dart';
import 'services/api_service.dart';

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

// 临时白屏排查探针：print 在鸿蒙上会进 hilog（XComFlutterOHOS_Native 标签）
void _trace(String msg) {
  print('[APPTRACE] $msg');
}

void main() {
  _trace('main: enter');
  // 鸿蒙白屏兜底：显式指定目标平台，绕开 framework defaultTargetPlatform
  // 判断链在 ohos 上的异常。注意：SDK 里该 setter 在非 debug 构建会直接 throw
  // （platform.dart: if (!kDebugMode) throw ...），且 override 本来就只在 debug
  // 生效（_platform_io.dart: if (kDebugMode && ...)），release/profile 靠 SDK
  // 移除 vm:platform-const-if 的修复，因此必须包在 kDebugMode 里。
  // 标准 Flutter SDK（Android/iOS 构建）没有 ohos 枚举值，不能写字面量
  // TargetPlatform.ohos（会 Member not found 编译失败），改为按 name 匹配。
  if (kDebugMode && Platform.operatingSystem == 'ohos') {
    for (final p in TargetPlatform.values) {
      if (p.name == 'ohos') {
        debugDefaultTargetPlatformOverride = p;
        _trace('debugDefaultTargetPlatformOverride=ohos set');
        break;
      }
    }
  }
  // 平台常量折叠排查：打印运行时真实平台值
  _trace('platform: os=${Platform.operatingSystem} android=${Platform.isAndroid} iOS=${Platform.isIOS} win=${Platform.isWindows} isOhos=${Platform.operatingSystem == 'ohos'}');
  FlutterError.onError = (details) {
    _trace('FlutterError.onError: ${details.exception}\n${details.stack}');
    developer.log(
      'Flutter framework error',
      name: 'hospital.app',
      error: details.exception,
      stackTrace: details.stack,
    );
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    _trace('PlatformDispatcher.onError: $error\n$stackTrace');
    developer.log(
      'Uncaught platform error',
      name: 'hospital.app',
      error: error,
      stackTrace: stackTrace,
    );
    return false;
  };

  runZonedGuarded(
    () {
      _trace('zone: before runApp');
      developer.log('Application starting', name: 'hospital.app');
      runApp(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => LaunchConsentProvider()),
            Provider(create: (_) => ApiService()),
            ChangeNotifierProxyProvider<AuthProvider, HotQuestionsProvider>(
              create: (context) => HotQuestionsProvider(
                questionService: QuestionService(
                  authProvider: context.read<AuthProvider>(),
                ),
              ),
              update: (context, authProvider, previous) =>
                  previous ??
                  HotQuestionsProvider(
                    questionService: QuestionService(
                      authProvider: authProvider,
                    ),
                  ),
            ),
          ],
          child: const MyApp(),
        ),
      );
      _trace('zone: after runApp returned');
    },
    (error, stackTrace) {
      _trace('zone error: $error\n$stackTrace');
      developer.log(
        'Uncaught zoned error',
        name: 'hospital.app',
        error: error,
        stackTrace: stackTrace,
      );
    },
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  GoRouter? _router;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_router != null) {
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final launchConsentProvider = context.read<LaunchConsentProvider>();
    _trace('didChangeDependencies: creating router');
    developer.log(
      'Creating application router',
      name: 'hospital.app',
      error: {
        'isAuthenticated': authProvider.isAuthenticated,
        'hasAcceptedLaunchConsent': launchConsentProvider.hasAccepted,
      },
    );
    _router = createRouter(authProvider, launchConsentProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, LaunchConsentProvider>(
      builder: (context, authProvider, launchConsentProvider, child) {
        _trace(
            'build: authLoading=${authProvider.isLoading} consentLoading=${launchConsentProvider.isLoading} authed=${authProvider.isAuthenticated}');
        developer.log(
          'MyApp rebuild',
          name: 'hospital.app',
          error: {
            'authLoading': authProvider.isLoading,
            'launchConsentLoading': launchConsentProvider.isLoading,
            'isAuthenticated': authProvider.isAuthenticated,
            'hasAcceptedLaunchConsent': launchConsentProvider.hasAccepted,
            'hasCurrentUser': authProvider.currentUser != null,
          },
        );
        return MaterialApp.router(
          title: '三十天时刻智护',
          theme: AppTheme.light(),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
          scrollBehavior: const AppScrollBehavior(),
          routerConfig: _router!,
          builder: (context, child) {
            if (!authProvider.isLoading && !launchConsentProvider.isLoading) {
              return child ?? const SizedBox.shrink();
            }

            return Stack(
              fit: StackFit.expand,
              children: [
                child ?? const SizedBox.shrink(),
                const ColoredBox(
                  color: AppTheme.pageBackgroundBottom,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
