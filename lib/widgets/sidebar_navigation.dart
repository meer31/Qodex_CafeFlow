import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/constants/app_constants.dart';
import '../providers/auth_provider.dart';

class SidebarNavigation extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onDestinationSelected;
  final bool isCompact;
  final VoidCallback? onClose;

  const SidebarNavigation({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.isCompact = false,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final String activeRole = authProvider.activeRole;

    final List<Map<String, dynamic>> menuItems = [
      {'title': 'Dashboard', 'icon': Icons.dashboard_rounded, 'roles': [AppConstants.roleAdmin, AppConstants.roleManager, AppConstants.roleCashier]},
      {'title': 'POS Billing', 'icon': Icons.point_of_sale_rounded, 'roles': [AppConstants.roleAdmin, AppConstants.roleManager, AppConstants.roleCashier]},
      {'title': 'Categories', 'icon': Icons.category_rounded, 'roles': [AppConstants.roleAdmin, AppConstants.roleManager]},
      {'title': 'Products', 'icon': Icons.restaurant_menu_rounded, 'roles': [AppConstants.roleAdmin, AppConstants.roleManager]},
      {'title': 'Stock Inventory', 'icon': Icons.inventory_2_rounded, 'roles': [AppConstants.roleAdmin, AppConstants.roleManager]},
      {'title': 'Raw Materials & Recipes', 'icon': Icons.menu_book_rounded, 'roles': [AppConstants.roleAdmin, AppConstants.roleManager]},
      {'title': 'Tables & Sections', 'icon': Icons.table_restaurant_rounded, 'roles': [AppConstants.roleAdmin, AppConstants.roleManager, AppConstants.roleCashier]},
      {'title': 'Waiters', 'icon': Icons.badge_rounded, 'roles': [AppConstants.roleAdmin, AppConstants.roleManager]},
      {'title': 'Sales & Invoices', 'icon': Icons.receipt_long_rounded, 'roles': [AppConstants.roleAdmin, AppConstants.roleManager, AppConstants.roleCashier]},
      {'title': 'Expenses', 'icon': Icons.account_balance_wallet_rounded, 'roles': [AppConstants.roleAdmin, AppConstants.roleManager]},
      {'title': 'Meat Purchases', 'icon': Icons.kebab_dining_rounded, 'roles': [AppConstants.roleAdmin, AppConstants.roleManager]},
      {'title': 'Reports & Analytics', 'icon': Icons.analytics_rounded, 'roles': [AppConstants.roleAdmin, AppConstants.roleManager, AppConstants.roleCashier]},
      {'title': 'Report Center', 'icon': Icons.summarize_rounded, 'roles': [AppConstants.roleAdmin, AppConstants.roleManager, AppConstants.roleCashier]},
      {'title': 'Settings', 'icon': Icons.settings_rounded, 'roles': [AppConstants.roleAdmin]},
    ];

    if (isCompact) {
      return Container(
        width: 72,
        color: AppColors.sidebarBg,
        child: Column(
          children: [
            // Compact Brand Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
              ),
              child: Tooltip(
                message: 'QODEX CAFEFLOW',
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/images/qodex_logo.png',
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),

            // Compact Menu List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                itemCount: menuItems.length,
                itemBuilder: (context, index) {
                  final item = menuItems[index];
                  final List<String> allowedRoles = item['roles'] as List<String>;
                  final bool isAllowed = allowedRoles.contains(activeRole);

                  if (!isAllowed) return const SizedBox.shrink();

                  final isSelected = selectedIndex == index;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Tooltip(
                      message: item['title'] as String,
                      child: InkWell(
                        onTap: () => onDestinationSelected(index),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            item['icon'] as IconData,
                            color: isSelected ? Colors.white : AppColors.textMuted,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Compact Role Switcher & Logout Footer
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFF1E293B))),
              ),
              child: Column(
                children: [
                  PopupMenuButton<String>(
                    tooltip: 'Active Role: $activeRole',
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.sidebarActive,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        activeRole == AppConstants.roleAdmin
                            ? Icons.admin_panel_settings_rounded
                            : activeRole == AppConstants.roleManager
                                ? Icons.manage_accounts_rounded
                                : Icons.point_of_sale_rounded,
                        size: 18,
                        color: AppColors.accent,
                      ),
                    ),
                    color: AppColors.secondary,
                    onSelected: (role) => authProvider.switchRole(role),
                    itemBuilder: (context) => [
                      AppConstants.roleAdmin,
                      AppConstants.roleManager,
                      AppConstants.roleCashier,
                    ].map((role) => PopupMenuItem(
                      value: role,
                      child: Text(role, style: const TextStyle(color: Colors.white, fontSize: 13)),
                    )).toList(),
                  ),
                  const SizedBox(height: 8),
                  IconButton(
                    icon: Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                    tooltip: 'Sign Out',
                    onPressed: () => authProvider.logout(),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: 250,
      color: AppColors.sidebarBg,
      child: Column(
        children: [
          // Cafe Brand Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/images/qodex_logo.png',
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'QODEX',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.0,
                        ),
                      ),
                      SizedBox(height: 1),
                      Text(
                        'CAFEFLOW',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFF38BDF8),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Smart Cafe & Restaurant Mgmt',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onClose != null)
                  IconButton(
                    icon: Icon(Icons.chevron_left_rounded, color: AppColors.textMuted, size: 22),
                    tooltip: 'Close Sidebar',
                    onPressed: onClose,
                    splashRadius: 18,
                  ),
              ],
            ),
          ),

          // Menu Navigation Links
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              itemCount: menuItems.length,
              itemBuilder: (context, index) {
                final item = menuItems[index];
                final List<String> allowedRoles = item['roles'] as List<String>;
                final bool isAllowed = allowedRoles.contains(activeRole);

                if (!isAllowed) return const SizedBox.shrink();

                final isSelected = selectedIndex == index;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: InkWell(
                    onTap: () => onDestinationSelected(index),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item['icon'] as IconData,
                            color: isSelected ? Colors.white : AppColors.textMuted,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item['title'] as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                                fontSize: 13.5,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Role Switcher Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFF1E293B))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ACTIVE ROLE',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.sidebarActive,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: activeRole,
                      dropdownColor: AppColors.secondary,
                      isExpanded: true,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                      items: [
                        AppConstants.roleAdmin,
                        AppConstants.roleManager,
                        AppConstants.roleCashier,
                      ].map((role) => DropdownMenuItem(
                        value: role,
                        child: Row(
                          children: [
                            Icon(
                              role == AppConstants.roleAdmin
                                  ? Icons.admin_panel_settings_rounded
                                  : role == AppConstants.roleManager
                                      ? Icons.manage_accounts_rounded
                                      : Icons.point_of_sale_rounded,
                              size: 16,
                              color: AppColors.accent,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                role,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      )).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          authProvider.switchRole(val);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => authProvider.logout(),
                  borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                      border: Border.all(color: AppColors.error.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout_rounded, color: AppColors.error, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Sign Out',
                          style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}