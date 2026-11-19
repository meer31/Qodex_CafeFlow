import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'services/supabase_service.dart';
import 'providers/auth_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/category_provider.dart';
import 'providers/product_provider.dart';
import 'providers/stock_provider.dart';
import 'providers/table_provider.dart';
import 'providers/waiter_provider.dart';
import 'providers/expense_provider.dart';
import 'providers/pos_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/meat_purchase_provider.dart';
import 'database/database_helper.dart';
import 'providers/sale_session_provider.dart';
import 'screens/main_layout_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite FFI bindings safely for Desktop Windows, macOS, Linux
  DatabaseHelper.ensureFfiInitialized();

  // Initialize Supabase
  await SupabaseService.initialize();

  runApp(const CafeFlowApp());
}

class CafeFlowApp extends StatelessWidget {
  const CafeFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
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
      child: Consumer<SettingsProvider>(
        builder: (context, settingsProv, _) {
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.getThemeData(settingsProv.settings.appTheme),
            home: Consumer<AuthProvider>(
              builder: (context, authProvider, _) {
                if (authProvider.isAuthenticated) {
                  return const MainLayoutScreen();
                }
                return const LoginScreen();
              },
            ),
          );
        },
      ),
    );
  }
}
