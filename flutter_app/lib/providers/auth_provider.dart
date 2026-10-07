import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../services/api_service.dart';
import '../services/app_storage_service.dart';

class AuthProvider with ChangeNotifier {
  AuthProvider({ApiService? apiService})
    : _apiService = apiService ?? ApiService() {
    _initialize();
  }

  final ApiService _apiService;
  final AppStorageService _storageService = AppStorageService.instance;

  String? _token;
  CurrentUser? _currentUser;
  bool _isLoading = true;

  String? get token => _token;
  CurrentUser? get currentUser => _currentUser;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;
  bool get isLoading => _isLoading;

  Future<void> _initialize() async {
    developer.log('AuthProvider initialization started', name: 'hospital.auth');
    _token = await _storageService.readAuthToken();
    _currentUser = await _storageService.readCurrentUser();
    developer.log(
      'Stored token loaded',
      name: 'hospital.auth',
      error: {
        'hasToken': isAuthenticated,
        'tokenLength': _token?.length ?? 0,
        'hasCachedCurrentUser': _currentUser != null,
      },
    );
    _isLoading = false;
    developer.log(
      'AuthProvider initialization completed',
      name: 'hospital.auth',
      error: {
        'isAuthenticated': isAuthenticated,
        'hasCurrentUser': _currentUser != null,
      },
    );
    notifyListeners();
    if (isAuthenticated) {
      unawaited(_refreshCurrentUser(notify: true));
    }
  }

  Future<void> login(String username, String password) async {
    developer.log(
      'Login flow started',
      name: 'hospital.auth',
      error: {
        'usernameLength': username.length,
        'passwordLength': password.length,
      },
    );
    try {
      final loginResult = await _apiService.login(
        phone: username,
        password: password,
      );
      developer.log(
        'Login API returned successfully',
        name: 'hospital.auth',
        error: {
          'tokenType': loginResult.tokenType,
          'accessTokenLength': loginResult.accessToken.length,
        },
      );
      _token = loginResult.accessToken;
      await _storageService.writeAuthToken(_token!);
      final carrierPhone = loginResult.phone?.trim() ?? '';
      if (carrierPhone.replaceAll(RegExp(r'\D'), '').length >= 7) {
        await _storageService.writeRecentLoginPhone(carrierPhone);
      }
      developer.log(
        'Token saved to local storage',
        name: 'hospital.auth',
        error: {'tokenLength': _token!.length},
      );
      await _refreshCurrentUser(notify: false);
      developer.log(
        'Login flow completed',
        name: 'hospital.auth',
        error: {
          'hasCurrentUser': _currentUser != null,
          'isAuthenticated': isAuthenticated,
        },
      );
      notifyListeners();
    } catch (error, stackTrace) {
      developer.log(
        'Login flow failed',
        name: 'hospital.auth',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<SendCodeResult> sendSmsCode(String phone) async {
    developer.log(
      'Send sms code flow started',
      name: 'hospital.auth',
      error: {'phoneLength': phone.length},
    );
    try {
      final result = await _apiService.sendSmsCode(phone: phone);
      developer.log(
        'Send sms code flow completed',
        name: 'hospital.auth',
        error: {
          'message': result.message,
          'hasCode': result.code != null && result.code!.isNotEmpty,
        },
      );
      return result;
    } catch (error, stackTrace) {
      developer.log(
        'Send sms code flow failed',
        name: 'hospital.auth',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> loginWithSms(String phone, String code) async {
    developer.log(
      'Sms login flow started',
      name: 'hospital.auth',
      error: {'phoneLength': phone.length, 'codeLength': code.length},
    );
    try {
      final loginResult = await _apiService.loginWithSms(
        phone: phone,
        code: code,
      );
      developer.log(
        'Sms login API returned successfully',
        name: 'hospital.auth',
        error: {
          'tokenType': loginResult.tokenType,
          'accessTokenLength': loginResult.accessToken.length,
        },
      );
      _token = loginResult.accessToken;
      await _storageService.writeAuthToken(_token!);
      developer.log(
        'Token saved to local storage after sms login',
        name: 'hospital.auth',
        error: {'tokenLength': _token!.length},
      );
      await _refreshCurrentUser(notify: false);
      developer.log(
        'Sms login flow completed',
        name: 'hospital.auth',
        error: {
          'hasCurrentUser': _currentUser != null,
          'isAuthenticated': isAuthenticated,
        },
      );
      notifyListeners();
    } catch (error, stackTrace) {
      developer.log(
        'Sms login flow failed',
        name: 'hospital.auth',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> loginWithCarrierToken(String carrierToken) async {
    developer.log(
      'Carrier login flow started',
      name: 'hospital.auth',
      error: {'tokenLength': carrierToken.length},
    );
    try {
      final loginResult = await _apiService.loginWithCarrierToken(carrierToken);
      developer.log(
        'Carrier login API returned successfully',
        name: 'hospital.auth',
        error: {
          'tokenType': loginResult.tokenType,
          'accessTokenLength': loginResult.accessToken.length,
        },
      );
      _token = loginResult.accessToken;
      await _storageService.writeAuthToken(_token!);
      developer.log(
        'Token saved to local storage after carrier login',
        name: 'hospital.auth',
        error: {'tokenLength': _token!.length},
      );
      await _refreshCurrentUser(notify: false);
      developer.log(
        'Carrier login flow completed',
        name: 'hospital.auth',
        error: {
          'hasCurrentUser': _currentUser != null,
          'isAuthenticated': isAuthenticated,
        },
      );
      notifyListeners();
    } catch (error, stackTrace) {
      developer.log(
        'Carrier login flow failed',
        name: 'hospital.auth',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> refreshCurrentUser() => _refreshCurrentUser(notify: true);

  Future<void> updateLocalCurrentUser({
    String? displayName,
    String? avatarKey,
  }) async {
    final currentUser = _currentUser;
    if (currentUser == null) {
      return;
    }
    _currentUser = currentUser.copyWith(
      displayName: displayName,
      avatarKey: avatarKey,
    );
    await _storageService.writeCurrentUser(_currentUser);
    notifyListeners();
  }

  Future<void> updateCurrentUserProfile({
    required String displayName,
    String? avatarKey,
  }) async {
    final token = _token;
    if (token == null || token.isEmpty) {
      throw Exception('当前未登录，无法更新个人资料');
    }

    final updatedUser = await _apiService.updateCurrentUserProfile(
      token: token,
      payload: CurrentUserProfilePayload(
        displayName: displayName,
        avatarKey: avatarKey,
      ),
    );
    _currentUser = updatedUser;
    await _storageService.writeCurrentUser(_currentUser);
    notifyListeners();
  }

  Future<void> _refreshCurrentUser({required bool notify}) async {
    if (!isAuthenticated) {
      developer.log(
        'Skip current user refresh because user is not authenticated',
        name: 'hospital.auth',
      );
      _currentUser = null;
      await _storageService.writeCurrentUser(null);
      if (notify) {
        notifyListeners();
      }
      return;
    }

    try {
      developer.log('Refreshing current user', name: 'hospital.auth');
      _currentUser = await _apiService.fetchCurrentUser(_token!);
      await _storageService.writeCurrentUser(_currentUser);
      final phone = _currentUser?.phone.trim() ?? '';
      if (phone.replaceAll(RegExp(r'\D'), '').length >= 7) {
        await _storageService.writeRecentLoginPhone(phone);
      }
      developer.log(
        'Current user refreshed',
        name: 'hospital.auth',
        error: {
          'userId': _currentUser?.id,
          'displayName': _currentUser?.displayName,
        },
      );
    } catch (error, stackTrace) {
      developer.log(
        'Refreshing current user failed',
        name: 'hospital.auth',
        error: error,
        stackTrace: stackTrace,
      );

      final errorMessage = error.toString().toLowerCase();
      if (errorMessage.contains('401') ||
          errorMessage.contains('unauthorized')) {
        developer.log(
          'Token expired or unauthorized, executing logout',
          name: 'hospital.auth',
        );
        unawaited(logout());
        return;
      }

      _currentUser = null;
      await _storageService.writeCurrentUser(null);
    }

    if (notify) {
      notifyListeners();
    }
  }

  Future<void> logout() async {
    developer.log(
      'Logout flow started',
      name: 'hospital.auth',
      error: {'hadToken': _token != null && _token!.isNotEmpty},
    );
    final currentToken = _token;
    _token = null;
    _currentUser = null;
    await _storageService.clearUserData();

    if (currentToken != null && currentToken.isNotEmpty) {
      try {
        await _apiService.logout(currentToken);
      } catch (error, stackTrace) {
        developer.log(
          'Logout API failed',
          name: 'hospital.auth',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    developer.log('Logout flow completed', name: 'hospital.auth');
    notifyListeners();
  }

  Future<void> deactivateAccount() async {
    developer.log(
      'Account deactivation flow started',
      name: 'hospital.auth',
      error: {'hadToken': _token != null && _token!.isNotEmpty},
    );
    final currentToken = _token;
    if (currentToken == null || currentToken.isEmpty) {
      throw Exception('当前未登录，无法注销账号');
    }

    await _apiService.deactivateCurrentUser(currentToken);
    _token = null;
    _currentUser = null;
    await _storageService.clearUserData();

    developer.log('Account deactivation flow completed', name: 'hospital.auth');
    notifyListeners();
  }
}
