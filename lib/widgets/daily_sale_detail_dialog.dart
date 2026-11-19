import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../models/sale_session_model.dart';
import '../models/sale_model.dart';
import '../models/expense_model.dart';
import '../providers/sale_session_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/invoice_dialogs.dart';
import '../widgets/sale_session_dialogs.dart';

class DailySaleDetailDialog extends StatefulWidget {
  final SaleSessionModel session;

  const DailySaleDetailDialog({super.key, required this.session});

  static Future<void> show(BuildContext context, SaleSessionModel session) async {
    await showDialog(
      context: context,
      builder: (_) => DailySaleDetailDialog(session: session),
    );
  }

  @override
  State<DailySaleDetailDialog> createState() => _DailySaleDetailDialogState();
}

class _DailySaleDetailDialogState extends State<DailySaleDetailDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<SaleModel> _invoices = [];
  List<ExpenseModel> _expenses = [];
  List<SessionSoldItem> _soldItems = [];
  List<SessionStockReportItem> _stockReportItems = [];
  String _itemSearchQuery = '';
  String _stockSearchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final provider = Provider.of<SaleSessionProvider>(context, listen: false);
    final invoices = await provider.getSessionInvoices(widget.session.id!);
    final expenses = await provider.getSessionExpenses(widget.session.id!);
    final soldItems = await provider.getSessionSoldItems(widget.session.id!);
    final stockReportItems = await provider.getSessionStockReport(widget.session.id!);

    if (mounted) {
      setState(() {
        _invoices = invoices;
        _expenses = expenses;
        _soldItems = soldItems;
        _stockReportItems = stockReportItems;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context).settings;
    final currency = settings.currencySymbol;
    final session = widget.session;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 960,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.date_range_rounded, color: AppColors.primary, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(session.sessionName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: session.isActive
                                    ? AppColors.accent.withValues(alpha: 0.15)
                                    : AppColors.textMuted.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                session.status,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: session.isActive ? AppColors.accent : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Started: ${session.startTime.replaceFirst('T', ' ').substring(0, 16)}'
                          '${session.endTime != null ? '  |  Ended: ${session.endTime!.replaceFirst('T', ' ').substring(0, 16)}' : '  |  (Still in progress)'}',
                          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Top Financial KPI Cards Row
            Row(
              children: [
                _buildKpiCard(
                  title: 'TOTAL SALES',
                  value: '$currency ${session.totalSales.toStringAsFixed(0)}',
                  subtitle: '${_invoices.length} Invoices',
                  color: AppColors.primary,
                  icon: Icons.point_of_sale_rounded,
                ),
                const SizedBox(width: 12),
                _buildKpiCard(
                  title: 'OPENING COUNTER CASH',
                  value: '$currency ${session.openingCash.toStringAsFixed(0)}',
                  subtitle: 'Cash for change',
                  color: Colors.teal,
                  icon: Icons.payments_rounded,
                ),
                const SizedBox(width: 12),
                _buildKpiCard(
                  title: 'TOTAL COUNTER MONEY',
                  value: '$currency ${session.totalCounterCash.toStringAsFixed(0)}',
                  subtitle: 'Opening + Cash Sales',
                  color: AppColors.accent,
                  icon: Icons.account_balance_wallet_rounded,
                  highlight: true,
                ),
                const SizedBox(width: 12),
                _buildKpiCard(
                  title: 'TOTAL EXPENSES',
                  value: '$currency ${session.totalExpenses.toStringAsFixed(0)}',
                  subtitle: '${_expenses.length} Records',
                  color: AppColors.error,
                  icon: Icons.money_off_rounded,
                ),
                const SizedBox(width: 12),
                _buildKpiCard(
                  title: 'NET SHIFT PROFIT',
                  value: '$currency ${session.netProfit.toStringAsFixed(0)}',
                  subtitle: 'Sales - Expenses',
                  color: session.netProfit >= 0 ? AppColors.accent : AppColors.error,
                  icon: Icons.trending_up_rounded,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tabs Bar
            TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: AppColors.primary,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lunch_dining_rounded, size: 18),
                      const SizedBox(width: 6),
                      Text('Selling Items (${_soldItems.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.receipt_long_rounded, size: 18),
                      const SizedBox(width: 6),
                      Text('All Invoices (${_invoices.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.receipt_rounded, size: 18),
                      const SizedBox(width: 6),
                      Text('Expenses (${_expenses.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.inventory_2_rounded, size: 18),
                      const SizedBox(width: 6),
                      Text('Stock (${_stockReportItems.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Tab View Body
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        // TAB 1: ALL SELLING ITEMS OF THAT DAY / SHIFT
                        _buildSellingItemsTab(currency),

                        // TAB 2: ALL INVOICES OF THAT DAY
                        _invoices.isEmpty
                            ? Center(child: Text('No invoices recorded during this shift.', style: TextStyle(color: AppColors.textMuted)))
                            : ListView.builder(
                                itemCount: _invoices.length,
                                itemBuilder: (context, index) {
                                  final sale = _invoices[index];
                                  final timePart = sale.dateTime.contains('T')
                                      ? sale.dateTime.split('T').last.substring(0, 5)
                                      : sale.dateTime;

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    elevation: 0.5,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: BorderSide(color: AppColors.border),
                                    ),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                      leading: CircleAvatar(
                                        backgroundColor: sale.isCleared
                                            ? AppColors.accent.withValues(alpha: 0.15)
                                            : AppColors.warning.withValues(alpha: 0.15),
                                        child: Text(
                                          '#${sale.invoiceNumber}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: sale.isCleared ? AppColors.accent : AppColors.warning,
                                          ),
                                        ),
                                      ),
                                      title: Row(
                                        children: [
                                          Text('Invoice #${sale.invoiceNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: sale.isCleared
                                                  ? AppColors.accent.withValues(alpha: 0.1)
                                                  : AppColors.warning.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              sale.isCleared ? 'PAID' : 'REMAINING',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: sale.isCleared ? AppColors.accent : AppColors.warning,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text('Time: $timePart', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                          if (sale.tableName != null && sale.tableName!.isNotEmpty) ...[
                                            const SizedBox(width: 8),
                                            Text('| Table: ${sale.tableName}', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                          ],
                                          if (sale.waiterName != null && sale.waiterName!.isNotEmpty) ...[
                                            const SizedBox(width: 8),
                                            Text('| Waiter: ${sale.waiterName}', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                          ],
                                        ],
                                      ),
                                      subtitle: Text(
                                        'Items: ${sale.items.map((i) => '${i.quantity}x ${i.productName}').join(', ')}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                '$currency ${sale.grandTotal.toStringAsFixed(0)}',
                                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                                              ),
                                              Text(sale.paymentMethod, style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                                            ],
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: Icon(Icons.visibility_rounded, size: 20, color: AppColors.primary),
                                            tooltip: 'View / Print Invoice',
                                            onPressed: () {
                                              InvoiceDialogs.showInvoiceDetailsDialog(
                                                context: context,
                                                sale: sale,
                                                currencySymbol: currency,
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),

                        // TAB 2: EXPENSES OF THAT DAY
                        _expenses.isEmpty
                            ? Center(child: Text('No expenses recorded during this shift.', style: TextStyle(color: AppColors.textMuted)))
                            : ListView.builder(
                                itemCount: _expenses.length,
                                itemBuilder: (context, index) {
                                  final exp = _expenses[index];
                                  final timePart = exp.dateTime.contains('T')
                                      ? exp.dateTime.split('T').last.substring(0, 5)
                                      : exp.dateTime;

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    elevation: 0.5,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: BorderSide(color: AppColors.border),
                                    ),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: Color(0xFFFFEBEB),
                                        child: Icon(Icons.money_off_rounded, color: AppColors.error, size: 20),
                                      ),
                                      title: Row(
                                        children: [
                                          Text(exp.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary.withValues(alpha: 0.08),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(exp.category, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                          ),
                                          const SizedBox(width: 8),
                                          Text('Time: $timePart', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                        ],
                                      ),
                                      subtitle: exp.notes != null && exp.notes!.isNotEmpty
                                          ? Text(exp.notes!, style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic))
                                          : null,
                                      trailing: Text(
                                        '- $currency ${exp.amount.toStringAsFixed(2)}',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.error),
                                      ),
                                    ),
                                  );
                                },
                              ),

                        // TAB 4: STOCK IN, CONSUMED & PRODUCTS PRODUCED
                        _buildStockTab(currency),
                      ],
                    ),
            ),
            const SizedBox(height: 12),

            // Footer Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.print_rounded),
                  label: const Text('Print Shift Summary (Z-Report)'),
                  onPressed: () async {
                    await SaleSessionDialogs.printShiftZReport(
                      session: widget.session,
                      currency: currency,
                      cafeName: settings.cafeName,
                    );
                  },
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
    bool highlight = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: highlight ? color.withValues(alpha: 0.12) : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: highlight ? color : AppColors.border, width: highlight ? 1.5 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.5),
                  ),
                ),
                Icon(icon, size: 16, color: color),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSellingItemsTab(String currency) {
    if (_soldItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fastfood_outlined, size: 48, color: AppColors.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              'No menu items sold during this shift yet.',
              style: TextStyle(fontSize: 14, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    final filteredItems = _soldItems.where((item) {
      if (_itemSearchQuery.trim().isEmpty) return true;
      return item.productName.toLowerCase().contains(_itemSearchQuery.trim().toLowerCase());
    }).toList();

    final totalCupsSold = _soldItems.fold<int>(0, (sum, i) => sum + i.quantity);
    final totalItemsRevenue = _soldItems.fold<double>(0.0, (sum, i) => sum + i.totalRevenue);

    return Column(
      children: [
        // Summary & Search Toolbar
        Row(
          children: [
            Expanded(
              flex: 5,
              child: TextField(
                onChanged: (val) => setState(() => _itemSearchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search selling items (e.g. Chai, Coffee, Biryani)...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _itemSearchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => setState(() => _itemSearchQuery = ''),
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.local_cafe_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Total Sold: $totalCupsSold cups / items',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppColors.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.payments_rounded, size: 18, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Text(
                    'Revenue: $currency ${totalItemsRevenue.toStringAsFixed(0)}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppColors.accent),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Table Header: Item Name | Number of Cups / Qty | Price per Cup | Total Revenue
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Text('ITEM / DISH NAME', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primary)),
              ),
              Expanded(
                flex: 3,
                child: Text('NUMBER OF CUPS / QTY', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primary)),
              ),
              Expanded(
                flex: 3,
                child: Text('PRICE PER CUP / ITEM', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primary)),
              ),
              Expanded(
                flex: 3,
                child: Text('TOTAL REVENUE', textAlign: TextAlign.end, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primary)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // List of selling items
        Expanded(
          child: filteredItems.isEmpty
              ? Center(
                  child: Text('No selling items matching your search query.', style: TextStyle(color: AppColors.textMuted)),
                )
              : ListView.separated(
                  itemCount: filteredItems.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
                    return Card(
                      margin: EdgeInsets.zero,
                      elevation: 0.5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: AppColors.border),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      item.productName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${item.quantity}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: AppColors.secondary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                '$currency ${item.unitPrice.toStringAsFixed(0)}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                '$currency ${item.totalRevenue.toStringAsFixed(0)}',
                                textAlign: TextAlign.end,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStockTab(String currency) {
    final filteredStock = _stockReportItems.where((s) {
      if (_stockSearchQuery.isEmpty) return true;
      final q = _stockSearchQuery.toLowerCase();
      final matchesStockName = s.stockName.toLowerCase().contains(q);
      final matchesProduct = s.productsProduced.any((p) => p.productName.toLowerCase().contains(q));
      return matchesStockName || matchesProduct;
    }).toList();

    final totalStockInCount = _stockReportItems.where((s) => s.stockIn > 0).length;
    final totalConsumedCount = _stockReportItems.where((s) => s.stockOut > 0).length;

    return Column(
      children: [
        // Search & Summary Toolbar
        Row(
          children: [
            Expanded(
              flex: 5,
              child: TextField(
                onChanged: (val) => setState(() => _stockSearchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search stock items or ingredients (e.g. Milk, Chicken, Paratha, Sugar)...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _stockSearchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => setState(() => _stockSearchQuery = ''),
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.add_shopping_cart_rounded, size: 18, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  Text(
                    'Stock In: $totalStockInCount Items',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF047857)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.outbox_rounded, size: 18, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 8),
                  Text(
                    'Consumed: $totalConsumedCount Items',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFFB45309)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Stock Items List
        Expanded(
          child: filteredStock.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.textMuted.withValues(alpha: 0.5)),
                      const SizedBox(height: 12),
                      Text(
                        'No stock movement or consumption recorded during this shift.',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: filteredStock.length,
                  itemBuilder: (context, index) {
                    final item = filteredStock[index];

                    final inStr = item.stockIn % 1 == 0 ? item.stockIn.toInt().toString() : item.stockIn.toStringAsFixed(2);
                    final outStr = item.stockOut % 1 == 0 ? item.stockOut.toInt().toString() : item.stockOut.toStringAsFixed(2);
                    final netStr = item.netBalance % 1 == 0 ? item.netBalance.toInt().toString() : item.netBalance.toStringAsFixed(2);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      elevation: 0.5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: AppColors.border),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top Row: Name and Key Metrics
                            Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.inventory_2_rounded, color: AppColors.primary, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.stockName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Unit: ${item.unit}',
                                        style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                // Inward Pill
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: (item.stockIn > 0 ? const Color(0xFF10B981) : Colors.grey).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: (item.stockIn > 0 ? const Color(0xFF10B981) : Colors.grey).withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.arrow_downward_rounded,
                                        size: 14,
                                        color: item.stockIn > 0 ? const Color(0xFF047857) : Colors.grey,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Stock In: $inStr ${item.unit}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11.5,
                                          color: item.stockIn > 0 ? const Color(0xFF047857) : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Outward (Consumed) Pill
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: (item.stockOut > 0 ? const Color(0xFFF59E0B) : Colors.grey).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: (item.stockOut > 0 ? const Color(0xFFF59E0B) : Colors.grey).withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.local_fire_department_rounded,
                                        size: 14,
                                        color: item.stockOut > 0 ? const Color(0xFFB45309) : Colors.grey,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Consumed: $outStr ${item.unit}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11.5,
                                          color: item.stockOut > 0 ? const Color(0xFFB45309) : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Balance Pill
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: (item.netBalance >= 0 ? const Color(0xFF3B82F6) : const Color(0xFFEF4444)).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: (item.netBalance >= 0 ? const Color(0xFF3B82F6) : const Color(0xFFEF4444)).withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        item.netBalance >= 0 ? Icons.check_rounded : Icons.remove_circle_outline_rounded,
                                        size: 14,
                                        color: item.netBalance >= 0 ? const Color(0xFF1D4ED8) : const Color(0xFFB91C1C),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Net: ${item.netBalance >= 0 ? '+' : ''}$netStr ${item.unit}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11.5,
                                          color: item.netBalance >= 0 ? const Color(0xFF1D4ED8) : const Color(0xFFB91C1C),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            // Products Produced Breakdown Section
                            const SizedBox(height: 10),
                            const Divider(height: 1),
                            const SizedBox(height: 8),

                            Row(
                              children: [
                                Icon(Icons.restaurant_rounded, size: 14, color: AppColors.textSecondary),
                                const SizedBox(width: 6),
                                Text(
                                  'Items Sold / Made using this stock (${item.productsProduced.length} items):',
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),

                            if (item.productsProduced.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(left: 20),
                                child: Text(
                                  'Direct stock adjustment or transaction without specific recipe mapping.',
                                  style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textMuted),
                                ),
                              )
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: item.productsProduced.map((prod) {
                                  final pUsedStr = prod.stockUsed % 1 == 0
                                      ? prod.stockUsed.toInt().toString()
                                      : prod.stockUsed.toStringAsFixed(2);
                                  final pct = item.stockOut > 0 ? (prod.stockUsed / item.stockOut * 100) : 0.0;

                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.background,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          prod.productName.toLowerCase().contains('chai') ||
                                                  prod.productName.toLowerCase().contains('tea') ||
                                                  prod.productName.toLowerCase().contains('coffee')
                                              ? Icons.local_cafe_rounded
                                              : Icons.fastfood_rounded,
                                          size: 14,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          prod.productName,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                                        ),
                                        const SizedBox(width: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '${prod.soldQuantity} sold',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 10,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text('➔', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                        const SizedBox(width: 6),
                                        Text(
                                          '$pUsedStr ${prod.unit}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                            color: Color(0xFFD97706),
                                          ),
                                        ),
                                        if (pct > 0) ...[
                                          const SizedBox(width: 4),
                                          Text(
                                            '(${pct.toStringAsFixed(0)}%)',
                                            style: TextStyle(fontSize: 9.5, color: AppColors.textMuted),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
