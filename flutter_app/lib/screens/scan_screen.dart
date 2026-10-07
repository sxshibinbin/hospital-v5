import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';

const _qrScannerChannel = MethodChannel('hospital/qr_scanner');

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    autoStart: false,
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final ApiService _apiService = ApiService();
  bool _handlingScan = false;
  bool _isHarmony = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _isHarmony = !Platform.isAndroid &&
        !Platform.isIOS &&
        !Platform.isMacOS &&
        !Platform.isWindows &&
        !Platform.isLinux;
    if (!_isHarmony) {
      _scannerController.start();
    }
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _scanOnHarmony() async {
    if (_handlingScan) return;
    setState(() {
      _handlingScan = true;
      _errorMessage = null;
    });
    try {
      final value = await _qrScannerChannel.invokeMethod<String>('scan');
      if (value != null && value.isNotEmpty) {
        await _handleRawValue(value);
      }
    } on PlatformException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message ?? '无法打开扫码功能');
      }
    } finally {
      if (mounted) setState(() => _handlingScan = false);
    }
  }

  Future<void> _handleCapture(BarcodeCapture capture) async {
    if (_handlingScan) return;
    final rawValue = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .whereType<String>()
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    if (rawValue.isEmpty) return;
    await _handleRawValue(rawValue);
  }

  Future<void> _handleRawValue(String rawValue) async {
    final uri = Uri.tryParse(rawValue.trim());
    if (uri == null ||
        uri.scheme != 'hospital' ||
        uri.host != 'pc-login' ||
        uri.queryParameters['v'] != '1') {
      if (mounted) setState(() => _errorMessage = '不是本系统的登录二维码');
      return;
    }
    final sessionId = uri.queryParameters['sid'];
    final qrToken = uri.queryParameters['qt'];
    if (sessionId == null || qrToken == null || sessionId.isEmpty || qrToken.isEmpty) {
      if (mounted) setState(() => _errorMessage = '二维码内容不完整');
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final appToken = authProvider.token;
    setState(() => _handlingScan = true);
    if (!_isHarmony) await _scannerController.stop();
    if (appToken == null || appToken.isEmpty) {
      if (mounted) {
        setState(() {
          _handlingScan = false;
          _errorMessage = '请先登录 App';
        });
      }
      return;
    }
    try {
      final scanResult = await _apiService.scanQrLogin(
        token: appToken,
        sessionId: sessionId,
        qrToken: qrToken,
      );
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('确认登录 PC 端'),
          content: Text(
            '确认后将使用当前 App 账号登录${scanResult.terminalName}。\n\n'
            '二维码将在 ${_formatExpiry(scanResult.confirmExpiresAt)} 前有效。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确认登录'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await _apiService.confirmQrLogin(
          token: appToken,
          sessionId: sessionId,
          qrToken: qrToken,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('登录成功，请返回 PC 端查看')),
          );
          Navigator.of(context).pop();
        }
      } else {
        await _apiService.rejectQrLogin(
          token: appToken,
          sessionId: sessionId,
          qrToken: qrToken,
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = ApiService.extractErrorMessage(error, fallback: '二维码已失效或网络异常'));
      }
    } finally {
      if (mounted) setState(() => _handlingScan = false);
    }
  }

  String _formatExpiry(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return '60 秒内';
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('扫一扫')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _isHarmony
                  ? _buildHarmonyScanner(theme)
                  : MobileScanner(
                      controller: _scannerController,
                      onDetect: _handleCapture,
                    ),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: theme.colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                '将二维码放入取景框内，确认信息无误后再点击确认登录',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHarmonyScanner(ThemeData theme) {
    return Center(
      child: FilledButton.icon(
        onPressed: _handlingScan ? null : _scanOnHarmony,
        icon: const Icon(Icons.qr_code_scanner),
        label: Text(_handlingScan ? '正在打开扫码…' : '打开相机扫码'),
      ),
    );
  }
}
