import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';

class WebviewPage extends StatefulWidget {
  final String? profileId;
  final String? initialQuestion;

  const WebviewPage({
    super.key,
    this.profileId,
    this.initialQuestion,
  });

  @override
  State<WebviewPage> createState() => _WebviewPageState();
}

class _WebviewPageState extends State<WebviewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;

  bool _isAllowedWebViewUri(Uri uri) {
    const configuredHosts = String.fromEnvironment('ADMIN_FRONT_TRUSTED_HOSTS');
    final trustedHosts = configuredHosts
        .split(',')
        .map((item) => item.trim().toLowerCase())
        .where((item) => item.isNotEmpty)
        .toSet();
    trustedHosts.add('web.sstkjgf.com');

    final host = uri.host.toLowerCase();
    if (uri.scheme == 'https' && trustedHosts.contains(host)) {
      return true;
    }

    if (kDebugMode &&
        uri.scheme == 'http' &&
        {'localhost', '127.0.0.1', '10.0.2.2'}.contains(host)) {
      return true;
    }

    return false;
  }

  @override
  void initState() {
    super.initState();
    
    String initialUrl = 'https://web.sstkjgf.com/chat';
    const configuredUrl = String.fromEnvironment('ADMIN_FRONT_CHAT_URL');
    if (configuredUrl.isNotEmpty) {
      initialUrl = configuredUrl;
    } else if (kDebugMode) {
      if (Platform.isAndroid) {
        initialUrl = 'http://10.0.2.2:5173/chat';
      } else {
        initialUrl = 'http://127.0.0.1:5173/chat';
      }
    }

    // Append profileId and initialQuestion as query parameters if they exist
    final uri = Uri.parse(initialUrl);
    final queryParams = <String, String>{};
    if (widget.profileId != null) queryParams['profileId'] = widget.profileId!;
    if (widget.initialQuestion != null) queryParams['initialQuestion'] = widget.initialQuestion!;
    
    final finalUrl = queryParams.isNotEmpty 
        ? uri.replace(queryParameters: queryParams).toString() 
        : initialUrl;
    final finalUri = Uri.parse(finalUrl);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: (JavaScriptMessage message) {
          try {
            final data = jsonDecode(message.message);
            final action = data['action'];
            
            if (action == 'back') {
              Navigator.of(context).pop();
            } else if (action == 'consultationEnd') {
              final cardData = data['data'];
              _showConsultationResult(cardData);
            } else if (action == 'saveConsultation') {
              // 接收 Web 端保存卡片请求
              final cardData = data['data'];
              _saveConsultationRecord(cardData);
            }
          } catch (e) {
            debugPrint('Error parsing JSBridge message: $e');
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            final requestedUri = Uri.tryParse(request.url);
            if (requestedUri == null || !_isAllowedWebViewUri(requestedUri)) {
              debugPrint('Blocked untrusted WebView navigation: ${request.url}');
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onPageFinished: (String url) {
            // Inject token from AuthProvider
            final token = context.read<AuthProvider>().token ?? '';
            final encodedToken = jsonEncode(token);
            final encodedProfileId = jsonEncode(widget.profileId ?? '');
            _controller.runJavaScript(
              'if (window.injectAuthData) { window.injectAuthData($encodedToken, $encodedProfileId); }',
            );
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView Error: ${error.description}');
          },
        ),
      )
      ..loadRequest(finalUri);
  }

  void _saveConsultationRecord(Map<String, dynamic>? data) {
    // 模拟保存问诊记录
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('问诊记录保存成功！')),
    );
  }

  void _showConsultationResult(Map<String, dynamic> cardData) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('问诊结束'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('推荐科室：${cardData['recommended_department'] ?? '未知'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text('就医建议：${cardData['hospital_suggestion'] ?? '无'}'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Close WebView
              },
              child: const Text('退出问诊'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6), // Match React's background color
      body: SafeArea(
        bottom: false, // Let the WebView extend to the bottom edge
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading)
              const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}
