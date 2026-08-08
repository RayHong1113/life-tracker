// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:life_tracker/main.dart';
import 'package:life_tracker/providers/settings_provider.dart';

void main() {
  testWidgets('App loads successfully smoke test', (WidgetTester tester) async {
    // 1. 创建测试所需的 SettingsProvider 实例
    final settingsProvider = SettingsProvider();

    // 2. 传入 settingsProvider 并渲染页面
    await tester.pumpWidget(MyApp(settingsProvider: settingsProvider));

    // 3. 验证应用能够正常加载运行（不发生崩溃）
    expect(find.byType(MyApp), findsOneWidget);
  });
}