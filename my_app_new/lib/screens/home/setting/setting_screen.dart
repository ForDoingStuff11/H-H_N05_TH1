import 'package:flutter/material.dart';
import 'package:my_app/services/settings_service.dart';


class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SettingsService.instance,
      builder: (_, __) {
        final settings = SettingsService.instance.settings;

        return Scaffold(
          appBar: AppBar(
            title: const Text("Settings"),
          ),

          body: ListView(
            padding: const EdgeInsets.all(20),

            children: [

              const Text(
                "Appearance",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              Card(
                child: Column(
                  children: [

                    RadioListTile(
                      title: const Text("System"),
                      value: ThemeMode.system,
                      groupValue: settings.themeMode,
                      onChanged: (value) {
                        SettingsService.instance.setTheme(value!);
                      },
                    ),

                    RadioListTile(
                      title: const Text("Light"),
                      value: ThemeMode.light,
                      groupValue: settings.themeMode,
                      onChanged: (value) {
                        SettingsService.instance.setTheme(value!);
                      },
                    ),

                    RadioListTile(
                      title: const Text("Dark"),
                      value: ThemeMode.dark,
                      groupValue: settings.themeMode,
                      onChanged: (value) {
                        SettingsService.instance.setTheme(value!);
                      },
                    ),

                  ],
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                "Accent Color",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              Wrap(
                spacing: 12,
                children: [

                  _colorCircle(Colors.blue),

                  _colorCircle(Colors.green),

                  _colorCircle(Colors.purple),

                  _colorCircle(Colors.red),

                  _colorCircle(Colors.orange),

                ],
              ),

              const SizedBox(height: 30),

              const Text(
                "Audio",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              Card(
                child: Column(
                  children: [

                    SwitchListTile(
                      title: const Text("Background Music"),
                      value: settings.musicEnabled,
                      onChanged: (value) {
                        SettingsService.instance.setMusic(value);
                      },
                    ),

                    ListTile(
                      title: const Text("Music Volume"),

                      subtitle: Slider(
                        value: settings.musicVolume,

                        onChanged: settings.musicEnabled
                            ? (value) {
                                SettingsService.instance
                                    .setMusicVolume(value);
                              }
                            : null,
                      ),
                    ),

                    const Divider(),

                    SwitchListTile(
                      title: const Text("Sound Effect"),
                      value: settings.soundEnabled,
                      onChanged: (value) {
                        SettingsService.instance.setSound(value);
                      },
                    ),

                    ListTile(
                      title: const Text("Sound Volume"),

                      subtitle: Slider(
                        value: settings.soundVolume,

                        onChanged: settings.soundEnabled
                            ? (value) {
                                SettingsService.instance
                                    .setSoundVolume(value);
                              }
                            : null,
                      ),
                    ),

                  ],
                ),
              ),

              const SizedBox(height: 30),

              Card(
                child: ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text("About"),
                  subtitle: const Text(
                    "Online Caro\nVersion 1.0",
                  ),
                ),
              ),

            ],
          ),
        );
      },
    );
  }

  Widget _colorCircle(Color color) {
    return GestureDetector(
      onTap: () {
        SettingsService.instance.setAccent(color);
      },
      child: CircleAvatar(
        radius: 18,
        backgroundColor: color,
      ),
    );
  }
}