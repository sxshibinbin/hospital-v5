import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../theme/app_theme.dart';

const userAgreementUrl = 'https://web.sstkjgf.com/user-agreement.html';
const privacyPolicyUrl = 'https://web.sstkjgf.com/privacy-policy.html';

Future<void> showPolicyWebViewDialog(
  BuildContext context, {
  required String title,
  required String url,
}) async {
  if (!context.mounted) {
    return;
  }

  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _PolicyWebViewDialog(title: title, url: url),
  );
}

class _PolicyWebViewDialog extends StatefulWidget {
  const _PolicyWebViewDialog({required this.title, required this.url});

  final String title;
  final String url;

  @override
  State<_PolicyWebViewDialog> createState() => _PolicyWebViewDialogState();
}

class _PolicyWebViewDialogState extends State<_PolicyWebViewDialog> {
  late final WebViewController _controller;

  bool _isLoading = true;
  bool _hasLoadError = false;

  @override
  void initState() {
    super.initState();
    if (_isHarmony) {
      return;
    }
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) {
              return;
            }
            setState(() {
              _isLoading = true;
              _hasLoadError = false;
            });
          },
          onPageFinished: (_) async {
            await _controller.runJavaScript(_disableHorizontalScrollScript);
            if (!mounted) {
              return;
            }
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (_) {
            if (!mounted) {
              return;
            }
            setState(() {
              _isLoading = false;
              _hasLoadError = true;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _reload() async {
    setState(() {
      _isLoading = true;
      _hasLoadError = false;
    });
    await _controller.loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final availableHeight =
        mediaQuery.size.height - mediaQuery.padding.vertical - 88;
    final dialogHeight = availableHeight.clamp(360.0, 620.0).toDouble();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 40),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 356, maxHeight: dialogHeight),
        child: Column(
          children: [
            SizedBox(
              height: 56,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 56),
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF172133),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 6,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      tooltip: '关闭',
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.outlineColor),
            Expanded(
              child: _isHarmony
                  ? const _HarmonyPolicyDocument()
                  : Stack(
                fit: StackFit.expand,
                children: [
                  WebViewWidget(controller: _controller),
                  if (_isLoading)
                    const ColoredBox(
                      color: Colors.white,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (_hasLoadError)
                    ColoredBox(
                      color: Colors.white,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.cloud_off_rounded,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                size: 42,
                              ),
                              const SizedBox(height: 14),
                              Text(
                                '原文加载失败',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '请检查网络后重试',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 18),
                              OutlinedButton.icon(
                                onPressed: _reload,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('重试'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool get _isHarmony {
  final os = Platform.operatingSystem.toLowerCase();
  return os.contains('ohos') || os.contains('harmony');
}

class _HarmonyPolicyDocument extends StatelessWidget {
  const _HarmonyPolicyDocument();

  @override
  Widget build(BuildContext context) {
    final dialog = context.findAncestorStateOfType<_PolicyWebViewDialogState>();
    final url = dialog?.widget.url;
    if (url == null) return const SizedBox.shrink();
    return FutureBuilder<Response<dynamic>>(
      future: Dio().get<dynamic>(url),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data?.data == null) {
          return const Center(child: Text('原文加载失败，请稍后重试'));
        }
        final html = snapshot.data!.data.toString();
        final text = html
            .replaceAll(RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), '')
            .replaceAll(RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), '')
            .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
            .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n\n')
            .replaceAll(RegExp(r'<[^>]+>'), '')
            .replaceAll(RegExp(r'&nbsp;'), ' ')
            .replaceAll(RegExp(r'&amp;'), '&')
            .replaceAll(RegExp(r'\n{3,}'), '\n\n')
            .trim();
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
          child: SelectableText(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
          ),
        );
      },
    );
  }
}

const _disableHorizontalScrollScript = '''
(function () {
  var style = document.getElementById('flutter-policy-dialog-style');
  if (!style) {
    style = document.createElement('style');
    style.id = 'flutter-policy-dialog-style';
    document.head.appendChild(style);
  }
  style.textContent = [
    'html, body { overflow-x: hidden !important; max-width: 100% !important; }',
    '* { box-sizing: border-box !important; max-width: 100% !important; }',
    'body { margin: 0 !important; background: #ffffff !important; }',
    '.page { width: 100% !important; padding: 18px 14px 32px !important; }',
    'p, li, h1, h2, h3, td, th, a { word-break: break-word !important; overflow-wrap: anywhere !important; }',
    '.table-wrap { overflow-x: hidden !important; }',
    'table { width: 100% !important; table-layout: fixed !important; }'
  ].join('\\n');
})();
''';
