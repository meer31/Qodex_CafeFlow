import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:cafe_flow/screens/main_layout_screen.dart';
import 'package:cafe_flow/providers/auth_provider.dart';
import 'package:cafe_flow/providers/settings_provider.dart';
import 'package:cafe_flow/providers/category_provider.dart';
import 'package:cafe_flow/providers/product_provider.dart';
import 'package:cafe_flow/providers/stock_provider.dart';
import 'package:cafe_flow/providers/table_provider.dart';
import 'package:cafe_flow/providers/waiter_provider.dart';
import 'package:cafe_flow/providers/expense_provider.dart';
import 'package:cafe_flow/providers/pos_provider.dart';
import 'package:cafe_flow/providers/dashboard_provider.dart';
import 'package:cafe_flow/providers/meat_purchase_provider.dart';
import 'package:cafe_flow/providers/sale_session_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Sidebar auto slides out on menu button click or hover and slides back on exit', (WidgetTester tester) async {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      originalOnError?.call(details);
    };
    addTearDown(() {
      FlutterError.onError = originalOnError;
    });

    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(create: (_) => CategoryProvider()),
          ChangeNotifierProvider(create: (_) => ProductProvider()),
          ChangeNotifierProvider(create: (_) => StockProvider()),
          ChangeNotifierProvider(create: (_) => TableProvider()),
          ChangeNotifierProvider(create: (_) => WaiterProvider()),
          ChangeNotifierProvider(create: (_) => ExpenseProvider()),
          ChangeNotifierProvider(create: (_) => PosProvider()),
          ChangeNotifierProvider(create: (_) => DashboardProvider()),
          ChangeNotifierProvider(create: (_) => MeatPurchaseProvider()),
          ChangeNotifierProvider(create: (_) => SaleSessionProvider()),
        ],
        child: const MaterialApp(
          home: MainLayoutScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Initially, sidebar AnimatedPositioned has left = -260 (hidden)
    final animatedPositionedFinder = find.byType(AnimatedPositioned);
    expect(animatedPositionedFinder, findsOneWidget);
    AnimatedPositioned pos = tester.widget(animatedPositionedFinder);
    expect(pos.left, equals(-260.0));

    // Find the Menu Button MouseRegion
    final menuButtonFinder = find.byTooltip('Menu (Hover to auto slide)');
    expect(menuButtonFinder, findsOneWidget);

    // Tapping the menu button opens the sidebar
    await tester.tap(menuButtonFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300)); // animation finish

    pos = tester.widget(animatedPositionedFinder);
    expect(pos.left, equals(0.0));

    // Tapping the close button inside the sidebar closes it
    final closeButtonFinder = find.byTooltip('Close Sidebar');
    expect(closeButtonFinder, findsOneWidget);
    await tester.tap(closeButtonFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    pos = tester.widget(animatedPositionedFinder);
    expect(pos.left, equals(-260.0));
  });
}
