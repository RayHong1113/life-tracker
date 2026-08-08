import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 💡 仅使用 Flutter 官方 SDK 的 services 包
import 'package:provider/provider.dart';
import '../../providers/activity_provider.dart';
import '../calendar/calendar_view.dart';
import '../statistics/statistics_view.dart';
import '../settings/settings_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Consumer<ActivityProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(0.0),
            child: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
            ),
          ),
          body: IndexedStack(
            index: _currentTabIndex,
            children: const [
              CalendarView(),   // 0: Calendar
              StatisticsView(), // 1: Statistics
              SettingsView(),   // 2: Settings
            ],
          ),
          bottomNavigationBar: NavigationBarTheme(
            data: NavigationBarThemeData(
              height: 56,
              indicatorColor: const Color(0xFFE8F0FE), // 自定义选中的高亮胶囊颜色
              overlayColor: WidgetStateProperty.all(
                const Color(0xFF1A73E8).withValues(alpha: 0.12),
              ),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              iconTheme: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const IconThemeData(size: 20, color: Color(0xFF1A73E8));
                }
                return const IconThemeData(size: 20, color: Colors.black54);
              }),
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1A73E8));
                }
                return const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.black54);
              }),
            ),
            child: NavigationBar(
              selectedIndex: _currentTabIndex,
              onDestinationSelected: (index) {
                if (_currentTabIndex != index) {
                  setState(() {
                    _currentTabIndex = index;
                  });
                }
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.calendar_today_outlined),
                  selectedIcon: Icon(Icons.calendar_today),
                  label: 'Calendar',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart),
                  label: 'Statistics',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}