import 'dart:developer' as developer;
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../providers/launch_consent_provider.dart';
import 'app_route_observer.dart';
import '../screens/account_center_screen.dart';
import '../screens/account_policies_screen.dart';
import '../screens/first_launch_consent_screen.dart';
import '../screens/login_screen.dart';
import '../screens/home_screen.dart';
import '../screens/health_archive_screen.dart';
import '../screens/health_monitoring/alarm_record_screen.dart';
import '../screens/health_monitoring/health_monitoring_screen.dart';
import '../screens/health_monitoring/device_detail_screen.dart';
import '../screens/health_monitoring/device_add_screen.dart';
import '../screens/health_monitoring/metric_detail_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/history_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/scan_screen.dart';

GoRouter createRouter(
  AuthProvider authProvider,
  LaunchConsentProvider launchConsentProvider,
) {
  return GoRouter(
    initialLocation: '/launch-consent',
    refreshListenable: Listenable.merge([authProvider, launchConsentProvider]),
    observers: [appRouteObserver],
    redirect: (context, state) {
      if (authProvider.isLoading || launchConsentProvider.isLoading) {
        developer.log(
          'Router redirect skipped while app state is loading',
          name: 'hospital.router',
          error: {
            'matchedLocation': state.matchedLocation,
            'authLoading': authProvider.isLoading,
            'launchConsentLoading': launchConsentProvider.isLoading,
          },
        );
        return null;
      }

      final hasAcceptedLaunchConsent = launchConsentProvider.hasAccepted;
      final isLoggedIn = authProvider.isAuthenticated;
      final isLaunchConsentRoute = state.matchedLocation == '/launch-consent';
      final isLoginRoute = state.matchedLocation == '/login';
      developer.log(
        'Router redirect evaluated',
        name: 'hospital.router',
        error: {
          'matchedLocation': state.matchedLocation,
          'hasAcceptedLaunchConsent': hasAcceptedLaunchConsent,
          'isLoggedIn': isLoggedIn,
          'isLaunchConsentRoute': isLaunchConsentRoute,
          'isLoginRoute': isLoginRoute,
        },
      );

      if (!hasAcceptedLaunchConsent && !isLaunchConsentRoute) {
        developer.log(
          'Redirecting user to launch consent screen',
          name: 'hospital.router',
        );
        return '/launch-consent';
      }

      if (hasAcceptedLaunchConsent && isLaunchConsentRoute) {
        developer.log(
          'Redirecting accepted launch consent route',
          name: 'hospital.router',
        );
        return isLoggedIn ? '/chat' : '/login';
      }

      if (!isLoggedIn && !isLoginRoute) {
        developer.log(
          'Redirecting unauthenticated user to /login',
          name: 'hospital.router',
        );
        return '/login';
      }

      if (isLoggedIn && isLoginRoute) {
        developer.log(
          'Redirecting authenticated user to /chat',
          name: 'hospital.router',
        );
        return '/chat';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/launch-consent',
        builder: (context, state) => const FirstLaunchConsentScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/scan', builder: (context, state) => const ScanScreen()),
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/account',
        builder: (context, state) => const AccountCenterScreen(),
      ),
      GoRoute(
        path: '/account/edit',
        builder: (context, state) => const EditAccountProfileScreen(),
      ),
      GoRoute(
        path: '/account/settings',
        builder: (context, state) => const AppSettingsScreen(),
      ),
      GoRoute(
        path: '/account/policies',
        builder: (context, state) => const AccountPoliciesScreen(),
      ),
      GoRoute(
        path: '/account/about',
        builder: (context, state) => const AboutAppScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/health-archive',
        builder: (context, state) => const HealthArchiveScreen(),
      ),
      GoRoute(
        path: '/health-monitoring',
        builder: (context, state) => const HealthMonitoringScreen(),
      ),
      GoRoute(
        path: '/alarm-record',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is Map) {
            final recordType = extra['recordType'] == 'eventReport'
                ? AlarmRecordType.eventReport
                : AlarmRecordType.alarm;
            return AlarmRecordScreen(
              deviceImei: extra['deviceImei']?.toString(),
              recordType: recordType,
            );
          }

          return AlarmRecordScreen(deviceImei: extra is String ? extra : null);
        },
      ),
      GoRoute(
        path: '/health-monitoring/device-detail',
        builder: (context, state) {
          final device = state.extra as DeviceData;
          return DeviceDetailScreen(device: device);
        },
      ),
      GoRoute(
        path: '/health-monitoring/add-device',
        builder: (context, state) => const DeviceAddScreen(),
      ),
      GoRoute(
        path: '/health-monitoring/metric-detail',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return MetricDetailScreen(
            deviceId: extra['deviceId'] as int,
            deviceImei: extra['deviceImei'] as String,
            metricName: extra['metricName'] as String,
            metricColor: extra['metricColor'] as Color,
            deviceType: extra['deviceType']?.toString(),
          );
        },
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => const HistoryScreen(),
      ),
      GoRoute(
        path: '/chat',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final rawProfileId = extra?['profileId'];
          final rawSessionId = extra?['sessionId'];
          final initialQuestion = extra?['initialQuestion'] as String?;
          developer.log(
            'Building /chat route',
            name: 'hospital.router',
            error: {
              'hasExtra': extra != null,
              'rawProfileId': rawProfileId,
              'rawSessionId': rawSessionId,
              'hasInitialQuestion':
                  initialQuestion != null && initialQuestion.isNotEmpty,
            },
          );

          final profileId = switch (rawProfileId) {
            int value => value,
            String value => int.tryParse(value),
            _ => null,
          };
          final sessionId = switch (rawSessionId) {
            int value => value,
            String value => int.tryParse(value),
            _ => null,
          };

          return ChatScreen(
            profileId: profileId,
            initialSessionId: sessionId,
            initialQuestion: initialQuestion,
          );
        },
      ),
    ],
  );
}
