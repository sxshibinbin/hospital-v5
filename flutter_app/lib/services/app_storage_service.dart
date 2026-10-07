import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'harmony_persistence_service.dart';

class AppStorageService {
  AppStorageService._();

  static final AppStorageService instance = AppStorageService._();

  static const _authTokenKey = 'auth_token';
  static const _currentUserKey = 'auth_current_user';
  static const _recentLoginPhoneKey = 'recent_login_phone';
  static const _profilesKey = 'cached_profiles';
  static const _chatSessionsKey = 'cached_chat_sessions';
  static const _consultationRecordsKey = 'cached_consultation_records';
  static const _notificationsEnabledKey = 'settings_notifications_enabled';
  static const _healthReminderEnabledKey = 'settings_health_reminder_enabled';
  static const _privacyModeEnabledKey = 'settings_privacy_mode_enabled';
  static const _launchConsentAcceptedKey = 'launch_consent_accepted';

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static final Map<String, Object> _memoryStore = <String, Object>{};

  SharedPreferences? _cachedPreferences;
  bool _useMemoryStore = false;

  Future<SharedPreferences?> _getPreferences() async {
    if (_useMemoryStore) {
      return null;
    }
    final cached = _cachedPreferences;
    if (cached != null) {
      return cached;
    }
    try {
      // HarmonyOS may take several seconds to initialize the preferences
      // bridge on a cold start. A short timeout permanently forced the app
      // into an in-memory store, making consent and recent phone disappear
      // after every restart.
      final preferences = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 10),
      );
      _cachedPreferences = preferences;
      return preferences;
    } catch (error, stackTrace) {
      _useMemoryStore = true;
      developer.log(
        'SharedPreferences unavailable, using in-memory storage fallback',
        name: 'hospital.storage',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<String?> readAuthToken() async {
    final secureToken = await _readSecureString(_authTokenKey);
    if (secureToken != null && secureToken.isNotEmpty) {
      return secureToken;
    }

    final legacyToken = await _readString(_authTokenKey);
    if (legacyToken != null && legacyToken.isNotEmpty) {
      await writeAuthToken(legacyToken);
      await _remove(_authTokenKey);
    }
    return legacyToken;
  }

  Future<void> writeAuthToken(String token) =>
      _writeSecureString(_authTokenKey, token);

  Future<void> clearAuthToken() async {
    await _deleteSecureString(_authTokenKey);
    await _remove(_authTokenKey);
  }

  Future<CurrentUser?> readCurrentUser() =>
      _readJsonObject(_currentUserKey, CurrentUser.fromJson);

  Future<void> writeCurrentUser(CurrentUser? user) async {
    if (user == null) {
      await _remove(_currentUserKey);
      return;
    }
    await _writeJsonObject(_currentUserKey, user.toJson());
  }

  Future<String?> readRecentLoginPhone() async {
    try {
      final nativeValue = await HarmonyPersistenceService.readString(
        _recentLoginPhoneKey,
      );
      if (nativeValue != null) return nativeValue;
    } catch (_) {}
    return _readString(_recentLoginPhoneKey);
  }

  Future<void> writeRecentLoginPhone(String phone) async {
    try {
      await HarmonyPersistenceService.writeString(_recentLoginPhoneKey, phone);
    } catch (_) {}
    await _writeString(_recentLoginPhoneKey, phone);
  }

  Future<List<HealthProfile>> readProfiles() =>
      _readJsonList(_profilesKey, HealthProfile.fromJson);

  Future<void> writeProfiles(List<HealthProfile> profiles) =>
      _writeJsonList(_profilesKey, profiles.map((item) => item.toJson()));

  Future<List<ChatSessionSummary>> readChatSessions() =>
      _readJsonList(_chatSessionsKey, ChatSessionSummary.fromJson);

  Future<void> writeChatSessions(List<ChatSessionSummary> sessions) =>
      _writeJsonList(_chatSessionsKey, sessions.map((item) => item.toJson()));

  Future<List<SavedConsultationRecord>> readConsultationRecords() =>
      _readJsonList(_consultationRecordsKey, SavedConsultationRecord.fromJson);

  Future<void> writeConsultationRecords(
    List<SavedConsultationRecord> records,
  ) => _writeJsonList(
    _consultationRecordsKey,
    records.map((item) => item.toJson()),
  );

  Future<void> clearUserData() async {
    final preferences = await _getPreferences();
    if (preferences == null) {
      _memoryStore.remove(_authTokenKey);
      _memoryStore.remove(_currentUserKey);
      _memoryStore.remove(_profilesKey);
      _memoryStore.remove(_chatSessionsKey);
      _memoryStore.remove(_consultationRecordsKey);
      return;
    }
    await Future.wait([
      preferences.remove(_authTokenKey),
      preferences.remove(_currentUserKey),
      preferences.remove(_profilesKey),
      preferences.remove(_chatSessionsKey),
      preferences.remove(_consultationRecordsKey),
    ]);
  }

  Future<bool> readNotificationsEnabled() =>
      _readBool(_notificationsEnabledKey, defaultValue: true);

  Future<void> writeNotificationsEnabled(bool value) =>
      _writeBool(_notificationsEnabledKey, value);

  Future<bool> readHealthReminderEnabled() =>
      _readBool(_healthReminderEnabledKey, defaultValue: true);

  Future<void> writeHealthReminderEnabled(bool value) =>
      _writeBool(_healthReminderEnabledKey, value);

  Future<bool> readPrivacyModeEnabled() =>
      _readBool(_privacyModeEnabledKey, defaultValue: false);

  Future<void> writePrivacyModeEnabled(bool value) =>
      _writeBool(_privacyModeEnabledKey, value);

  Future<bool> readLaunchConsentAccepted() async {
    try {
      final nativeValue = await HarmonyPersistenceService.readBool(
        _launchConsentAcceptedKey,
      );
      if (nativeValue != null) return nativeValue;
    } catch (_) {}
    return _readBool(_launchConsentAcceptedKey, defaultValue: false);
  }

  Future<void> writeLaunchConsentAccepted(bool value) async {
    try {
      await HarmonyPersistenceService.writeBool(_launchConsentAcceptedKey, value);
    } catch (_) {}
    await _writeBool(_launchConsentAcceptedKey, value);
  }

  Future<String?> _readString(String key) async {
    final preferences = await _getPreferences();
    if (preferences == null) {
      return _memoryStore[key] as String?;
    }
    return preferences.getString(key);
  }

  Future<void> _writeString(String key, String value) async {
    final preferences = await _getPreferences();
    if (preferences == null) {
      _memoryStore[key] = value;
      return;
    }
    await preferences.setString(key, value);
  }

  Future<void> _remove(String key) async {
    final preferences = await _getPreferences();
    if (preferences == null) {
      _memoryStore.remove(key);
      return;
    }
    await preferences.remove(key);
  }

  Future<String?> _readSecureString(String key) async {
    try {
      return await _secureStorage.read(key: key);
    } catch (error, stackTrace) {
      developer.log(
        'Secure storage read unavailable, using in-memory token fallback',
        name: 'hospital.storage',
        error: error,
        stackTrace: stackTrace,
      );
      return _memoryStore[key] as String?;
    }
  }

  Future<void> _writeSecureString(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
      _memoryStore.remove(key);
    } catch (error, stackTrace) {
      _memoryStore[key] = value;
      developer.log(
        'Secure storage write unavailable, token persisted in memory only',
        name: 'hospital.storage',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _deleteSecureString(String key) async {
    try {
      await _secureStorage.delete(key: key);
    } catch (error, stackTrace) {
      developer.log(
        'Secure storage delete unavailable',
        name: 'hospital.storage',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _memoryStore.remove(key);
    }
  }

  Future<bool> _readBool(String key, {required bool defaultValue}) async {
    final preferences = await _getPreferences();
    if (preferences == null) {
      return _memoryStore[key] as bool? ?? defaultValue;
    }
    return preferences.getBool(key) ?? defaultValue;
  }

  Future<void> _writeBool(String key, bool value) async {
    final preferences = await _getPreferences();
    if (preferences == null) {
      _memoryStore[key] = value;
      return;
    }
    await preferences.setBool(key, value);
  }

  Future<T?> _readJsonObject<T>(
    String key,
    T Function(Map<String, dynamic> json) fromJson,
  ) async {
    final rawValue = await _readString(key);
    if (rawValue == null || rawValue.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(rawValue);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    return fromJson(decoded);
  }

  Future<void> _writeJsonObject(String key, Map<String, dynamic> value) =>
      _writeString(key, jsonEncode(value));

  Future<List<T>> _readJsonList<T>(
    String key,
    T Function(Map<String, dynamic> json) fromJson,
  ) async {
    final rawValue = await _readString(key);
    if (rawValue == null || rawValue.isEmpty) {
      return <T>[];
    }

    final decoded = jsonDecode(rawValue);
    if (decoded is! List<dynamic>) {
      return <T>[];
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(fromJson)
        .toList(growable: false);
  }

  Future<void> _writeJsonList(
    String key,
    Iterable<Map<String, dynamic>> values,
  ) => _writeString(key, jsonEncode(values.toList(growable: false)));
}
