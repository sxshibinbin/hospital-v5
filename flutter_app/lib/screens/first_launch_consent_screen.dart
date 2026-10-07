import 'dart:io' show exit;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/launch_consent_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_message.dart';
import '../widgets/policy_webview_dialog.dart';

class FirstLaunchConsentScreen extends StatefulWidget {
  const FirstLaunchConsentScreen({super.key});

  @override
  State<FirstLaunchConsentScreen> createState() =>
      _FirstLaunchConsentScreenState();
}

class _FirstLaunchConsentScreenState extends State<FirstLaunchConsentScreen> {
  bool _isAccepting = false;

  Future<void> _handleAccept() async {
    if (_isAccepting) {
      return;
    }

    setState(() {
      _isAccepting = true;
    });

    try {
      await context.read<LaunchConsentProvider>().accept();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isAccepting = false;
      });
      AppMessage.showError(context, '保存同意状态失败，请稍后重试');
      return;
    }

    if (!mounted) {
      return;
    }
    context.go('/login');
  }

  Future<void> _showPolicy({required String title, required String url}) async {
    await showPolicyWebViewDialog(context, title: title, url: url);
  }

  void _handleReject() {
    // 工信部合规要求：用户不同意隐私政策时必须退出应用。
    // SystemNavigator.pop() 在部分设备上只是切到后台，exit(0) 才是真正退出进程。
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    final isCompactHeight = mediaSize.height < 720;
    final logoSize = isCompactHeight ? 140.0 : 176.0;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.pageBackgroundBottom,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.pageBackgroundTop,
                Colors.white,
                AppTheme.pageBackgroundBottom,
              ],
              stops: [0, 0.48, 1],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                28,
                isCompactHeight ? 12 : 20,
                28,
                26,
              ),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/images/logo.webp',
                            width: logoSize,
                            height: logoSize,
                            fit: BoxFit.contain,
                          ),
                          SizedBox(height: isCompactHeight ? 22 : 30),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '三十天时刻智护',
                              maxLines: 1,
                              style: Theme.of(context).textTheme.displaySmall
                                  ?.copyWith(
                                    color: AppTheme.primaryDarkColor,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isAccepting ? null : _handleAccept,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(58),
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: _isAccepting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              '同意并开始使用',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _handleReject,
                    child: const Text(
                      '不同意以下条款',
                      style: TextStyle(color: Color(0xFF747188)),
                    ),
                  ),
                  SizedBox(height: isCompactHeight ? 28 : 54),
                  _LaunchPolicyNotice(
                    onOpenAgreement: () =>
                        _showPolicy(title: '用户协议', url: userAgreementUrl),
                    onOpenPrivacy: () =>
                        _showPolicy(title: '隐私政策', url: privacyPolicyUrl),
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

class _LaunchPolicyNotice extends StatelessWidget {
  const _LaunchPolicyNotice({
    required this.onOpenAgreement,
    required this.onOpenPrivacy,
  });

  final VoidCallback onOpenAgreement;
  final VoidCallback onOpenPrivacy;

  @override
  Widget build(BuildContext context) {
    final noticeStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: const Color(0xFF8F93A3),
      height: 1.65,
    );

    return DefaultTextStyle.merge(
      style: noticeStyle,
      textAlign: TextAlign.center,
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('请在使用前仔细阅读了解 '),
              _InlinePolicyLink(label: '用户协议', onTap: onOpenAgreement),
              const Text(' 和 '),
              _InlinePolicyLink(label: '隐私政策', onTap: onOpenPrivacy),
              const Text('。'),
            ],
          ),
          const Text(
            '为实现信息分享、统计分析等目的所必须，我们可能会调用剪贴板并使用与功能相关的最小必要信息（口令、链接、统计参数等）。',
          ),
        ],
      ),
    );
  }
}

class _InlinePolicyLink extends StatelessWidget {
  const _InlinePolicyLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.primaryDarkColor,
            fontWeight: FontWeight.w800,
            height: 1.65,
          ),
        ),
      ),
    );
  }
}
