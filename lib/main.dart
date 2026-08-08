import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/activity_provider.dart';
import 'views/home/home_screen.dart';
import 'providers/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settingsProvider = SettingsProvider();
  await settingsProvider.loadSettings();
  
  // 💡 把加载好的 settingsProvider 传给 MyApp
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
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}