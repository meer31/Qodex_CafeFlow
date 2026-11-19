import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/app_settings_model.dart';
import '../repositories/settings_repository.dart';

class SettingsProvider with ChangeNotifier {
  final SettingsRepository _repository = SettingsRepository();
  AppSettingsModel _settings = AppSettingsModel();
  bool _isLoading = false;

  AppSettingsModel get settings => _settings;
  bool get isLoading => _isLoading;

  SettingsProvider() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    _isLoading = true;
    notifyListeners();

    _settings = await _repository.getSettings();
    AppTheme.setPalette(_settings.appTheme);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateSettings(AppSettingsModel newSettings) async {
    _settings = newSettings;
    AppTheme.setPalette(newSettings.appTheme);
    await _repository.saveSettings(newSettings);
    notifyListeners();
  }

  Future<void> updateTheme(String themeKey) async {
    _settings = _settings.copyWith(appTheme: themeKey);
    AppTheme.setPalette(themeKey);
    await _repository.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> updateMilkRatio(double newRatio) async {
    _settings = _settings.copyWith(milkCupsPerKg: newRatio);
    await _repository.saveSettings(_settings);
    notifyListeners();
  }
}
