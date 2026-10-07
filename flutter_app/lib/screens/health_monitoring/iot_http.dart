import 'package:http/http.dart' as http;

import '../../services/app_storage_service.dart';

/// 健康监测模块 iot 接口统一请求封装。
///
/// 云后端（web.sstkjgf.com）的 /api/iot/* 要求 Bearer 登录态；
/// 历史代码为裸 http 调用，在云环境全部 401，表现为页面静默显示空数据
/// （本地旧版后端无鉴权，因此开发期未暴露）。
Future<Map<String, String>> _iotHeaders() async {
  final token = await AppStorageService.instance.readAuthToken();
  return {
    'Content-Type': 'application/json',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
  };
}

/// POST /api/iot/*
Future<http.Response> iotPost(Uri url, {Object? body}) async {
  return http.post(url, headers: await _iotHeaders(), body: body);
}

/// GET /api/iot/*
Future<http.Response> iotGet(Uri url) async {
  return http.get(url, headers: await _iotHeaders());
}
