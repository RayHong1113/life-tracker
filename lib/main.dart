import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/activity_provider.dart';
import 'views/home/home_screen.dart';
import 'providers/settings_provider.dart';
import 'services/firebase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await FirebaseService.instance.init();
  } catch (e) {
    debugPrint('Firebase Service init error: $e');
  }

  final settingsProvider = SettingsProvider();
  try {
    await settingsProvider.loadSettings();
  } catch (e) {
    debugPrint('Settings Provider load error: $e');
  }

  runApp(MyApp(settingsProvider: settingsProvider));
}

class MyApp extends StatelessWidget {
  final SettingsProvider settingsProvider;

  const MyApp({super.key, required this.settingsProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ActivityProvider()..fetchActivities(),
        ),
        // 💡 关键：将 settingsProvider 注册进 MultiProvider
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settingsProvider,
        ),
      ],
      child: MaterialApp(
        title: 'Life Tracker',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A73E8)),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}