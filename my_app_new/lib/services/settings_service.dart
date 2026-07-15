import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import 'audio_service.dart';

class SettingsService extends ChangeNotifier {
  SettingsService._();

  static final SettingsService instance = SettingsService._();

  AppSettings _settings = AppSettings.defaults;

  AppSettings get settings => _settings;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final theme = prefs.getString("theme") ?? "system";

    ThemeMode mode = ThemeMode.system;

    switch (theme) {
      case "light":
        mode = ThemeMode.light;
        break;

      case "dark":
        mode = ThemeMode.dark;
        break;

      default:
        mode = ThemeMode.system;
    }

    Color color = Colors.blue;

    switch (prefs.getString("color")) {
      case "green":
        color = Colors.green;
        break;

      case "purple":
        color = Colors.purple;
        break;

      case "red":
        color = Colors.red;
        break;

      default:
        color = Colors.blue;
    }

    _settings = AppSettings(
      themeMode: mode,
      musicEnabled: prefs.getBool("music") ?? true,
      soundEnabled: prefs.getBool("sound") ?? true,
      musicVolume: prefs.getDouble("musicVolume") ?? 0.7,
      soundVolume: prefs.getDouble("soundVolume") ?? 1,
      accentColor: color,
    );

    AudioService.musicEnabled = _settings.musicEnabled;
    AudioService.soundEnabled = _settings.soundEnabled;

    AudioService.setMusicVolume(_settings.musicVolume);
    AudioService.setSoundVolume(_settings.soundVolume);

    notifyListeners();
  }

  Future<void> setTheme(ThemeMode mode) async {
    _settings = _settings.copyWith(themeMode: mode);

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      "theme",
      switch (mode) {
        ThemeMode.light => "light",
        ThemeMode.dark => "dark",
        ThemeMode.system => "system",
      },
    );

    notifyListeners();
  }

  Future<void> setAccent(Color color) async {
    _settings = _settings.copyWith(accentColor: color);

    final prefs = await SharedPreferences.getInstance();

    String name = "blue";

    if (color == Colors.green) name = "green";
    if (color == Colors.purple) name = "purple";
    if (color == Colors.red) name = "red";

    await prefs.setString("color", name);

    notifyListeners();
  }

  Future<void> setMusic(bool value) async {
    _settings = _settings.copyWith(musicEnabled: value);

    AudioService.musicEnabled = value;

    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool("music", value);

    notifyListeners();
  }

  Future<void> setSound(bool value) async {
    _settings = _settings.copyWith(soundEnabled: value);

    AudioService.soundEnabled = value;

    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool("sound", value);

    notifyListeners();
  }

  Future<void> setMusicVolume(double value) async {
    _settings = _settings.copyWith(musicVolume: value);

    AudioService.setMusicVolume(value);

    final prefs = await SharedPreferences.getInstance();

    await prefs.setDouble("musicVolume", value);

    notifyListeners();
  }

  Future<void> setSoundVolume(double value) async {
    _settings = _settings.copyWith(soundVolume: value);

    AudioService.setSoundVolume(value);

    final prefs = await SharedPreferences.getInstance();

    await prefs.setDouble("soundVolume", value);

    notifyListeners();
  }
}