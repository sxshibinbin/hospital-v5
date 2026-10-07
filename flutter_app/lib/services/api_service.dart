import 'dart:developer' as developer;
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class CurrentUser {
  const CurrentUser({
    required this.id,
    required this.phone,
    required this.displayName,
    required this.defaultProfileName,
    this.avatarKey,
  });

  factory CurrentUser.fromJson(Map<String, dynamic> json) => CurrentUser(
    id: ((json['id'] ?? (json['user'] is Map ? (json['user'] as Map)['id'] : null)) as num).toInt(),
    phone:
        _extractString(json, 'phone') ??
        _extractString(json, 'phone_number') ??
        _extractString(json, 'phoneNumber') ??
        _extractString(json, 'mobile') ??
        (json['user'] is Map ? _extractString(Map<String, dynamic>.from(json['user'] as Map), 'phone') : null) ??
        '',
    displayName: _extractString(json, 'display_name') ?? '',
    defaultProfileName: _extractString(json, 'default_profile_name'),
    avatarKey: _extractString(json, 'avatar_key'),
  );

  final int id;
  final String phone;
  final String displayName;
  final String? defaultProfileName;
  final String? avatarKey;

  CurrentUser copyWith({
    String? phone,
    String? displayName,
    String? defaultProfileName,
    String? avatarKey,
  }) {
    return CurrentUser(
      id: id,
      phone: phone ?? this.phone,
      displayName: displayName ?? this.displayName,
      defaultProfileName: defaultProfileName ?? this.defaultProfileName,
      avatarKey: avatarKey ?? this.avatarKey,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'phone': phone,
    'display_name': displayName,
    'default_profile_name': defaultProfileName,
    'avatar_key': avatarKey,
  };
}

class CurrentUserProfilePayload {
  const CurrentUserProfilePayload({required this.displayName, this.avatarKey});

  final String displayName;
  final String? avatarKey;

  Map<String, dynamic> toJson() => {
    'display_name': displayName,
    'avatar_key': avatarKey,
  };
}

class LoginResult {
  const LoginResult({required this.accessToken, required this.tokenType, this.phone});

  factory LoginResult.fromJson(Map<String, dynamic> json) => LoginResult(
    accessToken: _extractString(json, 'access_token') ?? '',
    tokenType: _extractString(json, 'token_type') ?? 'bearer',
    phone: _extractString(json, 'phone') ?? _extractString(json, 'phone_number') ??
        (json['user'] is Map ? _extractString(Map<String, dynamic>.from(json['user'] as Map), 'phone') : null),
  );

  final String accessToken;
  final String tokenType;
  final String? phone;
}

class SendCodeResult {
  const SendCodeResult({
    required this.message,
    this.code,
    this.debugMode = false,
    this.debugCode,
    this.smsDelivered = true,
  });

  factory SendCodeResult.fromJson(Map<String, dynamic> json) => SendCodeResult(
    message: _extractString(json, 'message') ?? '',
    code: _extractString(json, 'code'),
    debugMode: json['debug_mode'] == true,
    debugCode: _extractString(json, 'debug_code'),
    smsDelivered: json['sms_delivered'] != false,
  );

  final String message;
  final String? code;
  final bool debugMode;
  final String? debugCode;
  final bool smsDelivered;
}

class QrLoginScanResult {
  const QrLoginScanResult({
    required this.status,
    required this.sessionId,
    required this.terminalName,
    required this.scannedAt,
    required this.confirmExpiresAt,
  });

  factory QrLoginScanResult.fromJson(Map<String, dynamic> json) =>
      QrLoginScanResult(
        status: _extractString(json, 'status') ?? '',
        sessionId: _extractString(json, 'session_id') ?? '',
        terminalName: _extractString(json, 'terminal_name') ?? 'PC 网页端',
        scannedAt: _extractString(json, 'scanned_at') ?? '',
        confirmExpiresAt: _extractString(json, 'confirm_expires_at') ?? '',
      );

  final String status;
  final String sessionId;
  final String terminalName;
  final String scannedAt;
  final String confirmExpiresAt;
}

class HealthProfile {
  const HealthProfile({
    required this.id,
    required this.name,
    required this.relation,
    required this.gender,
    required this.age,
    required this.medicalHistory,
    required this.allergies,
  });

  factory HealthProfile.fromJson(Map<String, dynamic> json) => HealthProfile(
    id: (json['id'] as num).toInt(),
    name: _extractString(json, 'name') ?? '',
    relation: _extractString(json, 'relation') ?? '',
    gender: _extractString(json, 'gender') ?? '',
    age: (json['age'] as num?)?.toInt() ?? 0,
    medicalHistory: _extractString(json, 'medical_history'),
    allergies: _extractString(json, 'allergies'),
  );

  final int id;
  final String name;
  final String relation;
  final String gender;
  final int age;
  final String? medicalHistory;
  final String? allergies;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'relation': relation,
    'gender': gender,
    'age': age,
    'medical_history': medicalHistory,
    'allergies': allergies,
  };
}

class HealthProfilePayload {
  const HealthProfilePayload({
    required this.name,
    required this.relation,
    required this.gender,
    required this.age,
    this.medicalHistory,
    this.allergies,
  });

  final String name;
  final String relation;
  final String gender;
  final int age;
  final String? medicalHistory;
  final String? allergies;

  Map<String, dynamic> toJson() => {
    'name': name,
    'relation': relation,
    'gender': gender,
    'age': age,
    'medical_history': medicalHistory,
    'allergies': allergies,
  };
}

class ConsultationCardData {
  const ConsultationCardData({
    this.summary,
    this.analysis,
    this.recommendedDepartment,
    this.hospitalSuggestion,
    this.aiLabelMeta,
  });

  factory ConsultationCardData.fromJson(Map<String, dynamic> json) =>
      ConsultationCardData(
        summary: _extractString(json, 'summary'),
        analysis: _extractString(json, 'analysis'),
        recommendedDepartment: _extractString(json, 'recommended_department'),
        hospitalSuggestion: _extractString(json, 'hospital_suggestion'),
        aiLabelMeta: (json['ai_label_meta'] as Map?)?.map(
          (key, value) => MapEntry(key.toString(), value),
        ),
      );

  final String? summary;
  final String? analysis;
  final String? recommendedDepartment;
  final String? hospitalSuggestion;
  final Map<String, dynamic>? aiLabelMeta;

  bool get hasContent =>
      _hasText(summary) ||
      _hasText(analysis) ||
      _hasText(recommendedDepartment) ||
      _hasText(hospitalSuggestion);

  Map<String, dynamic> toJson() => {
    'summary': summary,
    'analysis': analysis,
    'recommended_department': recommendedDepartment,
    'hospital_suggestion': hospitalSuggestion,
    'ai_label_meta': aiLabelMeta,
  };
}

class SavedConsultationRecord {
  const SavedConsultationRecord({
    required this.id,
    required this.profileId,
    required this.profileName,
    required this.relation,
    required this.createdAt,
    this.summary,
    this.analysis,
    this.recommendedDepartment,
    this.hospitalSuggestion,
  });

  factory SavedConsultationRecord.fromJson(Map<String, dynamic> json) =>
      SavedConsultationRecord(
        id: (json['id'] as num).toInt(),
        profileId: (json['profile_id'] as num).toInt(),
        profileName: _extractString(json, 'profile_name') ?? '',
        relation: _extractString(json, 'relation') ?? '',
        createdAt:
            DateTime.tryParse(_extractString(json, 'created_at') ?? '') ??
            DateTime.now(),
        summary: _extractString(json, 'summary'),
        analysis: _extractString(json, 'analysis'),
        recommendedDepartment: _extractString(json, 'recommended_department'),
        hospitalSuggestion: _extractString(json, 'hospital_suggestion'),
      );

  final int id;
  final int profileId;
  final String profileName;
  final String relation;
  final DateTime createdAt;
  final String? summary;
  final String? analysis;
  final String? recommendedDepartment;
  final String? hospitalSuggestion;

  Map<String, dynamic> toJson() => {
    'id': id,
    'profile_id': profileId,
    'profile_name': profileName,
    'relation': relation,
    'created_at': createdAt.toIso8601String(),
    'summary': summary,
    'analysis': analysis,
    'recommended_department': recommendedDepartment,
    'hospital_suggestion': hospitalSuggestion,
  };
}

class ConsultationChatTurn {
  const ConsultationChatTurn({required this.role, required this.content});

  final String role;
  final String content;

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

class ChatAttachmentUploadResult {
  const ChatAttachmentUploadResult({
    required this.fileId,
    required this.fileName,
    required this.contentType,
    required this.size,
  });

  factory ChatAttachmentUploadResult.fromJson(Map<String, dynamic> json) =>
      ChatAttachmentUploadResult(
        fileId: _extractString(json, 'file_id') ?? '',
        fileName: _extractString(json, 'file_name') ?? '',
        contentType: _extractString(json, 'content_type') ?? '',
        size: (json['size'] as num?)?.toInt() ?? 0,
      );

  final String fileId;
  final String fileName;
  final String contentType;
  final int size;
}

class ChatAttachmentUploadRequest {
  const ChatAttachmentUploadRequest({
    required this.fileName,
    required this.bytes,
  });

  final String fileName;
  final Uint8List bytes;
}

class ChatSessionAttachmentPayload {
  const ChatSessionAttachmentPayload({
    required this.fileId,
    required this.name,
    this.contentType,
    this.size = 0,
  });

  factory ChatSessionAttachmentPayload.fromJson(Map<String, dynamic> json) =>
      ChatSessionAttachmentPayload(
        fileId: _extractString(json, 'fileId') ?? '',
        name: _extractString(json, 'name') ?? '',
        contentType: _extractString(json, 'contentType'),
        size: (json['size'] as num?)?.toInt() ?? 0,
      );

  final String fileId;
  final String name;
  final String? contentType;
  final int size;

  Map<String, dynamic> toJson() => {
    'fileId': fileId,
    'name': name,
    'contentType': contentType,
    'size': size,
  };
}

class ChatSessionMessagePayload {
  const ChatSessionMessagePayload({
    required this.id,
    required this.role,
    required this.content,
    this.reasoning,
    this.status = 'success',
    this.contextFileIds,
    this.attachments,
    this.aiLabelMeta,
  });

  factory ChatSessionMessagePayload.fromJson(Map<String, dynamic> json) =>
      ChatSessionMessagePayload(
        id: _extractString(json, 'id') ?? '',
        role: _extractString(json, 'role') ?? 'user',
        content: _extractString(json, 'content') ?? '',
        reasoning: _extractString(json, 'reasoning'),
        status: _extractString(json, 'status') ?? 'success',
        contextFileIds: (json['contextFileIds'] as List<dynamic>?)
            ?.map((item) => item.toString())
            .toList(),
        attachments: (json['attachments'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map(ChatSessionAttachmentPayload.fromJson)
            .toList(),
        aiLabelMeta: (json['aiLabelMeta'] as Map?)?.map(
          (key, value) => MapEntry(key.toString(), value),
        ),
      );

  final String id;
  final String role;
  final String content;
  final String? reasoning;
  final String status;
  final List<String>? contextFileIds;
  final List<ChatSessionAttachmentPayload>? attachments;
  final Map<String, dynamic>? aiLabelMeta;

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role,
    'content': content,
    'reasoning': reasoning,
    'status': status,
    'contextFileIds': contextFileIds ?? const <String>[],
    'attachments':
        attachments?.map((item) => item.toJson()).toList() ?? const [],
    'aiLabelMeta': aiLabelMeta,
  };
}

class ChatSessionSummary {
  const ChatSessionSummary({
    required this.id,
    required this.title,
    required this.mode,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessage,
  });

  factory ChatSessionSummary.fromJson(Map<String, dynamic> json) =>
      ChatSessionSummary(
        id: (json['id'] as num).toInt(),
        title: _extractString(json, 'title') ?? '',
        mode: _extractString(json, 'mode') ?? 'normal',
        createdAt:
            DateTime.tryParse(_extractString(json, 'created_at') ?? '') ??
            DateTime.now(),
        updatedAt:
            DateTime.tryParse(_extractString(json, 'updated_at') ?? '') ??
            DateTime.now(),
        lastMessage: _extractString(json, 'last_message'),
      );

  final int id;
  final String title;
  final String mode;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastMessage;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'mode': mode,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'last_message': lastMessage,
  };
}

class ChatSessionDetail extends ChatSessionSummary {
  const ChatSessionDetail({
    required super.id,
    required super.title,
    required super.mode,
    required super.createdAt,
    required super.updatedAt,
    super.lastMessage,
    required this.messages,
  });

  factory ChatSessionDetail.fromJson(Map<String, dynamic> json) =>
      ChatSessionDetail(
        id: (json['id'] as num).toInt(),
        title: _extractString(json, 'title') ?? '',
        mode: _extractString(json, 'mode') ?? 'normal',
        createdAt:
            DateTime.tryParse(_extractString(json, 'created_at') ?? '') ??
            DateTime.now(),
        updatedAt:
            DateTime.tryParse(_extractString(json, 'updated_at') ?? '') ??
            DateTime.now(),
        lastMessage: _extractString(json, 'last_message'),
        messages: (json['messages'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(ChatSessionMessagePayload.fromJson)
            .toList(),
      );

  final List<ChatSessionMessagePayload> messages;
}

const String _defaultApiBaseUrl = 'https://web.sstkjgf.com';

/// 打包（Release）默认后端地址；Debug 仍走本机 localhost:8000，方便本地联调。
const String _releaseApiBaseUrl = 'https://web.sstkjgf.com';

String resolveApiBaseUrl() {
  const configuredUrl = String.fromEnvironment('API_BASE_URL');
  if (configuredUrl.isNotEmpty) {
    return configuredUrl.trim().replaceFirst(RegExp(r'/+$'), '');
  }

  if (kReleaseMode) {
    return _releaseApiBaseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
  }

  return _defaultApiBaseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

String? _extractString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) return value;
  return value.toString();
}

class ApiService {
  ApiService({Dio? dio, String? baseUrl})
    : _baseUrl = baseUrl ?? resolveApiBaseUrl(),
      _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl ?? resolveApiBaseUrl(),
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
              sendTimeout: const Duration(seconds: 30),
              responseType: ResponseType.json,
              headers: {Headers.acceptHeader: Headers.jsonContentType},
            ),
          ) {
    if (_dio.interceptors.every(
      (interceptor) => interceptor is! _ApiLoggingInterceptor,
    )) {
      _dio.interceptors.add(_ApiLoggingInterceptor());
    }
    developer.log(
      'ApiService initialized',
      name: 'hospital.api',
      error: {
        'baseUrl': _baseUrl,
        'platform': defaultTargetPlatform.name,
        'isWeb': kIsWeb,
      },
    );
  }

  final String _baseUrl;
  final Dio _dio;

  Dio get dio => _dio;
  String get baseUrl => _baseUrl;

  String get chatEndpoint => '$_baseUrl/api/chat';

  Future<List<ChatAttachmentUploadResult>> uploadChatAttachments({
    required List<ChatAttachmentUploadRequest> files,
    String? token,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    if (files.isEmpty) {
      return const <ChatAttachmentUploadResult>[];
    }
    final formData = FormData.fromMap({
      'files': files
          .map(
            (file) =>
                MultipartFile.fromBytes(file.bytes, filename: file.fileName),
          )
          .toList(growable: false),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/chat/uploads',
      data: formData,
      onSendProgress: onSendProgress,
      options: Options(
        headers: {
          if (token != null && token.trim().isNotEmpty) ..._authHeaders(token),
          Headers.acceptHeader: Headers.jsonContentType,
        },
      ),
    );

    final uploadedFiles =
        (response.data?['files'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ChatAttachmentUploadResult.fromJson)
            .toList(growable: false);

    if (uploadedFiles.isEmpty) {
      throw Exception('上传成功但未返回文件标识');
    }

    return uploadedFiles;
  }

  Future<ChatAttachmentUploadResult> uploadChatAttachment({
    required String fileName,
    required Uint8List bytes,
    String? token,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    final results = await uploadChatAttachments(
      files: [ChatAttachmentUploadRequest(fileName: fileName, bytes: bytes)],
      token: token,
      onSendProgress: onSendProgress,
    );
    return results.first;
  }

  Future<LoginResult> login({
    required String phone,
    required String password,
  }) async {
    final requestBody = _encodeFormBody({
      'username': phone,
      'password': password,
      'grant_type': 'password',
      'scope': '',
      'client_id': '',
      'client_secret': '',
    });
    developer.log(
      'Login request started',
      name: 'hospital.api.auth',
      error: {
        'path': '/api/auth/login',
        'baseUrl': _baseUrl,
        'phoneLength': phone.length,
        'contentType': Headers.formUrlEncodedContentType,
        'bodyFieldNames': const [
          'username',
          'password',
          'grant_type',
          'scope',
          'client_id',
          'client_secret',
        ],
      },
    );
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/auth/login',
      data: requestBody,
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {
          Headers.acceptHeader: Headers.jsonContentType,
          ..._clientHeaders(),
        },
      ),
    );
    developer.log(
      'Login request completed',
      name: 'hospital.api.auth',
      error: {
        'statusCode': response.statusCode,
        'tokenType': response.data?['token_type'],
        'hasAccessToken':
            (response.data?['access_token'] as String?)?.isNotEmpty ?? false,
      },
    );
    return LoginResult.fromJson(response.data ?? const {});
  }

  Future<SendCodeResult> sendSmsCode({required String phone}) async {
    developer.log(
      'Send sms code request started',
      name: 'hospital.api.auth',
      error: {
        'path': '/api/auth/send_code',
        'baseUrl': _baseUrl,
        'phoneLength': phone.length,
      },
    );
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/auth/send_code',
      data: {'phone': phone},
      options: Options(
        contentType: Headers.jsonContentType,
        headers: {
          Headers.acceptHeader: Headers.jsonContentType,
          ..._clientHeaders(),
        },
      ),
    );
    developer.log(
      'Send sms code request completed',
      name: 'hospital.api.auth',
      error: {
        'statusCode': response.statusCode,
        'hasCode': (response.data?['code'] as String?)?.isNotEmpty ?? false,
      },
    );
    return SendCodeResult.fromJson(response.data ?? const {});
  }

  Future<LoginResult> loginWithSms({
    required String phone,
    required String code,
  }) async {
    developer.log(
      'Sms login request started',
      name: 'hospital.api.auth',
      error: {
        'path': '/api/auth/login/sms',
        'baseUrl': _baseUrl,
        'phoneLength': phone.length,
        'codeLength': code.length,
      },
    );
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/auth/login/sms',
      data: {'phone': phone, 'code': code},
      options: Options(
        contentType: Headers.jsonContentType,
        headers: {
          Headers.acceptHeader: Headers.jsonContentType,
          ..._clientHeaders(),
        },
      ),
    );
    developer.log(
      'Sms login request completed',
      name: 'hospital.api.auth',
      error: {
        'statusCode': response.statusCode,
        'tokenType': response.data?['token_type'],
        'hasAccessToken':
            (response.data?['access_token'] as String?)?.isNotEmpty ?? false,
      },
    );
    return LoginResult.fromJson(response.data ?? const {});
  }

  Future<LoginResult> loginWithCarrierToken(String carrierToken) async {
    developer.log(
      'Carrier login request started',
      name: 'hospital.api.auth',
      error: {
        'path': '/api/auth/login/carrier',
        'baseUrl': _baseUrl,
        'tokenLength': carrierToken.length,
      },
    );
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/auth/login/carrier',
      data: {'carrier_token': carrierToken},
      options: Options(
        contentType: Headers.jsonContentType,
        headers: {
          Headers.acceptHeader: Headers.jsonContentType,
          ..._clientHeaders(),
        },
      ),
    );
    developer.log(
      'Carrier login request completed',
      name: 'hospital.api.auth',
      error: {
        'statusCode': response.statusCode,
        'tokenType': response.data?['token_type'],
        'hasAccessToken':
            (response.data?['access_token'] as String?)?.isNotEmpty ?? false,
      },
    );
    return LoginResult.fromJson(response.data ?? const {});
  }

  Future<void> logout(String token) async {
    await _dio.post<void>(
      '/api/auth/logout',
      options: Options(headers: _authHeaders(token)),
    );
  }

  Future<QrLoginScanResult> scanQrLogin({
    required String token,
    required String sessionId,
    required String qrToken,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/auth/qr/scan',
      data: {'session_id': sessionId, 'qr_token': qrToken},
      options: Options(headers: _authHeaders(token)),
    );
    return QrLoginScanResult.fromJson(response.data ?? const {});
  }

  Future<void> confirmQrLogin({
    required String token,
    required String sessionId,
    required String qrToken,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      '/api/auth/qr/confirm',
      data: {'session_id': sessionId, 'qr_token': qrToken},
      options: Options(headers: _authHeaders(token)),
    );
  }

  Future<void> rejectQrLogin({
    required String token,
    required String sessionId,
    required String qrToken,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      '/api/auth/qr/reject',
      data: {'session_id': sessionId, 'qr_token': qrToken},
      options: Options(headers: _authHeaders(token)),
    );
  }

  Future<void> deactivateCurrentUser(String token) async {
    await _dio.post<void>(
      '/api/auth/me/deactivate',
      options: Options(headers: _authHeaders(token)),
    );
  }

  Future<CurrentUser> fetchCurrentUser(String token) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/auth/me',
      options: Options(headers: _authHeaders(token)),
    );
    return CurrentUser.fromJson(response.data ?? const {});
  }

  Future<CurrentUser> updateCurrentUserProfile({
    required String token,
    required CurrentUserProfilePayload payload,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/api/auth/me',
      data: payload.toJson(),
      options: Options(
        headers: {
          ..._authHeaders(token),
          Headers.contentTypeHeader: Headers.jsonContentType,
        },
      ),
    );
    return CurrentUser.fromJson(response.data ?? const {});
  }

  Future<List<HealthProfile>> fetchProfiles(String token) async {
    final response = await _dio.get<List<dynamic>>(
      '/api/profiles',
      options: Options(headers: _authHeaders(token)),
    );
    return (response.data ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(HealthProfile.fromJson)
        .toList();
  }

  Future<HealthProfile> createProfile(
    String token,
    HealthProfilePayload payload,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/profiles',
      data: payload.toJson(),
      options: Options(
        headers: {
          ..._authHeaders(token),
          Headers.contentTypeHeader: Headers.jsonContentType,
        },
      ),
    );
    return HealthProfile.fromJson(response.data ?? const {});
  }

  Future<HealthProfile> updateProfile({
    required String token,
    required int profileId,
    required HealthProfilePayload payload,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/api/profiles/$profileId',
      data: payload.toJson(),
      options: Options(
        headers: {
          ..._authHeaders(token),
          Headers.contentTypeHeader: Headers.jsonContentType,
        },
      ),
    );
    return HealthProfile.fromJson(response.data ?? const {});
  }

  Future<void> deleteProfile({
    required String token,
    required int profileId,
  }) async {
    await _dio.delete<void>(
      '/api/profiles/$profileId',
      options: Options(headers: _authHeaders(token)),
    );
  }

  Future<List<ChatSessionSummary>> fetchChatSessions(String token) async {
    final response = await _dio.get<List<dynamic>>(
      '/api/chat-sessions',
      options: Options(headers: _authHeaders(token)),
    );
    return (response.data ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ChatSessionSummary.fromJson)
        .toList();
  }

  Future<ChatSessionDetail> fetchChatSessionDetail(
    String token,
    int sessionId,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/chat-sessions/$sessionId',
      options: Options(headers: _authHeaders(token)),
    );
    return ChatSessionDetail.fromJson(response.data ?? const {});
  }

  Future<ChatSessionSummary> saveChatSession({
    required String token,
    required String mode,
    required List<ChatSessionMessagePayload> messages,
    int? sessionId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/chat-sessions',
      data: {
        'session_id': sessionId,
        'mode': mode,
        'messages': messages.map((item) => item.toJson()).toList(),
      },
      options: Options(
        headers: {
          ..._authHeaders(token),
          Headers.contentTypeHeader: Headers.jsonContentType,
        },
      ),
    );
    return ChatSessionSummary.fromJson(response.data ?? const {});
  }

  Future<void> deleteChatSession(String token, int sessionId) async {
    await _dio.delete<void>(
      '/api/chat-sessions/$sessionId',
      options: Options(headers: _authHeaders(token)),
    );
  }

  Future<void> submitAiFeedback({
    required String token,
    required String content,
    required String question,
    required String aiResponse,
    int? sessionId,
    String? messageId,
  }) async {
    await _dio.post<void>(
      '/api/feedback',
      data: {
        'content': content,
        'question': question,
        'ai_response': aiResponse,
        'session_id': sessionId,
        'message_id': messageId,
      },
      options: Options(headers: {
        ..._authHeaders(token),
        Headers.contentTypeHeader: Headers.jsonContentType,
      }),
    );
  }

  Future<List<SavedConsultationRecord>> fetchConsultationRecords(
    String token,
  ) async {
    final response = await _dio.get<List<dynamic>>(
      '/api/consultations/records',
      options: Options(headers: _authHeaders(token)),
    );
    return (response.data ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(SavedConsultationRecord.fromJson)
        .toList();
  }

  Future<void> deleteConsultationRecord({
    required String token,
    required int recordId,
  }) async {
    await _dio.delete<void>(
      '/api/consultations/records/$recordId',
      options: Options(headers: _authHeaders(token)),
    );
  }

  Future<SavedConsultationRecord> saveConsultationRecord({
    required String token,
    required ConsultationCardData cardData,
    required List<ConsultationChatTurn> chatHistory,
    int? profileId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/consultations/save-card',
      data: {
        'profile_id': profileId,
        'card_data': cardData.toJson(),
        'chat_history': chatHistory.map((item) => item.toJson()).toList(),
      },
      options: Options(
        headers: {
          ..._authHeaders(token),
          Headers.contentTypeHeader: Headers.jsonContentType,
        },
      ),
    );
    return SavedConsultationRecord.fromJson(response.data ?? const {});
  }

  Map<String, String> _authHeaders(String token) => {
    'Authorization': 'Bearer $token',
    'X-Client-Terminal': 'app',
  };

  Map<String, String> _clientHeaders({String terminal = 'app'}) => {
    'X-Client-Terminal': terminal,
  };

  static String extractErrorMessage(Object error, {String? fallback}) {
    if (error is DioException) {
      if (error.type == DioExceptionType.connectionTimeout) {
        return '连接后端超时，请确认应用当前访问的后端地址可连通，且云服务器的 8000 端口已开放。';
      }

      if (error.type == DioExceptionType.receiveTimeout) {
        return '后端响应超时，请稍后重试或检查服务是否正常运行。';
      }

      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final detail = data['detail'];
        if (detail is String && detail.isNotEmpty) {
          return detail;
        }
      }

      if (data is String && data.isNotEmpty) {
        try {
          final decoded = jsonDecode(data);
          if (decoded is Map<String, dynamic>) {
            final detail = decoded['detail'];
            if (detail is String && detail.isNotEmpty) {
              return detail;
            }
          }
        } catch (_) {}
      }

      final statusCode = error.response?.statusCode;
      if (statusCode != null && statusCode >= 500) {
        return fallback ?? '服务器内部错误，请稍后重试';
      }

      if (error.message != null && error.message!.trim().isNotEmpty) {
        return error.message!;
      }
    }

    if (error is Exception) {
      final message = error.toString().replaceFirst('Exception: ', '');
      if (message.trim().isNotEmpty) {
        return message;
      }
    }

    return fallback ?? '请求失败，请稍后重试';
  }

  Future<Map<String, dynamic>> polishChatMessage({
    required String text,
    String? token,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/chat/polish',
      data: {'text': text},
      options: Options(
        headers: {
          if (token != null && token.trim().isNotEmpty) ..._authHeaders(token),
          Headers.acceptHeader: Headers.jsonContentType,
          Headers.contentTypeHeader: Headers.jsonContentType,
        },
      ),
    );
    return response.data!;
  }
}

String _encodeFormBody(Map<String, String> fields) {
  return fields.entries
      .map(
        (entry) =>
            '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
      )
      .join('&');
}

class _ApiLoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    developer.log(
      'HTTP request',
      name: 'hospital.api.http',
      error: {
        'method': options.method,
        'uri': options.uri.toString(),
        'headers': _sanitizeMap(options.headers),
        'queryParameters': _sanitizeValue(options.queryParameters),
        'data': _sanitizeValue(options.data),
      },
    );
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    developer.log(
      'HTTP response',
      name: 'hospital.api.http',
      error: {
        'method': response.requestOptions.method,
        'uri': response.requestOptions.uri.toString(),
        'statusCode': response.statusCode,
        'data': _sanitizeValue(response.data),
      },
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    developer.log(
      'HTTP error',
      name: 'hospital.api.http',
      error: {
        'method': err.requestOptions.method,
        'uri': err.requestOptions.uri.toString(),
        'statusCode': err.response?.statusCode,
        'message': err.message,
        'responseData': _sanitizeValue(err.response?.data),
      },
      stackTrace: err.stackTrace,
    );
    handler.next(err);
  }
}

Map<String, dynamic> _sanitizeMap(Map<dynamic, dynamic> input) {
  return input.map((key, value) {
    final normalizedKey = key.toString();
    return MapEntry(normalizedKey, _sanitizeKeyValue(normalizedKey, value));
  });
}

dynamic _sanitizeValue(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is FormData) {
    return {
      'fields': _sanitizeMap(
        value.fields.fold<Map<String, String>>({}, (acc, field) {
          acc[field.key] = field.value;
          return acc;
        }),
      ),
      'files': value.files
          .map(
            (file) => {
              'field': file.key,
              'filename': file.value.filename,
              'contentType': file.value.contentType?.toString(),
              'length': file.value.length,
            },
          )
          .toList(),
    };
  }
  if (value is Map) {
    return _sanitizeMap(value);
  }
  if (value is List) {
    return value.map(_sanitizeValue).toList();
  }
  if (value is String) {
    return value.length > 1200
        ? '${value.substring(0, 1200)}...(truncated)'
        : value;
  }
  return value.toString();
}

dynamic _sanitizeKeyValue(String key, dynamic value) {
  final normalizedKey = key.toLowerCase();
  if (normalizedKey.contains('authorization') ||
      normalizedKey.contains('token') ||
      normalizedKey.contains('password')) {
    return '<redacted>';
  }
  return _sanitizeValue(value);
}
