import 'dart:io' show Platform;

import 'package:ali_auth/ali_auth.dart';
import 'package:flutter/foundation.dart';

class CarrierAuthService {
  static bool get isHarmonyOS {
    final operatingSystem = Platform.operatingSystem.toLowerCase();
    return operatingSystem.contains('ohos') ||
        operatingSystem.contains('openharmony') ||
        operatingSystem.contains('harmony');
  }

  static bool get isNativeSdkSupported =>
      Platform.isAndroid || Platform.isIOS || isHarmonyOS;

  static void listen({
    required bool type,
    required Future<void> Function(dynamic event) onEvent,
    required void Function(Object? error) onError,
  }) {
    AliAuth.loginListen(type: type, onEvent: onEvent, onError: onError);
  }

  /// 按运营商返回对应的一键登录认证服务条款（名称 + URL）
  static Map<String, String>? _vendorPrivacyClause(String? carrierName) {
    final name = (carrierName ?? '').trim().toLowerCase();
    if (name.contains('电信') ||
        name.contains('天翼') ||
        name.contains('telecom') ||
        name.contains('ctcc') ||
        name.contains('189')) {
      return {
        'name': '《天翼账号认证服务条款》',
        'url': 'https://e.189.cn/sdk/agreement/detail.do?hidetop=true',
      };
    }
    if (name.contains('移动') ||
        name.contains('cmcc') ||
        name.contains('mobile') ||
        name.contains('10086')) {
      return {
        'name': '《中国移动认证服务条款》',
        'url': 'http://wap.cmpassport.com/resources/html/contract1.html',
      };
    }
    if (name.contains('联通') ||
        name.contains('unicom') ||
        name.contains('cucc') ||
        name.contains('10010')) {
      return {
        'name': '《中国联通免密登录协议》',
        'url':
            'https://img.client.10010.com/stprototype/clientonekeylogin/onekeyloginyinsi.html',
      };
    }
    return null;
  }

  static Future<Map<String, dynamic>> initSdk({
    required String androidSk,
    required String iosSk,
    required String harmonySk,
    required String? carrierName,
    required bool isDebug,
  }) async {
    // initSdk 调用点传入的 carrierName 可能为空（此前在 initSdk 之后才查询），
    // 这里兜底查询一次，确保三方运营商条款能按当前 SIM 卡正确注入
    var effectiveCarrierName = carrierName?.trim();
    if (effectiveCarrierName == null || effectiveCarrierName.isEmpty) {
      try {
        effectiveCarrierName = await AliAuth.getCurrentCarrierName();
      } catch (_) {
        effectiveCarrierName = null;
      }
    }
    final vendorClause = _vendorPrivacyClause(effectiveCarrierName);

    final result = await AliAuth.initSdk(
      AliAuthModel(
        androidSk,
        iosSk,
        harmonySk: harmonySk,
        pageType: PageType.fullPort,
        isDebug: isDebug,
        // isDelay: true 表示 initSdk 只做预取号，不自动拉起授权页；
        // 授权页由用户点击“一键登录”按钮时通过 login() 手动拉起。
        isDelay: true,
        // 显示导航栏并保留返回按钮，用户可从授权页返回登录页
        navHidden: false,
        navColor: '#F8F3FF',
        navText: '本机号码一键登录',
        navTextColor: '#2F266F',
        navReturnImgPath: 'assets/auth/icon_nav_back.png',
        logoHidden: true,
        switchAccHidden: true,
        // AGC 审核要求：手机号属敏感个人信息，授权页必须展示协议复选框，
        // 由用户主动勾选同意后才能发起取号，不得默认勾选或隐藏复选框。
        checkboxHidden: false,
        privacyState: false,
        // 自定义复选框图片（Flutter assets，带边框配色，避免浅色底上不可见）
        uncheckedImgPath: 'assets/auth/icon_checkbox_unchecked.png',
        checkedImgPath: 'assets/auth/icon_checkbox_checked.png',
        lightColor: true,
        statusBarColor: '#F8F3FF',
        // 协议详情页（SDK 内置 WebView）导航栏配色，保证协议页有返回按钮可退出
        webNavColor: '#F8F3FF',
        webNavTextColor: '#2F266F',
        bottomNavColor: '#FFFFFF',
        numberColor: '#2F266F',
        sloganText: effectiveCarrierName?.isNotEmpty == true
            ? '$effectiveCarrierName提供认证服务'
            : '运营商提供认证服务',
        sloganTextColor: '#8F88AE',
        logBtnText: '本机号码一键登录',
        logBtnTextColor: '#FFFFFF',
        logBtnMarginLeftAndRight: 28,
        logBtnHeight: 52,
        privacyTextSize: 12,
        privacyMargin: 24,
        privacyBefore: '我已阅读并同意',
        privacyEnd: '并授权获取本机号码',
        protocolOneName: '《用户协议》',
        protocolOneURL: 'https://web.sstkjgf.com/user-agreement.html',
        protocolTwoName: '《隐私政策》',
        protocolTwoURL: 'https://web.sstkjgf.com/privacy-policy.html',
        // 第三方运营商认证服务条款（按当前 SIM 卡运营商动态设置）
        protocolThreeName: vendorClause?['name'],
        protocolThreeURL: vendorClause?['url'],
        // 运营商条款排序：3 = 排在自定义条款之后
        privacyOperatorIndex: 3,
        vendorPrivacyPrefix: '《',
        vendorPrivacySuffix: '》',
        autoHideLoginLoading: true,
      ),
    );

    if (result is Map<String, dynamic>) {
      return result;
    }

    if (result is Map) {
      return result.map<String, dynamic>(
        (key, value) => MapEntry(key.toString(), value),
      );
    }

    return <String, dynamic>{'code': '500000'};
  }

  static Future<String?> getCurrentCarrierName() =>
      AliAuth.getCurrentCarrierName();

  static Future<void> login({required int timeout}) =>
      AliAuth.login(timeout: timeout);

  static Future<void> hideLoading() => AliAuth.hideLoading();

  static Future<void> quitPage() => AliAuth.quitPage();

  static Future<void> dispose() async {
    if (!kIsWeb && isNativeSdkSupported) {
      AliAuth.dispose();
    }
  }
}
