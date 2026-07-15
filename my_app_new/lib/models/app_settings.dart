import 'package:flutter/material.dart';

class AppSettings {
  final ThemeMode themeMode;

  final bool musicEnabled;
  final bool soundEnabled;

  final double musicVolume;
  final double soundVolume;

  final Color accentColor;

  const AppSettings({
    required this.themeMode,
    required this.musicEnabled,
    required this.soundEnabled,
    required this.musicVolume,
    required this.soundVolume,
    required this.accentColor,
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? musicEnabled,
    bool? soundEnabled,
    double? musicVolume,
    double? soundVolume,
    Color? accentColor,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      musicEnabled: musicEnabled ?? this.musicEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      musicVolume: musicVolume ?? this.musicVolume,
      soundVolume: soundVolume ?? this.soundVolume,
      accentColor: accentColor ?? this.accentColor,
    );
  }

  static const defaults = AppSettings(
    themeMode: ThemeMode.system,
    musicEnabled: true,
    soundEnabled: true,
    musicVolume: 0.7,
    soundVolume: 1,
    accentColor: Colors.blue,
  );
}