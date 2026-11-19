import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../models/sale_model.dart';
import '../models/cafe_table_model.dart';
import '../models/waiter_model.dart';
import '../providers/dashboard_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/table_provider.dart';
import '../providers/stock_provider.dart';
import '../providers/waiter_provider.dart';
import '../providers/pos_provider.dart';
import '../providers/sale_session_provider.dart';
import '../services/invoice_service.dart';
import '../widgets/kpi_card.dart';
import '../widgets/sales_chart_widget.dart';
import '../widgets/invoice_dialogs.dart';
import '../widgets/sale_session_dialogs.dart';

class DashboardScreen extends StatelessWidget {
  final Function(int) onNavigate;

  const DashboardScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final dashboard = Provider.of<DashboardProvider>(context);
    final settings = Provider.of<SettingsProvider>(context).settings;
    final currency = settings.currencySymbol;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Quick Action Buttons
          LayoutBuilder(
            builder: (context, headerConstraints) {
              return Wrap(
                spacing: 16,
                runSpacing: 12,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Operational Dashboard',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Real-time overview of active shift sales, expenses, counter money, and tables',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Consumer<SaleSessionProvider>(
                        builder: (context, sessionProv, _) {
                          final active = sessionProv.activeSession;
                          if (active == null) {
                            return ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.play_arrow_rounded, size: 18),
                              label: const Text('Start Sale Shift'),
                              onPressed: () => SaleSessionDialogs.showStartSaleDialog(context),
                            );
                          } else {
                            return OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red.shade700,
                                side: BorderSide(color: Colors.red.shade400),
                              ),
                              icon: const Icon(Icons.stop_circle_rounded, size: 18),
                              label: const Text('End Sale Shift'),
                              onPressed: () => SaleSessionDialogs.showEndSaleDialog(context),
                            );
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded),
                        tooltip: 'Refresh Dashboard',
                        onPressed: () async {
                          await dashboard.loadDashboardData();
                          if (context.mounted) {
                            Provider.of<SaleSessionProvider>(context, listen: false).loadSessions();
                            Provider.of<StockProvider>(context, listen: false).loadStockData();
                            Provider.of<TableProvider>(context, listen: false).loadTableData();
                          }
                        },
                      ),
                      ElevatedButton.icon(
                        onPressed: () => onNavigate(1), // Go to POS
                        icon: const Icon(Icons.point_of_sale_rounded),
                        label: const Text('Open POS Terminal'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => onNavigate(4), // Go to Stock
                        icon: const Icon(Icons.add_shopping_cart_rounded),
                        label: const Text('Add Stock'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // KPI Cards Row (Active Shift Focus: Total Sale & Total Expense of Active Shift Only)
          LayoutBuilder(
            builder: (context, constraints) {
              final double width = constraints.maxWidth;
              final int crossAxisCount = width > 1100 ? 4 : (width > 600 ? 2 : 1);
              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: width > 1100 ? 2.3 : 2.5,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // 1. Active Shift Total Sales
                  KpiCard(
                    title: "Active Shift Sales",
                    value: "$currency ${dashboard.activeShiftSales.toStringAsFixed(0)}",
                    subtitle: dashboard.hasActiveShift
                        ? (dashboard.activeSession?.sessionName ?? 'Current Active Shift')
                        : 'No Active Shift Open',
                    icon: Icons.point_of_sale_rounded,
                    color: dashboard.hasActiveShift ? AppColors.primary : AppColors.textMuted,
                  ),
                  // 2. Active Shift Total Expenses
                  KpiCard(
                    title: "Active Shift Expenses",
                    value: "$currency ${dashboard.activeShiftExpenses.toStringAsFixed(0)}",
                    subtitle: dashboard.hasActiveShift
                        ? 'Expenses in current shift'
                        : 'No Active Shift Open',
                    icon: Icons.account_balance_wallet_rounded,
                    color: AppColors.error,
                  ),
                  // 3. Counter Money (Opening Float + Cash Sales)
                  KpiCard(
                    title: "Counter Cash",
                    value: "$currency ${dashboard.activeCounterCash.toStringAsFixed(0)}",
                    subtitle: dashboard.hasActiveShift
                        ? 'Float: $currency ${dashboard.activeOpeningCash.toStringAsFixed(0)} + Cash Sales'
                        : 'Drawer cash for change',
                    icon: Icons.payments_rounded,
                    color: Colors.teal.shade700,
                  ),
                  // 4. Remaining Bills
                  KpiCard(
                    title: "Remaining Bills",
                    value: "$currency ${dashboard.totalRemainingSales.toStringAsFixed(0)}",
                    subtitle: "${dashboard.totalRemainingCount} pending payment",
                    icon: Icons.hourglass_top_rounded,
                    color: Colors.orange.shade800,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Sales Chart & Side Summaries (Active Tables + Low Stock Alerts)
          LayoutBuilder(
            builder: (context, chartConstraints) {
              final isStacked = chartConstraints.maxWidth < 950;

              final chartWidget = SizedBox(
                height: 380,
                child: SalesChartWidget(
                  dataPoints: dashboard.dailySalesChart,
                  title: 'Daily Sales Performance (7 Days)',
                  currencySymbol: currency,
                ),
              );

              final sideColumn = SizedBox(
                height: isStacked ? 340 : 380,
                child: Column(
                  children: [
                    // Active Tables Quick Banner
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg,
                        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.table_restaurant_rounded, color: AppColors.accent, size: 24),
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Occupied Tables', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                  Text('${dashboard.activeTablesCount} Active Dining', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: () => onNavigate(6), // Tables
                            child: const Text('View Tables'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Low Stock Alerts Card
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.cardBg,
                          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Low Stock Alerts',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${dashboard.lowStockAlerts.length} Items',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.warning),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: dashboard.lowStockAlerts.isEmpty
                                  ? Center(
                                      child: Text(
                                        'All stock levels are optimal',
                                        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                                      ),
                                    )
                                  : ListView.separated(
                                      itemCount: dashboard.lowStockAlerts.length,
                                      separatorBuilder: (_, _) => const Divider(height: 12),
                                      itemBuilder: (context, index) {
                                        final item = dashboard.lowStockAlerts[index];
                                        return Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item.name,
                                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '${item.quantity.toStringAsFixed(1)} ${item.unit}',
                                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.error),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );

              if (isStacked) {
                return Column(
                  children: [
                    chartWidget,
                    const SizedBox(height: 16),
                    sideColumn,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: chartWidget),
                  const SizedBox(width: 20),
                  Expanded(flex: 2, child: sideColumn),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Bottom Row: Recent Invoices & Top Selling Items
          LayoutBuilder(
            builder: (context, bottomConstraints) {
              final isStacked = bottomConstraints.maxWidth < 950;

              final invoicesWidget = Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent Invoices',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: () => onNavigate(8), // Invoices History
                          child: const Text('View All Invoices'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columnSpacing: 20,
                        headingRowHeight: 48,
                        dataRowMinHeight: 40,
                        dataRowMaxHeight: 46,
                        columns: const [
                          DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Invoice #', style: TextStyle(fontWeight: FontWeight.bold))))),
                          DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Time', style: TextStyle(fontWeight: FontWeight.bold))))),
                          DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Table', style: TextStyle(fontWeight: FontWeight.bold))))),
                          DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))))),
                          DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Grand Total', style: TextStyle(fontWeight: FontWeight.bold))))),
                          DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Payment', style: TextStyle(fontWeight: FontWeight.bold))))),
                          DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))))),
                        ],
                        rows: dashboard.recentInvoices.map((sale) {
                          return DataRow(cells: [
                            DataCell(
                              Text(
                                '#${sale.invoiceNumber}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            DataCell(Text(sale.dateTime.split('T').last.substring(0, 5))),
                            DataCell(Text(sale.tableName ?? 'Takeaway')),
                            // Status column
                            DataCell(
                              sale.isRemaining
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade100,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.orange.shade300, width: 0.8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.hourglass_top_rounded, size: 10, color: Colors.orange.shade900),
                                          const SizedBox(width: 3),
                                          Text(
                                            'REMAINING',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.orange.shade900,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.accent.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4), width: 0.8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.check_circle_rounded, size: 10, color: AppColors.accent),
                                          SizedBox(width: 3),
                                          Text(
                                            'CLEARED',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.accent,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                            DataCell(Text('$currency ${sale.grandTotal.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(sale.paymentMethod, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accent)),
                            )),
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (sale.isRemaining) ...[
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.accent,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      minimumSize: const Size(0, 26),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                      elevation: 0,
                                    ),
                                    icon: const Icon(Icons.check_rounded, size: 12, color: Colors.white),
                                    label: const Text('Clear', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                    onPressed: () => _handleClearBill(context, sale, dashboard),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Tooltip(
                                  message: 'Edit Invoice',
                                  child: InkWell(
                                    onTap: () => _handleEditInvoice(context, sale, dashboard),
                                    borderRadius: BorderRadius.circular(4),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Tooltip(
                                  message: 'Delete Invoice',
                                  child: InkWell(
                                    onTap: () => _handleDeleteInvoice(context, sale, dashboard),
                                    borderRadius: BorderRadius.circular(4),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: AppColors.error.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Tooltip(
                                  message: 'Print Receipt',
                                  child: InkWell(
                                    onTap: () async {
                                      await InvoiceService.printInvoice(sale: sale, settings: settings);
                                    },
                                    borderRadius: BorderRadius.circular(4),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: AppColors.secondary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Icon(Icons.print_rounded, size: 16, color: AppColors.secondary),
                                    ),
                                  ),
                                ),
                              ],
                            )),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              );

              final topSellingWidget = Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Top Selling Items',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                dashboard.hasActiveShift
                                    ? (dashboard.activeSession?.sessionName ?? 'Active Shift')
                                    : 'No active shift running',
                                style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: dashboard.hasActiveShift
                                ? AppColors.accent.withValues(alpha: 0.12)
                                : AppColors.textMuted.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: dashboard.hasActiveShift
                                  ? AppColors.accent.withValues(alpha: 0.3)
                                  : AppColors.border,
                            ),
                          ),
                          child: Text(
                            dashboard.hasActiveShift ? 'SHIFT ITEMS' : 'INACTIVE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: dashboard.hasActiveShift ? AppColors.accent : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (dashboard.topSellingItems.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.local_cafe_outlined,
                              size: 36,
                              color: AppColors.textMuted.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              dashboard.hasActiveShift
                                  ? 'No items sold in this shift yet'
                                  : 'Start a shift to see selling items',
                              style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: dashboard.topSellingItems.length,
                        separatorBuilder: (_, _) => const Divider(height: 16),
                        itemBuilder: (context, index) {
                          final item = dashboard.topSellingItems[index];
                          final unitPrice = (item['unit_price'] as num?)?.toDouble();
                          final totalRev = (item['total_revenue'] as num?)?.toDouble();

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                      child: Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['name'] as String,
                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (unitPrice != null && totalRev != null)
                                            Text(
                                              'Rate: $currency ${unitPrice.toStringAsFixed(0)} | Rev: $currency ${totalRev.toStringAsFixed(0)}',
                                              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.secondary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${item['qty']} sold',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.secondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                  ],
                ),
              );

              if (isStacked) {
                return Column(
                  children: [
                    invoicesWidget,
                    const SizedBox(height: 16),
                    topSellingWidget,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: invoicesWidget),
                  const SizedBox(width: 20),
                  Expanded(flex: 2, child: topSellingWidget),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _handleEditInvoice(BuildContext context, SaleModel sale, DashboardProvider dashboard) {
    final tableProvider = Provider.of<TableProvider>(context, listen: false);
    final waiterProvider = Provider.of<WaiterProvider>(context, listen: false);
    final posProvider = Provider.of<PosProvider>(context, listen: false);

    CafeTableModel? matchedTable;
    if (sale.tableId != null) {
      try {
        matchedTable = tableProvider.tables.firstWhere((t) => t.id == sale.tableId);
      } catch (_) {}
    }

    WaiterModel? matchedWaiter;
    if (sale.waiterId != null) {
      try {
        matchedWaiter = waiterProvider.waiters.firstWhere((w) => w.id == sale.waiterId);
      } catch (_) {}
    }

    posProvider.loadInvoiceForEditing(sale, table: matchedTable, waiter: matchedWaiter);
    onNavigate(1); // Switch to POS terminal

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Loaded Invoice #${sale.invoiceNumber} into POS for editing.'),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleDeleteInvoice(BuildContext context, SaleModel sale, DashboardProvider dashboard) async {
    await InvoiceDialogs.showDeleteDialog(
      context: context,
      sale: sale,
      onDelete: (s) async {
        await dashboard.deleteSale(s.id!);
        if (context.mounted) {
          Provider.of<SaleSessionProvider>(context, listen: false).loadSessions();
          Provider.of<StockProvider>(context, listen: false).loadStockData();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Invoice #${s.invoiceNumber} deleted and stock restored.'),
              backgroundColor: AppColors.textPrimary,
            ),
          );
        }
      },
    );
  }

  Future<void> _handleClearBill(
    BuildContext context,
    SaleModel sale,
    DashboardProvider dashboard,
  ) async {
    await InvoiceDialogs.showClearBillDialog(
      context: context,
      sale: sale,
      onClear: (paymentMethod) async {
        await dashboard.clearBill(sale.id!, paymentMethod: paymentMethod);
        if (context.mounted) {
          Provider.of<SaleSessionProvider>(context, listen: false).loadSessions();
          Provider.of<StockProvider>(context, listen: false).loadStockData();
          Provider.of<TableProvider>(context, listen: false).loadTableData();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Invoice #${sale.invoiceNumber} cleared! Total Sales updated.'),
              backgroundColor: AppColors.accent,
            ),
          );
        }
      },
    );
  }
}