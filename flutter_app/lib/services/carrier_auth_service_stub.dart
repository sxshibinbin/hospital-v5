class CarrierAuthService {
  static bool get isHarmonyOS => false;

  static bool get isNativeSdkSupported => false;

  static void listen({
    required bool type,
    required Future<void> Function(dynamic event) onEvent,
    required void Function(Object? error) onError,
  }) {}

  static Future<Map<String, dynamic>> initSdk({
    required String androidSk,
    required String iosSk,
    required String harmonySk,
    required String? carrierName,
    required bool isDebug,
  }) async {
    return <String, dynamic>{'code': '500000'};
  }

  static Future<String?> getCurrentCarrierName() async => null;

  static Future<void> login({required int timeout}) async {}

  static Future<void> hideLoading() async {}

  static Future<void> quitPage() async {}

  static Future<void> dispose() async {}
}
