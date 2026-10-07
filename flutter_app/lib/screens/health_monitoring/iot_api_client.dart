import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class IotApiException implements Exception {
  const IotApiException(
    this.message, {
    this.statusCode,
    this.isUnauthorized = false,
  });

  final String message;
  final int? statusCode;
  final bool isUnauthorized;

  @override
  String toString() => message;
}

Future<Map<String, dynamic>> iotGetJson(
  BuildContext context,
  String path, {
  String operation = 'IoT request',
}) {
  return _iotRequestJson(context, 'GET', path, operation: operation);
}

Future<Map<String, dynamic>> iotPostJson(
  BuildContext context,
  String path, {
  required Map<String, dynamic> body,
  String operation = 'IoT request',
}) {
  return _iotRequestJson(
    context,
    'POST',
    path,
    body: body,
    operation: operation,
  );
}

Future<Map<String, dynamic>> _iotRequestJson(
  BuildContext context,
  String method,
  String path, {
  Map<String, dynamic>? body,
  required String operation,
}) async {
  if (!path.startsWith('/api/iot')) {
    throw ArgumentError.value(
      path,
      'path',
      'IoT API path must start with /api/iot',
    );
  }

  final authProvider = context.read<AuthProvider>();
  final token = authProvider.token?.trim();
  final uri = Uri.parse('${resolveApiBaseUrl()}$path');
  final headers = {
    'Accept': 'application/json',
    'X-Client-Terminal': 'app',
    if (method != 'GET') 'Content-Type': 'application/json',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  final response = method == 'GET'
      ? await http.get(uri, headers: headers)
      : await http.post(
          uri,
          headers: headers,
          body: jsonEncode(body ?? const {}),
        );

  final payload = _decodeJsonObject(response.body);
  if (response.statusCode == 401) {
    developer.log(
      'IoT API unauthorized',
      name: 'hospital.iot',
      error: {
        'operation': operation,
        'path': path,
        'statusCode': response.statusCode,
      },
    );
    await authProvider.logout();
    throw const IotApiException(
      '登录状态已失效，请重新登录',
      statusCode: 401,
      isUnauthorized: true,
    );
  }

  if (response.statusCode < 200 || response.statusCode >= 300) {
    final message =
        _extractIotErrorMessage(payload) ?? '接口请求失败(${response.statusCode})';
    developer.log(
      'IoT API request failed',
      name: 'hospital.iot',
      error: {
        'operation': operation,
        'path': path,
        'statusCode': response.statusCode,
        'message': message,
      },
    );
    throw IotApiException(message, statusCode: response.statusCode);
  }

  if (payload == null) {
    throw const IotApiException('接口返回格式异常');
  }
  return payload;
}

Map<String, dynamic>? _decodeJsonObject(String body) {
  if (body.trim().isEmpty) {
    return null;
  }
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
  } catch (_) {
    return null;
  }
  return null;
}

String? _extractIotErrorMessage(Map<String, dynamic>? payload) {
  if (payload == null) {
    return null;
  }
  final message =
      _messageText(payload['message']) ?? _messageText(payload['detail']);
  if (message != null && message.isNotEmpty) {
    return message;
  }
  return null;
}

String? _messageText(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is String) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }
  if (value is Map) {
    final nested =
        value['msg'] ?? value['message'] ?? value['detail'] ?? value['data'];
    final text = _messageText(nested);
    if (text != null) {
      return text;
    }
    return value.values.map(_messageText).whereType<String>().join('; ');
  }
  if (value is List) {
    final parts = value.map(_messageText).whereType<String>().toList();
    return parts.isEmpty ? null : parts.join('; ');
  }
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}
