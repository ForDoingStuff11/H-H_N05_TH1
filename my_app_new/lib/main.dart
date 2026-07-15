import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:my_app/services/audio_service.dart';
import 'package:my_app/services/settings_service.dart';
import 'helper/app_theme.dart';
import 'screens/auth/auth_gate.dart';
import 'helper/presence_observer.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AudioService.initialize();
  await SettingsService.instance.load();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SettingsService.instance,
      builder: (context, _) {
        final settings = SettingsService.instance.settings;

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Online Caro',

          themeMode: settings.themeMode,

          theme: AppTheme.lightTheme(settings.accentColor),

          darkTheme: AppTheme.darkTheme(settings.accentColor),

          home: const PresenceObserver(child: AuthGate()),
        );
      },
    );
  }
}
