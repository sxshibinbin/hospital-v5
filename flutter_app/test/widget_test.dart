import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/main.dart';
import 'package:flutter_app/providers/auth_provider.dart';
import 'package:flutter_app/providers/hot_questions_provider.dart';
import 'package:flutter_app/providers/launch_consent_provider.dart';
import 'package:flutter_app/services/question_service.dart';

void main() {
  testWidgets('未登录时显示登录页', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'launch_consent_accepted': true});

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => LaunchConsentProvider()),
          ChangeNotifierProxyProvider<AuthProvider, HotQuestionsProvider>(
            create: (context) => HotQuestionsProvider(
              questionService: QuestionService(
                authProvider: context.read<AuthProvider>(),
              ),
            ),
            update: (context, authProvider, previous) =>
                previous ??
                HotQuestionsProvider(
                  questionService: QuestionService(authProvider: authProvider),
                ),
          ),
        ],
        child: const MyApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Hi，我是时小安'), findsOneWidget);
    expect(find.text('本机号码一键登录'), findsOneWidget);
    expect(find.text('其他手机号登录'), findsOneWidget);

    await tester.ensureVisible(find.text('其他手机号登录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('其他手机号登录'));
    await tester.pumpAndSettle();

    expect(find.text('手机号'), findsOneWidget);
    expect(find.text('验证码'), findsOneWidget);
    expect(find.text('发送验证码'), findsOneWidget);
  });
}
