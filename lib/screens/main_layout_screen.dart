import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/stock_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/sale_session_provider.dart';
import '../widgets/sale_session_dialogs.dart';
import '../widgets/daily_sale_detail_dialog.dart';
import '../widgets/sidebar_navigation.dart';

import 'dashboard_screen.dart';
import 'pos_billing_screen.dart';
import 'category_management_screen.dart';
import 'product_management_screen.dart';
import 'stock_management_screen.dart';
import 'recipe_management_screen.dart';
import 'tables_management_screen.dart';
import 'waiter_management_screen.dart';
import 'invoice_history_screen.dart';
import 'expenses_screen.dart';
import 'reports_screen.dart';
import 'report_center_screen.dart';
import 'settings_screen.dart';
import 'meat_purchase_screen.dart';

class MainLayoutScreen extends StatefulWidget {
  const MainLayoutScreen({super.key});

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  int _selectedIndex = 0;
  bool _isSidebarOpen = false;
  Timer? _sidebarCloseTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SaleSessionProvider>(context, listen: false).loadSessions();
    });
  }

  @override
  void dispose() {
    _sidebarCloseTimer?.cancel();
    super.dispose();
  }

  void _openSidebar() {
    _sidebarCloseTimer?.cancel();
    if (!_isSidebarOpen) {
      setState(() {
        _isSidebarOpen = true;
      });
    }
  }

  void _scheduleCloseSidebar({Duration delay = const Duration(milliseconds: 220)}) {
    _sidebarCloseTimer?.cancel();
    _sidebarCloseTimer = Timer(delay, () {
      if (mounted && _isSidebarOpen) {
        setState(() {
          _isSidebarOpen = false;
        });
      }
    });
  }

  void _cancelCloseTimer() {
    _sidebarCloseTimer?.cancel();
  }

  void _closeSidebarImmediately() {
    _sidebarCloseTimer?.cancel();
    if (_isSidebarOpen) {
      setState(() {
        _isSidebarOpen = false;
      });
    }
  }

  void _toggleSidebar() {
    _sidebarCloseTimer?.cancel();
    setState(() {
      _isSidebarOpen = !_isSidebarOpen;
    });
  }

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final stockProvider = Provider.of<StockProvider>(context);
    final settings = Provider.of<SettingsProvider>(context).settings;

    final List<Widget> screens = [
      DashboardScreen(key: ValueKey('dash_${settings.appTheme}'), onNavigate: _onDestinationSelected),
      PosBillingScreen(key: ValueKey('pos_${settings.appTheme}')),
      CategoryManagementScreen(key: ValueKey('cat_${settings.appTheme}')),
      ProductManagementScreen(key: ValueKey('prod_${settings.appTheme}')),
      StockManagementScreen(key: ValueKey('stock_${settings.appTheme}')),
      RecipeManagementScreen(key: ValueKey('recipe_${settings.appTheme}')),
      TablesManagementScreen(key: ValueKey('tables_${settings.appTheme}'), onNavigate: _onDestinationSelected),
      WaiterManagementScreen(key: ValueKey('waiter_${settings.appTheme}')),
      InvoiceHistoryScreen(key: ValueKey('invoice_${settings.appTheme}'), onNavigate: _onDestinationSelected),
      ExpensesScreen(key: ValueKey('expenses_${settings.appTheme}')),
      MeatPurchaseScreen(key: ValueKey('meat_${settings.appTheme}')),
      ReportsScreen(key: ValueKey('reports_${settings.appTheme}')),
      ReportCenterScreen(key: ValueKey('reportcenter_${settings.appTheme}')),
      SettingsScreen(key: ValueKey('settings_${settings.appTheme}')),
    ];

    final lowStockCount = stockProvider.lowStockItems.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final bool isNarrow = width < 768;
        const double sidebarWidth = 260.0;

        return Scaffold(
          body: Stack(
            children: [
              // Main Layout Column
              Column(
                children: [
                  // Responsive Top Header Bar
                  Container(
                    height: 64,
                    padding: EdgeInsets.symmetric(horizontal: isNarrow ? 12 : 16),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      border: Border(bottom: BorderSide(color: AppColors.border)),
                    ),
                    child: Row(
                      children: [
                        // Top Left Menu Button (Auto-slides open on cursor hover & toggles on click)
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          onEnter: (_) => _openSidebar(),
                          onExit: (_) => _scheduleCloseSidebar(),
                          child: IconButton(
                            icon: AnimatedRotation(
                              turns: _isSidebarOpen ? 0.25 : 0.0,
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                _isSidebarOpen ? Icons.menu_open_rounded : Icons.menu_rounded,
                                color: AppColors.primary,
                                size: 26,
                              ),
                            ),
                            tooltip: 'Menu (Hover to auto slide)',
                            onPressed: _toggleSidebar,
                          ),
                        ),
                        const SizedBox(width: 8),

                          // Active Screen Title & Cafe Name
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    settings.cafeName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: isNarrow ? 16 : 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    authProvider.activeRole.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Shift Status Pill / Start Sale, Low Stock Badge & User Profile
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Consumer<SaleSessionProvider>(
                                builder: (context, sessionProv, _) {
                                  final active = sessionProv.activeSession;
                                  if (active != null) {
                                    return Tooltip(
                                      message: 'Click to view shift details, counter cash & live invoices',
                                      child: InkWell(
                                        onTap: () => DailySaleDetailDialog.show(context, active),
                                        borderRadius: BorderRadius.circular(20),
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: isNarrow ? 8 : 12,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: Colors.green.withValues(alpha: 0.35)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: const BoxDecoration(
                                                  color: Colors.green,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              if (!isNarrow) ...[
                                                Text(
                                                  'Shift: ${active.startTimeFormatted}',
                                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.green),
                                                ),
                                                const SizedBox(width: 6),
                                              ],
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppColors.cardBg,
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                                                ),
                                                child: Text(
                                                  '${settings.currencySymbol} ${active.totalSales.toStringAsFixed(0)}',
                                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.primary),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  } else {
                                    return ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.accent,
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.symmetric(horizontal: isNarrow ? 8 : 12, vertical: 5),
                                        minimumSize: const Size(0, 32),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        elevation: 0,
                                      ),
                                      icon: const Icon(Icons.play_arrow_rounded, size: 16),
                                      label: Text(
                                        isNarrow ? 'Start' : 'Start Sale Shift',
                                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                                      ),
                                      onPressed: () => SaleSessionDialogs.showStartSaleDialog(context),
                                    );
                                  }
                                },
                              ),

                              if (lowStockCount > 0 && !isNarrow) ...[
                                const SizedBox(width: 10),
                                InkWell(
                                  onTap: () => _onDestinationSelected(4), // Go to Stock
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: AppColors.warning.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.warning_amber_rounded, size: 15, color: AppColors.warning),
                                        const SizedBox(width: 5),
                                        Text(
                                          '$lowStockCount Low Stock',
                                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.warning),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],

                              const SizedBox(width: 10),

                              // Profile Avatar & Name
                              CircleAvatar(
                                backgroundColor: AppColors.secondary,
                                radius: 16,
                                child: Text(
                                  authProvider.currentUser.name.isNotEmpty
                                      ? authProvider.currentUser.name.substring(0, 1).toUpperCase()
                                      : 'U',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),

                              if (!isNarrow) ...[
                                const SizedBox(width: 8),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      authProvider.currentUser.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                                    ),
                                    Text(
                                      authProvider.currentUser.role,
                                      style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(Icons.logout_rounded, color: AppColors.error, size: 18),
                                  tooltip: 'Sign Out',
                                  onPressed: () => authProvider.logout(),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Active Page Content
              Expanded(
                child: IndexedStack(
                  index: _selectedIndex,
                  children: [
                    for (int i = 0; i < screens.length; i++)
                      ExcludeSemantics(
                        excluding: i != _selectedIndex,
                        child: screens[i],
                      ),
                  ],
                ),
              ),
            ],
          ),

          // Backdrop Overlay when sidebar is open
          if (_isSidebarOpen)
            Positioned.fill(
              child: MouseRegion(
                onEnter: (_) => _scheduleCloseSidebar(),
                child: GestureDetector(
                  onTap: _closeSidebarImmediately,
                  behavior: HitTestBehavior.translucent,
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.18),
                  ),
                ),
              ),
            ),

          // Auto-sliding Sidebar Panel
          AnimatedPositioned(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            top: 0,
            bottom: 0,
            left: _isSidebarOpen ? 0 : -sidebarWidth,
            width: sidebarWidth,
            child: MouseRegion(
              onEnter: (_) => _cancelCloseTimer(),
              onExit: (_) => _scheduleCloseSidebar(),
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: _isSidebarOpen
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 18,
                            spreadRadius: 2,
                            offset: const Offset(4, 0),
                          ),
                        ]
                      : [],
                ),
                child: SidebarNavigation(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (i) {
                    _closeSidebarImmediately();
                    _onDestinationSelected(i);
                  },
                  onClose: _closeSidebarImmediately,
                  isCompact: false,
                ),
              ),
            ),
          ),
        ],
      ),
    );
      },
    );
  }
}