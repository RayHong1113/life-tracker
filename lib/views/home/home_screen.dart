import 'package:flutter/material.dart';
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
          // 💡 紧凑小巧的底部导航栏主题配置
          bottomNavigationBar: NavigationBarTheme(
            data: NavigationBarThemeData(
              height: 56, // 💡 压缩为 56px 的超窄高度
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow, // 💡 修正属性类型名称
              iconTheme: WidgetStateProperty.all(
                const IconThemeData(size: 20),
              ),
              labelTextStyle: WidgetStateProperty.all(
                const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ),
            child: NavigationBar(
              selectedIndex: _currentTabIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _currentTabIndex = index;
                });
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