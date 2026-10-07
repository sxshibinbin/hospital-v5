import 'dart:developer' as developer;
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/app_storage_service.dart';
import '../services/carrier_auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/privacy_formatter.dart';
import '../widgets/app_logo.dart';
import '../widgets/app_message.dart';
import '../widgets/policy_webview_dialog.dart';

const _aliyunNumberAuthAndroidSk = String.fromEnvironment(
  'ALIYUN_NUMBER_AUTH_ANDROID_SK',
);
const _aliyunNumberAuthIosSk = String.fromEnvironment(
  'ALIYUN_NUMBER_AUTH_IOS_SK',
);
// 鸿蒙(ohos)预留：平台接线合入前仅占位，保持三端密钥键名约定一致
// ignore: unused_element, unused_field
const _aliyunNumberAuthHarmonySk = String.fromEnvironment(
  'ALIYUN_NUMBER_AUTH_HARMONY_SK',
);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AppStorageService _storageService = AppStorageService.instance;
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _phoneFocusNode = FocusNode();
  final _codeFocusNode = FocusNode();
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isSendingCodeNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int> _resendSecondsNotifier = ValueNotifier<int>(0);

  bool _isLoading = false;
  bool _isSendingCode = false;
  bool _hasAcceptedAgreement = false;
  bool _isInitializingCarrierAuth = false;
  bool _isCarrierAuthAvailable = false;
  bool _isCarrierLoginInProgress = false;
  bool _isCompletingCarrierLogin = false;
  int _resendSeconds = 0;
  String? _detectedPhone;
  String? _carrierName;
  String? _carrierAuthUnavailableDetail;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_restoreRecentPhone());
    unawaited(_initializeCarrierAuth());
  }

  Future<void> _restoreRecentPhone() async {
    var recentPhone =
        (await _storageService.readRecentLoginPhone())?.trim() ?? '';
    if (recentPhone.isEmpty) {
      final currentUser = await _storageService.readCurrentUser();
      recentPhone = currentUser?.phone.trim() ?? '';
      if (recentPhone.isNotEmpty) {
        await _storageService.writeRecentLoginPhone(recentPhone);
      }
    }
    developer.log(
      'Restore recent phone completed',
      name: 'hospital.login_screen',
      error: {'hasRecentPhone': recentPhone.isNotEmpty},
    );
    if (!mounted || recentPhone.isEmpty) {
      return;
    }

    setState(() {
      _detectedPhone = recentPhone;
      _phoneController.text = recentPhone;
    });
  }

  bool _isValidPhone(String phone) => RegExp(r'^1\d{10}$').hasMatch(phone);

  void _syncIsLoading(bool value) {
    _isLoading = value;
    _isLoadingNotifier.value = value;
  }

  void _syncIsSendingCode(bool value) {
    _isSendingCode = value;
    _isSendingCodeNotifier.value = value;
  }

  void _syncResendSeconds(int value) {
    _resendSeconds = value;
    _resendSecondsNotifier.value = value;
  }

  Future<void> _persistRecentPhone(String phone) async {
    // Carrier-auth backends may return either the full number or an already
    // masked value (for example, 138****1234). Keep either form so the next
    // login page can still show the number after a successful carrier login.
    final normalized = phone.trim();
    if (normalized.replaceAll(RegExp(r'\D'), '').length < 7) {
      return;
    }

    await _storageService.writeRecentLoginPhone(normalized);
  }

  void _showSuccessMessage(String message) {
    AppMessage.showSuccess(context, message);
  }

  void _showWarningMessage(String message) {
    AppMessage.showWarning(context, message);
  }

  void _showErrorMessage(String message) {
    AppMessage.showError(context, message);
  }

  Future<void> _showPolicy({required String title, required String url}) {
    return showPolicyWebViewDialog(context, title: title, url: url);
  }

  bool get _canUseCarrierAuth {
    if (kIsWeb || !CarrierAuthService.isNativeSdkSupported) {
      return false;
    }

    if (CarrierAuthService.isHarmonyOS) {
      return _aliyunNumberAuthHarmonySk.isNotEmpty;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _aliyunNumberAuthAndroidSk.isNotEmpty;
      case TargetPlatform.iOS:
        return _aliyunNumberAuthIosSk.isNotEmpty;
      default:
        return false;
    }
  }

  String get _carrierStatusText {
    if (_carrierName != null && _carrierName!.trim().isNotEmpty) {
      return '$_carrierName提供认证服务';
    }

    if (_isCarrierAuthAvailable) {
      return '已就绪，可使用运营商本机号码授权登录';
    }

    if (!CarrierAuthService.isNativeSdkSupported) {
      return '当前版本暂未接入运营商一键登录，请使用手机号验证码登录';
    }

    if (_canUseCarrierAuth) {
      return '正在准备运营商认证能力';
    }

    return '当前环境未配置运营商一键登录，仍可使用短信验证码登录';
  }

  Future<void> _initializeCarrierAuth() async {
    if (!_canUseCarrierAuth || _isInitializingCarrierAuth) {
      return;
    }

    setState(() {
      _isInitializingCarrierAuth = true;
      _carrierAuthUnavailableDetail = null;
    });

    try {
      CarrierAuthService.listen(
        type: true,
        onEvent: _handleCarrierAuthEvent,
        onError: _handleCarrierAuthError,
      );

      final result = await CarrierAuthService.initSdk(
        androidSk: _aliyunNumberAuthAndroidSk,
        iosSk: _aliyunNumberAuthIosSk,
        harmonySk: _aliyunNumberAuthHarmonySk,
        carrierName: _carrierName,
        isDebug: kDebugMode,
      );
      developer.log(
        'Carrier auth initialized',
        name: 'hospital.login_screen',
        error: {'result': result},
      );

      final code = result['code']?.toString();
      final isAvailable =
          code != '500000' && code != '500001' && code != '500005';

      String? carrierName;
      if (isAvailable) {
        try {
          carrierName = await CarrierAuthService.getCurrentCarrierName();
        } catch (error, stackTrace) {
          developer.log(
            'Reading carrier name failed',
            name: 'hospital.login_screen',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _isCarrierAuthAvailable = isAvailable;
        _carrierName = carrierName;
        if (isAvailable) {
          _carrierAuthUnavailableDetail = null;
        }
      });
    } catch (error, stackTrace) {
      developer.log(
        'Carrier auth initialization failed',
        name: 'hospital.login_screen',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isCarrierAuthAvailable = false;
        _carrierAuthUnavailableDetail = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isInitializingCarrierAuth = false;
        });
      }
    }
  }

  Future<bool> _handleLogin() async {
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();
    developer.log(
      'Login button pressed',
      name: 'hospital.login_screen',
      error: {
        'phoneLength': phone.length,
        'codeLength': code.length,
        'mounted': mounted,
      },
    );

    if (!_hasAcceptedAgreement) {
      _showWarningMessage('请先阅读并同意用户协议与隐私政策');
      return false;
    }

    if (phone.isEmpty || code.isEmpty) {
      developer.log(
        'Login blocked because phone or code is empty',
        name: 'hospital.login_screen',
      );
      _showWarningMessage('请输入手机号和验证码');
      return false;
    }

    if (!_isValidPhone(phone)) {
      _showWarningMessage('请输入正确的 11 位手机号');
      return false;
    }

    setState(() {
      _syncIsLoading(true);
    });

    var loginSucceeded = false;
    try {
      final authProvider = context.read<AuthProvider>();
      developer.log(
        'Calling AuthProvider.loginWithSms',
        name: 'hospital.login_screen',
        error: {'isLoading': _isLoading, 'hasAuthProvider': true},
      );
      await authProvider.loginWithSms(phone, code);
      await _persistRecentPhone(phone);
      loginSucceeded = true;
      developer.log(
        'AuthProvider.loginWithSms completed',
        name: 'hospital.login_screen',
        error: {
          'isAuthenticated': authProvider.isAuthenticated,
          'hasCurrentUser': authProvider.currentUser != null,
          'mounted': mounted,
        },
      );
    } catch (error, stackTrace) {
      developer.log(
        'Login action failed in screen',
        name: 'hospital.login_screen',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        developer.log(
          'Showing login failure message',
          name: 'hospital.login_screen',
        );
        _showErrorMessage(
          '登录失败：${ApiService.extractErrorMessage(error, fallback: '请稍后重试')}',
        );
      }
    } finally {
      if (mounted) {
        developer.log(
          'Resetting login loading state',
          name: 'hospital.login_screen',
        );
        setState(() {
          _isLoading = false;
        });
      }
    }

    return loginSucceeded;
  }

  Future<void> _handleQuickLogin() async {
    // 一键登录不在首页拦截协议勾选：运营商授权页内自带协议复选框与校验，
    // 收集手机号前的同意动作在授权页完成，首页复选框仅用于短信登录路径。
    developer.log(
      'Quick login button pressed',
      name: 'hospital.login_screen',
      error: {
        'carrierAvailable': _isCarrierAuthAvailable,
        'carrierConfigured': _canUseCarrierAuth,
      },
    );

    if (!_canUseCarrierAuth || !_isCarrierAuthAvailable) {
      final detail = _carrierAuthUnavailableDetail;
      _showWarningMessage(
        detail == null || detail.isEmpty
            ? '当前环境暂不可用运营商一键登录，请改用其他手机号登录'
            : '当前环境暂不可用运营商一键登录：$detail',
      );
      await _openCustomPhoneSheet();
      return;
    }

    setState(() {
      _isCarrierLoginInProgress = true;
    });

    try {
      await CarrierAuthService.login(timeout: 5000);
    } catch (error, stackTrace) {
      developer.log(
        'Carrier login invocation failed',
        name: 'hospital.login_screen',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isCarrierLoginInProgress = false;
      });
      _showErrorMessage('一键登录拉起失败，请改用其他手机号登录');
    }
  }

  Future<void> _handleSendCode() async {
    final phone = _phoneController.text.trim();
    await _sendCode(phone);
  }

  Future<void> _sendCode(String phone) async {
    developer.log(
      'Send code button pressed',
      name: 'hospital.login_screen',
      error: {
        'phoneLength': phone.length,
        'isSendingCode': _isSendingCode,
        'resendSeconds': _resendSeconds,
      },
    );

    if (!_hasAcceptedAgreement) {
      _showWarningMessage('请先阅读并同意用户协议与隐私政策');
      return;
    }

    if (phone.isEmpty) {
      _showWarningMessage('请先输入手机号');
      return;
    }

    if (!_isValidPhone(phone)) {
      _showWarningMessage('请输入正确的 11 位手机号');
      return;
    }

    if (_isSendingCode || _resendSeconds > 0) {
      return;
    }

    setState(() {
      _syncIsSendingCode(true);
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final result = await authProvider.sendSmsCode(phone);
      if (!mounted) {
        return;
      }
      await _persistRecentPhone(phone);
      if (!mounted) {
        return;
      }
      _startResendCountdown();
      setState(() {
        _detectedPhone = phone;
      });
      final debugCodes = <String>[
        if (result.debugCode != null && result.debugCode!.isNotEmpty)
          result.debugCode!,
        if (result.code != null && result.code!.isNotEmpty) result.code!,
      ];
      if (result.debugMode || !result.smsDelivered) {
        final message = result.debugMode
            ? (kDebugMode && debugCodes.isNotEmpty
                  ? '后端短信调试模式已开启，未真实发送短信。开发环境验证码：${debugCodes.join(' 或 ')}'
                  : '后端短信调试模式已开启，未真实发送短信，请检查服务器短信配置')
            : '短信未真实发送，请检查服务器短信配置';
        _showWarningMessage(message);
        return;
      }
      _showSuccessMessage('验证码已发送到 ${maskPhoneNumber(phone)}');
    } catch (error, stackTrace) {
      developer.log(
        'Send code failed in screen',
        name: 'hospital.login_screen',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) {
        return;
      }
      _showErrorMessage(
        '发送失败：${ApiService.extractErrorMessage(error, fallback: '请稍后重试')}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _syncIsSendingCode(false);
        });
      }
    }
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() {
      _syncResendSeconds(60);
    });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _resendSeconds <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _syncResendSeconds(0);
          });
        }
        return;
      }
      setState(() {
        _syncResendSeconds(_resendSeconds - 1);
      });
    });
  }

  void _handleCarrierAuthError(Object? error) {
    developer.log(
      'Carrier auth event stream failed',
      name: 'hospital.login_screen',
      error: error,
    );
  }

  Future<void> _handleCarrierAuthEvent(dynamic event) async {
    developer.log(
      'Carrier auth event received',
      name: 'hospital.login_screen',
      error: {'event': event},
    );

    if (event is! Map) {
      return;
    }

    final code = event['code']?.toString();
    if (code == null) {
      return;
    }
    final wasCarrierLoginInProgress = _isCarrierLoginInProgress;
    final message = event['msg']?.toString().trim();

    // 鸿蒙 SDK 的 700002 是「点击登录按钮」（700003 才是勾选协议），
    // 未勾选时由 SDK 原生 toast 校验提示；Android 端 700002 则是
    // 「协议未勾选点击」，SDK 同样自行提示。两端均静默透传。
    const ignoredCodes = <String>{
      '500004',
      '600001',
      '600012',
      '600016',
      '600024',
      '700002',
      '700003',
      '700004',
      '700006',
      '700007',
      '700008',
      '700009',
    };
    if (ignoredCodes.contains(code)) {
      return;
    }

    if (code == '600000') {
      final token = event['data']?.toString() ?? '';
      if (token.isEmpty) {
        if (mounted) {
          setState(() {
            _isCarrierLoginInProgress = false;
          });
        }
        return;
      }

      // 先关闭鸿蒙原生授权页，再调用后端登录。否则原生页可能继续盖在
      // Flutter 页面上，造成“后端已登录但界面没有跳转”的现象。
      unawaited(_completeCarrierLogin(token));
      return;
    }

    if (code == '700000' || code == '700001' || code == '700020') {
      if (mounted) {
        setState(() {
          _isCarrierLoginInProgress = false;
        });
      }
      return;
    }

    if (code == '500005' ||
        code == '600002' ||
        code == '600004' ||
        code == '600005' ||
        code == '600007' ||
        code == '600008' ||
        code == '600009' ||
        code == '600010' ||
        code == '600011' ||
        code == '600013' ||
        code == '600015' ||
        code == '600017' ||
        code == '600018' ||
        code == '600021' ||
        code == '600023' ||
        code == '600025' ||
        code == '600026') {
      if (!mounted) {
        return;
      }
      setState(() {
        _isCarrierLoginInProgress = false;
        _isCarrierAuthAvailable = false;
        _carrierAuthUnavailableDetail = message == null || message.isEmpty
            ? 'SDK 返回 code=$code'
            : 'SDK 返回 code=$code，$message';
      });
      if (!wasCarrierLoginInProgress) {
        return;
      }
      final detail = message == null || message.isEmpty
          ? 'SDK 返回 code=$code'
          : 'SDK 返回 code=$code，$message';
      _showErrorMessage('一键登录失败：$detail');
    }
  }

  Future<void> _completeCarrierLogin(String carrierToken) async {
    if (!mounted || _isCompletingCarrierLogin) {
      return;
    }

    _isCompletingCarrierLogin = true;
    setState(() {
      _syncIsLoading(true);
      _isCarrierLoginInProgress = false;
    });

    // 鸿蒙 SDK 取号成功后不会自动关闭授权页（与 Android 不同），需要这里
    // 显式调用 quitPage。插件已切换为 dialog 模式承载授权页，quitLoginPage
    // 只关闭弹窗，不会再把宿主 UIAbility 一起终止（否则登录成功后整个应用
    // 会被收回桌面）。
    String? failureMessage;
    var loginSucceeded = false;
    try {
      final authProvider = context.read<AuthProvider>();
      await authProvider.loginWithCarrierToken(carrierToken);
      loginSucceeded = true;
      final loggedInPhone = authProvider.currentUser?.phone;
      if (loggedInPhone != null && loggedInPhone.isNotEmpty) {
        await _persistRecentPhone(loggedInPhone);
        if (mounted) {
          setState(() {
            _detectedPhone = loggedInPhone;
          });
        }
      }
    } catch (error, stackTrace) {
      developer.log(
        'Carrier login completion failed',
        name: 'hospital.login_screen',
        error: error,
        stackTrace: stackTrace,
      );
      failureMessage =
          '一键登录失败：${ApiService.extractErrorMessage(error, fallback: '请稍后重试')}';
    } finally {
      await _closeCarrierAuthPage();

      if (mounted) {
        setState(() {
          _syncIsLoading(false);
        });
      }
      _isCompletingCarrierLogin = false;
    }

    if (failureMessage != null && mounted) {
      _showErrorMessage(failureMessage);
      return;
    }

    if (loginSucceeded && mounted) {
      // AuthProvider 会触发 GoRouter 刷新，但这里显式导航，保证真机上
      // 原生授权页关闭后一定进入聊天页。
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (mounted) {
        context.go('/chat');
      }
    }
  }

  Future<void> _closeCarrierAuthPage() async {
    try {
      await CarrierAuthService.quitPage().timeout(
        const Duration(milliseconds: 800),
      );
    } catch (_) {}
    // Let the native dialog close animation settle before switching routes.
    await Future<void>.delayed(const Duration(milliseconds: 120));
  }

  Future<void> _openCustomPhoneSheet() async {
    setState(() {
      _codeController.clear();
      _phoneController.text = _detectedPhone ?? _phoneController.text;
    });

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _PhoneLoginBottomSheet(
          phoneController: _phoneController,
          codeController: _codeController,
          phoneFocusNode: _phoneFocusNode,
          codeFocusNode: _codeFocusNode,
          isLoadingListenable: _isLoadingNotifier,
          isSendingCodeListenable: _isSendingCodeNotifier,
          resendSecondsListenable: _resendSecondsNotifier,
          onSendCode: _handleSendCode,
          onLogin: () async {
            final success = await _handleLogin();
            if (success && sheetContext.mounted) {
              await Navigator.maybeOf(sheetContext)?.maybePop();
            }
          },
        );
      },
    );
  }

  Future<void> _handleOtherPhoneLogin() async {
    if (!_hasAcceptedAgreement) {
      _showWarningMessage('请先阅读并同意用户协议与隐私政策');
      return;
    }
    await _openCustomPhoneSheet();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detectedPhone = _detectedPhone;
    final hasDetectedPhone = detectedPhone != null && detectedPhone.isNotEmpty;
    final supportsCarrierAuth = CarrierAuthService.isNativeSdkSupported;
    final canUseDetectedPhone = supportsCarrierAuth && hasDetectedPhone;
    final primaryLoginDisabled =
        _isLoading ||
        _isSendingCode ||
        (supportsCarrierAuth &&
            (_isInitializingCarrierAuth || _isCarrierLoginInProgress));

    return Scaffold(
      backgroundColor: AppTheme.pageBackgroundBottom,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.pageBackgroundTop, AppTheme.pageBackgroundBottom],
          ),
        ),
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                        maxWidth: 480,
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const AppLogo(size: 42),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '三十天时刻智护',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: AppTheme.primaryDarkColor,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () {},
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.72,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.headset_mic_rounded,
                                  color: AppTheme.primaryDarkColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Wrap(
                            spacing: 14,
                            runSpacing: 12,
                            alignment: WrapAlignment.center,
                            children: [
                              _FeatureBubble(label: '健康问题来问我'),
                              _FeatureBubble(
                                label: '检查报告拍给我',
                                alignment: Alignment.centerRight,
                              ),
                              _FeatureBubble(label: '挂号问诊我帮你'),
                              _FeatureBubble(
                                label: '定制健康小目标',
                                alignment: Alignment.centerRight,
                              ),
                            ],
                          ),
                          // const SizedBox(height: 20),
                          SizedBox(
                            height: 78,
                            child: Transform.scale(
                              scale: 0.78,
                              child: const _HeroIllustration(),
                            ),
                          ),
                          // const SizedBox(height: 24),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.94),
                              borderRadius: BorderRadius.circular(32),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x140F0A36),
                                  blurRadius: 36,
                                  offset: Offset(0, 16),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Hi，我是时小安',
                                  style: theme.textTheme.headlineMedium
                                      ?.copyWith(
                                        color: AppTheme.primaryDarkColor,
                                        fontWeight: FontWeight.w800,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '健康是福，健康的事就找时小安～',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: AppTheme.primaryDarkColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 18),
                                if (canUseDetectedPhone) ...[
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        maskPhoneNumber(detectedPhone),
                                        style: theme.textTheme.headlineLarge
                                            ?.copyWith(
                                              color: AppTheme.primaryDarkColor,
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                    ],
                                  ),
                                ] else ...[
                                  Text(
                                    supportsCarrierAuth
                                        ? '暂未识别到本机号码'
                                        : '手机号验证码登录',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      color: AppTheme.primaryDarkColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    supportsCarrierAuth
                                        ? '请改用其他手机号验证码登录'
                                        : '使用手机号和短信验证码完成登录',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Text(
                                  _carrierStatusText,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: primaryLoginDisabled
                                        ? null
                                        : (supportsCarrierAuth
                                              ? _handleQuickLogin
                                              : _handleOtherPhoneLogin),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _isCarrierLoginInProgress
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                              )
                                            : Icon(
                                                supportsCarrierAuth
                                                    ? Icons.smartphone_rounded
                                                    : Icons.sms_rounded,
                                              ),
                                        const SizedBox(width: 8),
                                        Text(
                                          supportsCarrierAuth
                                              ? (_isInitializingCarrierAuth
                                                    ? '正在准备一键登录'
                                                    : '本机号码一键登录')
                                              : '手机号验证码登录',
                                          style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (supportsCarrierAuth) ...[
                                  const SizedBox(height: 12),
                                  TextButton(
                                    onPressed: _handleOtherPhoneLogin,
                                    child: const Text('其他手机号登录'),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 40,
                                      height: 40,
                                      child: Checkbox(
                                        value: _hasAcceptedAgreement,
                                        onChanged: (value) {
                                          setState(() {
                                            _hasAcceptedAgreement =
                                                value ?? false;
                                          });
                                        },
                                        activeColor: AppTheme.primaryColor,
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 9),
                                        child: _AgreementText(
                                          onOpenAgreement: () => _showPolicy(
                                            title: '用户协议',
                                            url: userAgreementUrl,
                                          ),
                                          onOpenPrivacy: () => _showPolicy(
                                            title: '隐私政策',
                                            url: privacyPolicyUrl,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // SizedBox(
                                //   width: double.infinity,
                                //   child: OutlinedButton(
                                //     onPressed: () {
                                //       _showInfoMessage('暂未接入第三方授权登录');
                                //     },
                                //     style: OutlinedButton.styleFrom(
                                //       foregroundColor: const Color(0xFF1677FF),
                                //       side: const BorderSide(
                                //         color: Color(0xFFE7E3F5),
                                //       ),
                                //       padding: const EdgeInsets.symmetric(
                                //         vertical: 14,
                                //       ),
                                //       shape: RoundedRectangleBorder(
                                //         borderRadius: BorderRadius.circular(24),
                                //       ),
                                //     ),
                                //     child: const Row(
                                //       mainAxisAlignment: MainAxisAlignment.center,
                                //       mainAxisSize: MainAxisSize.min,
                                //       children: [
                                //         Icon(Icons.account_balance_wallet_rounded),
                                //         SizedBox(width: 8),
                                //         Text(
                                //           '支付宝',
                                //           style: TextStyle(
                                //             fontWeight: FontWeight.w700,
                                //           ),
                                //         ),
                                //       ],
                                //     ),
                                //   ),
                                // ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _phoneFocusNode.dispose();
    _codeFocusNode.dispose();
    unawaited(CarrierAuthService.dispose());
    _resendTimer?.cancel();
    _isLoadingNotifier.dispose();
    _isSendingCodeNotifier.dispose();
    _resendSecondsNotifier.dispose();
    super.dispose();
  }
}

class _HeroIllustration extends StatelessWidget {
  const _HeroIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: 280,
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.78),
                  const Color(0xFFF6E8F2),
                ],
              ),
            ),
          ),
          Positioned(
            left: 26,
            bottom: 24,
            child: _FloatingOrb(
              size: 52,
              colors: const [Color(0xFFB4E6FF), Color(0xFFE4F7FF)],
              icon: Icons.camera_alt_rounded,
            ),
          ),
          Positioned(
            top: 18,
            left: 88,
            child: _FloatingOrb(
              size: 34,
              colors: const [Color(0xFFE6C8FF), Color(0xFFF5E7FF)],
              icon: Icons.auto_awesome_rounded,
            ),
          ),
          Positioned(
            right: 34,
            bottom: 34,
            child: _FloatingOrb(
              size: 48,
              colors: const [Color(0xFFB8CBFF), Color(0xFFE8EFFF)],
              icon: Icons.health_and_safety_rounded,
            ),
          ),
          Positioned(
            bottom: 0,
            child: Container(
              width: 162,
              height: 182,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(36),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFFFFF), Color(0xFFEDE8FF)],
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1C8077D6),
                    blurRadius: 30,
                    offset: Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF4D6C9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.face_retouching_natural_rounded,
                      size: 44,
                      color: Color(0xFF7A4C35),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: 96,
                    height: 54,
                    decoration: BoxDecoration(
                      color: const Color(0xFF9DD5FF),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.medical_services_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingOrb extends StatelessWidget {
  const _FloatingOrb({
    required this.size,
    required this.colors,
    required this.icon,
  });

  final double size;
  final List<Color> colors;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: colors),
        boxShadow: const [
          BoxShadow(
            color: Color(0x148B7CFF),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Icon(icon, size: size * 0.46, color: Colors.white),
    );
  }
}

class _FeatureBubble extends StatelessWidget {
  const _FeatureBubble({
    required this.label,
    this.alignment = Alignment.centerLeft,
  });

  final String label;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.primaryDarkColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _PhoneLoginBottomSheet extends StatelessWidget {
  const _PhoneLoginBottomSheet({
    required this.phoneController,
    required this.codeController,
    required this.phoneFocusNode,
    required this.codeFocusNode,
    required this.isLoadingListenable,
    required this.isSendingCodeListenable,
    required this.resendSecondsListenable,
    required this.onSendCode,
    required this.onLogin,
  });

  final TextEditingController phoneController;
  final TextEditingController codeController;
  final FocusNode phoneFocusNode;
  final FocusNode codeFocusNode;
  final ValueListenable<bool> isLoadingListenable;
  final ValueListenable<bool> isSendingCodeListenable;
  final ValueListenable<int> resendSecondsListenable;
  final Future<void> Function() onSendCode;
  final Future<void> Function() onLogin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: EdgeInsets.only(
            left: 12,
            right: 12,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
          ),
          child: Material(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(28),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD7D2EA),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '其他手机号登录',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: AppTheme.primaryDarkColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '从下方输入手机号与验证码完成登录，首次登录会自动注册账号',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: phoneController,
                    focusNode: phoneFocusNode,
                    autofocus: true,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(11),
                    ],
                    onSubmitted: (_) => codeFocusNode.requestFocus(),
                    decoration: const InputDecoration(
                      labelText: '手机号',
                      hintText: '请输入 11 位手机号',
                      prefixIcon: Icon(Icons.phone_android_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: codeController,
                          focusNode: codeFocusNode,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          onSubmitted: (_) => onLogin(),
                          decoration: const InputDecoration(
                            labelText: '验证码',
                            hintText: '请输入短信验证码',
                            prefixIcon: Icon(Icons.verified_user_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ValueListenableBuilder<bool>(
                        valueListenable: isSendingCodeListenable,
                        builder: (context, isSendingCode, child) {
                          return ValueListenableBuilder<int>(
                            valueListenable: resendSecondsListenable,
                            builder: (context, resendSeconds, child) {
                              return FilledButton.tonal(
                                onPressed: (isSendingCode || resendSeconds > 0)
                                    ? null
                                    : onSendCode,
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 18,
                                  ),
                                ),
                                child: isSendingCode
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        resendSeconds > 0
                                            ? '${resendSeconds}s'
                                            : '发送验证码',
                                      ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ValueListenableBuilder<bool>(
                      valueListenable: isLoadingListenable,
                      builder: (context, isLoading, child) {
                        return FilledButton(
                          onPressed: isLoading ? null : onLogin,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primaryDarkColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  '确认登录',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AgreementText extends StatelessWidget {
  const _AgreementText({
    required this.onOpenAgreement,
    required this.onOpenPrivacy,
  });

  final VoidCallback onOpenAgreement;
  final VoidCallback onOpenPrivacy;

  @override
  Widget build(BuildContext context) {
    final baseStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      height: 1.45,
    );
    final linkStyle = baseStyle?.copyWith(
      color: AppTheme.primaryDarkColor,
      fontWeight: FontWeight.w700,
    );

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('阅读并同意 ', style: baseStyle),
        InkWell(
          onTap: onOpenAgreement,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Text('《用户协议》', style: linkStyle),
          ),
        ),
        Text(' 和 ', style: baseStyle),
        InkWell(
          onTap: onOpenPrivacy,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Text('《隐私政策》', style: linkStyle),
          ),
        ),
      ],
    );
  }
}
