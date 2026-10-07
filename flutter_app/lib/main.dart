import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui';

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

void main() {
  FlutterError.onError = (details) {
    developer.log(
      'Flutter framework error',
      name: 'hospital.app',
      error: details.exception,
      stackTrace: details.stack,
    );
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
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
    },
    (error, stackTrace) {
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
