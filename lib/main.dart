import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/activity_provider.dart';
import 'views/home/home_screen.dart';

void main() {
  // Ensure Flutter engine bindings are initialized before calling native database plugins
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MultiProvider allows injecting state management models at the top level of the widget tree
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ActivityProvider()..fetchActivities(),
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