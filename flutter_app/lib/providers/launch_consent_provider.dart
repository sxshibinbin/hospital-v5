import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../services/app_storage_service.dart';

class LaunchConsentProvider with ChangeNotifier {
  LaunchConsentProvider({AppStorageService? storageService})
    : _storageService = storageService ?? AppStorageService.instance {
    unawaited(_initialize());
  }

  final AppStorageService _storageService;

  bool _isLoading = true;
  bool _hasAccepted = false;

  bool get isLoading => _isLoading;
  bool get hasAccepted => _hasAccepted;

  Future<void> _initialize() async {
    developer.log(
      'Launch consent initialization started',
      name: 'hospital.launch_consent',
    );
    try {
      _hasAccepted = await _storageService.readLaunchConsentAccepted();
    } catch (error, stackTrace) {
      developer.log(
        'Reading launch consent failed',
        name: 'hospital.launch_consent',
        error: error,
        stackTrace: stackTrace,
      );
      _hasAccepted = false;
    } finally {
      _isLoading = false;
      developer.log(
        'Launch consent initialization completed',
        name: 'hospital.launch_consent',
        error: {'hasAccepted': _hasAccepted},
      );
      notifyListeners();
    }
  }

  Future<void> accept() async {
    await _storageService.writeLaunchConsentAccepted(true);
    _hasAccepted = true;
    _isLoading = false;
    developer.log('Launch consent accepted', name: 'hospital.launch_consent');
    notifyListeners();
  }
}
