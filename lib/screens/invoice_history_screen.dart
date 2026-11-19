import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../models/sale_model.dart';
import '../models/cafe_table_model.dart';
import '../models/waiter_model.dart';
import '../models/sale_session_model.dart';
import '../repositories/sale_repository.dart';
import '../providers/settings_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/table_provider.dart';
import '../providers/stock_provider.dart';
import '../providers/waiter_provider.dart';
import '../providers/pos_provider.dart';
import '../providers/sale_session_provider.dart';
import '../services/invoice_service.dart';
import '../widgets/invoice_dialogs.dart';
import '../widgets/sale_session_dialogs.dart';
import '../widgets/daily_sale_detail_dialog.dart';

class InvoiceHistoryScreen extends StatefulWidget {
  final Function(int)? onNavigate;

  const InvoiceHistoryScreen({super.key, this.onNavigate});

  @override
  State<InvoiceHistoryScreen> createState() => _InvoiceHistoryScreenState();
}

class _InvoiceHistoryScreenState extends State<InvoiceHistoryScreen> {
  final SaleRepository _saleRepository = SaleRepository();
  List<SaleModel> _invoices = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _statusFilter = 'ALL'; // ALL, REMAINING, CLEARED
  int _currentTabIndex = 0; // 0: All Invoices, 1: Daily Sale Shifts

  // State for Daily Sale Shifts tab search & date filtering
  final TextEditingController _shiftSearchController = TextEditingController();
  String _shiftSearchQuery = '';
  DateTime? _shiftSelectedDate;
  String _shiftDateQuickFilter = 'ALL'; // ALL, TODAY, YESTERDAY, CUSTOM
  String _shiftStatusFilter = 'ALL'; // ALL, ACTIVE, CLOSED

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _shiftSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _invoices = await _saleRepository.getAllSales(limit: 100);
    if (mounted) {
      Provider.of<SaleSessionProvider>(context, listen: false).loadSessions();
      Provider.of<DashboardProvider>(context, listen: false).loadDashboardData();
      Provider.of<TableProvider>(context, listen: false).loadTableData();
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleClearBill(SaleModel sale) async {
    final cleared = await InvoiceDialogs.showClearBillDialog(
      context: context,
      sale: sale,
      onClear: (paymentMethod) async {
        final dashboardProvider = Provider.of<DashboardProvider>(context, listen: false);
        await dashboardProvider.clearBill(sale.id!, paymentMethod: paymentMethod);
        if (mounted) {
          Provider.of<StockProvider>(context, listen: false).loadStockData();
          Provider.of<SaleSessionProvider>(context, listen: false).loadSessions();
        }
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Invoice #${sale.invoiceNumber} cleared! Total Sales updated.'),
              backgroundColor: AppColors.accent,
            ),
          );
        }
      },
    );
    if (cleared == true) {
      _loadData();
    }
  }

  void _handleEditInvoice(SaleModel sale) {
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

    if (widget.onNavigate != null) {
      widget.onNavigate!(1);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Loaded Invoice #${sale.invoiceNumber} into POS for editing.'),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleDeleteInvoice(SaleModel sale) async {
    final deleted = await InvoiceDialogs.showDeleteDialog(
      context: context,
      sale: sale,
      onDelete: (s) async {
        await _saleRepository.deleteSale(s.id!);
        if (mounted) {
          Provider.of<DashboardProvider>(context, listen: false).loadDashboardData();
          Provider.of<StockProvider>(context, listen: false).loadStockData();
          Provider.of<SaleSessionProvider>(context, listen: false).loadSessions();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Invoice #${s.invoiceNumber} deleted and stock restored.'),
              backgroundColor: AppColors.textPrimary,
            ),
          );
        }
      },
    );
    if (deleted == true) {
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context).settings;
    final currency = settings.currencySymbol;

    final remainingCount = _invoices.where((s) => s.isRemaining).length;
    final clearedCount = _invoices.where((s) => s.isCleared).length;

    final filtered = _invoices.where((sale) {
      if (_statusFilter == 'REMAINING' && !sale.isRemaining) return false;
      if (_statusFilter == 'CLEARED' && !sale.isCleared) return false;

      final q = _searchQuery.toLowerCase();
      final numMatch = sale.invoiceNumber.toLowerCase().contains(q);
      final tableMatch = (sale.tableName ?? '').toLowerCase().contains(q);
      final waiterMatch = (sale.waiterName ?? '').toLowerCase().contains(q);
      return numMatch || tableMatch || waiterMatch;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            // Top Screen Header & Quick Actions (Fully Responsive)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sales, Invoices & Shift Records',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Search past sales records, manage cross-midnight daily shifts, and track counter cash',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
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
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.play_arrow_rounded, size: 18),
                            label: const Text('Start Sale Shift', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () => SaleSessionDialogs.showStartSaleDialog(context),
                          );
                        } else {
                          return ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.stop_circle_rounded, size: 18),
                            label: const Text('End Sale Shift', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () => SaleSessionDialogs.showEndSaleDialog(context),
                          );
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'Refresh All Data',
                      onPressed: _loadData,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tab Navigation Bar
            Container(
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _currentTabIndex = 0),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _currentTabIndex == 0 ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long_rounded,
                              size: 18,
                              color: _currentTabIndex == 0 ? Colors.white : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'All Invoices (${_invoices.length})',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _currentTabIndex == 0 ? Colors.white : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Consumer<SaleSessionProvider>(
                      builder: (context, sessionProv, _) {
                        final count = sessionProv.sessions.length;
                        final hasActive = sessionProv.activeSession != null;
                        return InkWell(
                          onTap: () => setState(() => _currentTabIndex = 1),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            decoration: BoxDecoration(
                              color: _currentTabIndex == 1 ? AppColors.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.calendar_month_rounded,
                                  size: 18,
                                  color: _currentTabIndex == 1
                                      ? Colors.white
                                      : (hasActive ? Colors.greenAccent : AppColors.textSecondary),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  hasActive ? 'Daily Sale Shifts ($count) 🟢 LIVE' : 'Daily Sale Shifts ($count)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: _currentTabIndex == 1 ? Colors.white : AppColors.textSecondary,
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
              ),
            ),
            const SizedBox(height: 16),

            // Active Tab View
            Expanded(
              child: _currentTabIndex == 0
                  ? _buildInvoicesTab(currency, remainingCount, clearedCount, filtered)
                  : _buildDailySaleShiftsTab(currency),
            ),
          ],
        ),
      );
  }

  // ==========================================
  // TAB 1: ALL INVOICES
  // ==========================================
  Widget _buildInvoicesTab(String currency, int remainingCount, int clearedCount, List<SaleModel> filtered) {
    final settings = Provider.of<SettingsProvider>(context, listen: false).settings;

    return Column(
      children: [
        // KPI Summary Cards: Weekly Sales, Monthly Sales, Net Profit, Remaining Bills
        Consumer<DashboardProvider>(
          builder: (context, dashboard, _) {
            final cards = [
              _buildStatCard('Weekly Sales', '$currency ${dashboard.weeklySales.toStringAsFixed(0)}', Icons.date_range_rounded, AppColors.info),
              _buildStatCard('Monthly Sales', '$currency ${dashboard.monthlySales.toStringAsFixed(0)}', Icons.calendar_month_rounded, AppColors.secondary),
              _buildStatCard(
                'Monthly Net Profit',
                '$currency ${dashboard.monthlyProfit.toStringAsFixed(0)}',
                Icons.trending_up_rounded,
                dashboard.monthlyProfit >= 0 ? AppColors.accent : AppColors.error,
              ),
              _buildStatCard(
                'Remaining Bills',
                '$currency ${dashboard.totalRemainingSales.toStringAsFixed(0)}',
                Icons.hourglass_top_rounded,
                Colors.orange.shade800,
              ),
            ];

            return LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 800) {
                  return Column(
                    children: [
                      Row(children: [cards[0], const SizedBox(width: 10), cards[1]]),
                      const SizedBox(height: 10),
                      Row(children: [cards[2], const SizedBox(width: 10), cards[3]]),
                    ],
                  );
                }
                return Row(
                  children: [
                    cards[0],
                    const SizedBox(width: 10),
                    cards[1],
                    const SizedBox(width: 10),
                    cards[2],
                    const SizedBox(width: 10),
                    cards[3],
                  ],
                );
              },
            );
          },
        ),
        const SizedBox(height: 16),

        // Filters Row: Status Filter Chips & Search Bar (Responsive)
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 750;
            final chips = Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: Text('All (${_invoices.length})'),
                  selected: _statusFilter == 'ALL',
                  onSelected: (_) => setState(() => _statusFilter = 'ALL'),
                ),
                ChoiceChip(
                  avatar: Icon(
                    Icons.hourglass_top_rounded,
                    size: 14,
                    color: _statusFilter == 'REMAINING' ? Colors.white : Colors.orange.shade900,
                  ),
                  label: Text(
                    'Remaining / Delayed ($remainingCount)',
                    style: TextStyle(
                      color: _statusFilter == 'REMAINING' ? Colors.white : Colors.orange.shade900,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  selected: _statusFilter == 'REMAINING',
                  selectedColor: Colors.orange.shade800,
                  backgroundColor: Colors.orange.shade50,
                  onSelected: (_) => setState(() => _statusFilter = 'REMAINING'),
                ),
                ChoiceChip(
                  avatar: Icon(
                    Icons.check_circle_rounded,
                    size: 14,
                    color: _statusFilter == 'CLEARED' ? Colors.white : AppColors.accent,
                  ),
                  label: Text(
                    'Cleared / Paid ($clearedCount)',
                    style: TextStyle(
                      color: _statusFilter == 'CLEARED' ? Colors.white : AppColors.accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  selected: _statusFilter == 'CLEARED',
                  selectedColor: AppColors.accent,
                  backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                  onSelected: (_) => setState(() => _statusFilter = 'CLEARED'),
                ),
              ],
            );

            final search = TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: const InputDecoration(
                hintText: 'Search by Invoice Number, Table, or Waiter...',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            );

            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  chips,
                  const SizedBox(height: 10),
                  search,
                ],
              );
            }

            return Row(
              children: [
                chips,
                const SizedBox(width: 16),
                Expanded(child: search),
              ],
            );
          },
        ),
        const SizedBox(height: 16),

        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: filtered.isEmpty
                      ? const Center(child: Text('No invoices match search criteria'))
                      : SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columnSpacing: 18,
                              headingRowHeight: 48,
                              columns: const [
                                DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Invoice #', style: TextStyle(fontWeight: FontWeight.bold))))),
                                DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Date & Time', style: TextStyle(fontWeight: FontWeight.bold))))),
                                DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Table', style: TextStyle(fontWeight: FontWeight.bold))))),
                                DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))))),
                                DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Grand Total', style: TextStyle(fontWeight: FontWeight.bold))))),
                                DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Payment Method', style: TextStyle(fontWeight: FontWeight.bold))))),
                                DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))))),
                              ],
                              rows: filtered.map((sale) {
                                return DataRow(cells: [
                                  DataCell(
                                    Text(
                                      '#${sale.invoiceNumber}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(sale.dateTime.replaceFirst('T', ' ').substring(0, 16))),
                                  DataCell(Text(sale.tableName ?? 'Takeaway')),
                                  // Status Badge
                                  DataCell(
                                    sale.isRemaining
                                        ? Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.shade100,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: Colors.orange.shade300, width: 0.8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.hourglass_top_rounded, size: 12, color: Colors.orange.shade900),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'REMAINING',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.orange.shade900,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        : Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AppColors.accent.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: AppColors.accent.withValues(alpha: 0.4), width: 0.8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.check_circle_rounded, size: 12, color: AppColors.accent),
                                                SizedBox(width: 4),
                                                Text(
                                                  'CLEARED',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.accent,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                  ),
                                  DataCell(Text('$currency ${sale.grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
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
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            minimumSize: const Size(0, 32),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                            elevation: 1,
                                          ),
                                          icon: const Icon(Icons.check_circle_outline_rounded, size: 14, color: Colors.white),
                                          label: const Text('Clear', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                          onPressed: () => _handleClearBill(sale),
                                        ),
                                        const SizedBox(width: 6),
                                      ],
                                      IconButton(
                                        icon: Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
                                        tooltip: 'Edit Invoice in POS',
                                        onPressed: () => _handleEditInvoice(sale),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                                        tooltip: 'Delete Invoice',
                                        onPressed: () => _handleDeleteInvoice(sale),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.soup_kitchen_rounded, color: Colors.orange, size: 20),
                                        tooltip: 'Print Kitchen Token',
                                        onPressed: () async {
                                          await InvoiceService.printKitchenSlip(sale: sale, settings: settings);
                                        },
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.print_rounded, color: AppColors.primary, size: 20),
                                        tooltip: 'Print Customer Receipt',
                                        onPressed: () async {
                                          await InvoiceService.printInvoice(sale: sale, settings: settings);
                                        },
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.visibility_outlined, color: AppColors.secondary, size: 20),
                                        tooltip: 'View Details',
                                        onPressed: () => InvoiceDialogs.showInvoiceDetailsDialog(
                                          context: context,
                                          sale: sale,
                                          currencySymbol: currency,
                                        ),
                                      ),
                                    ],
                                  )),
                                ]);
                              }).toList(),
                            ),
                          ),
                        ),
                ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 2: DAILY SALE SHIFTS
  // ==========================================
  Widget _buildDailySaleShiftsTab(String currency) {
    return Consumer<SaleSessionProvider>(
      builder: (context, sessionProv, _) {
        if (sessionProv.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final allSessions = sessionProv.sessions;
        final active = sessionProv.activeSession;

        // Filter shifts by status, selected date, and text query
        final filteredSessions = allSessions.where((s) {
          // Status filter: ALL, ACTIVE, CLOSED
          if (_shiftStatusFilter == 'ACTIVE' && !s.isActive) return false;
          if (_shiftStatusFilter == 'CLOSED' && !s.isClosed) return false;

          // Picked Date filter
          if (_shiftSelectedDate != null) {
            final targetYmd = DateFormat('yyyy-MM-dd').format(_shiftSelectedDate!);
            final busDateMatches = s.businessDate.trim() == targetYmd;
            final startMatches = s.startTime.startsWith(targetYmd);
            bool parsedMatches = false;
            final parsed = DateTime.tryParse(s.businessDate) ?? DateTime.tryParse(s.startTime);
            if (parsed != null) {
              parsedMatches = parsed.year == _shiftSelectedDate!.year &&
                  parsed.month == _shiftSelectedDate!.month &&
                  parsed.day == _shiftSelectedDate!.day;
            }
            if (!busDateMatches && !startMatches && !parsedMatches) {
              return false;
            }
          }

          // Search text query
          final q = _shiftSearchQuery.trim().toLowerCase();
          if (q.isNotEmpty) {
            final nameMatch = s.sessionName.toLowerCase().contains(q);
            final dateMatch = s.businessDate.toLowerCase().contains(q);
            final notesMatch = (s.notes ?? '').toLowerCase().contains(q);
            final startMatch = s.startTimeFormatted.toLowerCase().contains(q);
            final endMatch = s.endTimeFormatted.toLowerCase().contains(q);

            bool humanDateMatch = false;
            final parsed = DateTime.tryParse(s.businessDate) ?? DateTime.tryParse(s.startTime);
            if (parsed != null) {
              try {
                final d1 = DateFormat('dd-MM-yyyy').format(parsed).toLowerCase();
                final d2 = DateFormat('dd/MM/yyyy').format(parsed).toLowerCase();
                final d3 = DateFormat('MM/dd/yyyy').format(parsed).toLowerCase();
                final d4 = DateFormat('d MMM yyyy').format(parsed).toLowerCase();
                final d5 = DateFormat('d MMMM yyyy').format(parsed).toLowerCase();
                final d6 = DateFormat('MMMM yyyy').format(parsed).toLowerCase();
                final d7 = DateFormat('EEEE').format(parsed).toLowerCase();
                final d8 = DateFormat('yyyy/MM/dd').format(parsed).toLowerCase();
                if (d1.contains(q) ||
                    d2.contains(q) ||
                    d3.contains(q) ||
                    d4.contains(q) ||
                    d5.contains(q) ||
                    d6.contains(q) ||
                    d7.contains(q) ||
                    d8.contains(q)) {
                  humanDateMatch = true;
                }
              } catch (_) {}
            }

            if (!nameMatch && !dateMatch && !notesMatch && !startMatch && !endMatch && !humanDateMatch) {
              return false;
            }
          }

          return true;
        }).toList();

        final activeCount = allSessions.where((s) => s.isActive).length;
        final closedCount = allSessions.where((s) => s.isClosed).length;
        final isFiltered = _shiftSelectedDate != null ||
            _shiftSearchQuery.trim().isNotEmpty ||
            _shiftStatusFilter != 'ALL';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Active Shift Live Banner (Zero-Overflow Guaranteed via LayoutBuilder)
            if (active != null) ...[
              _buildActiveShiftBanner(active, currency),
              const SizedBox(height: 16),
            ],

            // Shifts Overview Stats Row (Responsive)
            _buildOverallShiftStats(
              filteredSessions,
              currency,
              isFiltered: isFiltered,
              totalAllCount: allSessions.length,
            ),
            const SizedBox(height: 16),

            // Shift Search & Date Filters Bar
            _buildShiftSearchBar(
              context,
              allSessions.length,
              activeCount,
              closedCount,
              isFiltered,
              filteredSessions.length,
            ),
            const SizedBox(height: 16),

            // Shift Sessions List
            Expanded(
              child: allSessions.isEmpty
                  ? _buildEmptyInitialShiftsState()
                  : filteredSessions.isEmpty
                      ? _buildEmptyFilteredShiftsState()
                      : ListView.separated(
                          itemCount: filteredSessions.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final s = filteredSessions[index];
                            return _buildShiftCard(s, currency);
                          },
                        ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickShiftDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _shiftSelectedDate ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _shiftSelectedDate = picked;
        _shiftDateQuickFilter = 'CUSTOM';
      });
    }
  }

  void _resetShiftFilters() {
    setState(() {
      _shiftSearchController.clear();
      _shiftSearchQuery = '';
      _shiftSelectedDate = null;
      _shiftDateQuickFilter = 'ALL';
      _shiftStatusFilter = 'ALL';
    });
  }

  Widget _buildEmptyInitialShiftsState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_rounded, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            const Text(
              'No Daily Sale Shifts Recorded Yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Click "Start Sale" when the cafe opens (e.g. at 5:00 PM) to record sales,\ntrack opening cash for change, and anchor all cross-midnight sales to today\'s business date.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
              icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
              label: const Text('Start First Sale Shift', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () => SaleSessionDialogs.showStartSaleDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyFilteredShiftsState() {
    String dateDesc = '';
    if (_shiftSelectedDate != null) {
      dateDesc = DateFormat('yyyy-MM-dd').format(_shiftSelectedDate!);
    } else if (_shiftSearchQuery.isNotEmpty) {
      dateDesc = '"$_shiftSearchQuery"';
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy_rounded, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            const Text(
              'No Daily Sale Shifts Found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              dateDesc.isNotEmpty
                  ? 'No sale shifts match the date or search query $dateDesc.'
                  : 'No sale shifts match the current search and filter criteria.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
              label: const Text('Reset Date & Filters', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: _resetShiftFilters,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftSearchBar(
    BuildContext context,
    int totalCount,
    int activeCount,
    int closedCount,
    bool isFiltered,
    int filteredCount,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 900;

        // Date & Status Chips
        final filterChips = Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Status Chips
            ChoiceChip(
              label: Text('All ($totalCount)'),
              selected: _shiftStatusFilter == 'ALL',
              onSelected: (_) => setState(() => _shiftStatusFilter = 'ALL'),
            ),
            ChoiceChip(
              avatar: Icon(
                Icons.play_circle_filled_rounded,
                size: 15,
                color: _shiftStatusFilter == 'ACTIVE' ? Colors.white : Colors.green.shade800,
              ),
              label: Text(
                'Active ($activeCount)',
                style: TextStyle(
                  color: _shiftStatusFilter == 'ACTIVE' ? Colors.white : Colors.green.shade900,
                  fontWeight: FontWeight.bold,
                ),
              ),
              selected: _shiftStatusFilter == 'ACTIVE',
              selectedColor: Colors.green.shade700,
              backgroundColor: Colors.green.shade50,
              onSelected: (_) => setState(() => _shiftStatusFilter = 'ACTIVE'),
            ),
            ChoiceChip(
              avatar: Icon(
                Icons.check_circle_outline_rounded,
                size: 15,
                color: _shiftStatusFilter == 'CLOSED' ? Colors.white : Colors.grey.shade700,
              ),
              label: Text(
                'Closed ($closedCount)',
                style: TextStyle(
                  color: _shiftStatusFilter == 'CLOSED' ? Colors.white : Colors.grey.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
              selected: _shiftStatusFilter == 'CLOSED',
              selectedColor: Colors.grey.shade700,
              backgroundColor: Colors.grey.shade100,
              onSelected: (_) => setState(() => _shiftStatusFilter = 'CLOSED'),
            ),

            const SizedBox(width: 4),

            // Date Quick Filter: Today
            ActionChip(
              avatar: Icon(Icons.today_rounded, size: 15, color: AppColors.primary),
              label: const Text('Today'),
              backgroundColor: _shiftDateQuickFilter == 'TODAY'
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : Colors.grey.shade100,
              side: BorderSide(
                color: _shiftDateQuickFilter == 'TODAY' ? AppColors.primary : AppColors.border,
                width: _shiftDateQuickFilter == 'TODAY' ? 1.5 : 1,
              ),
              onPressed: () {
                setState(() {
                  _shiftSelectedDate = DateTime.now();
                  _shiftDateQuickFilter = 'TODAY';
                });
              },
            ),

            // Date Quick Filter: Yesterday
            ActionChip(
              avatar: Icon(Icons.history_toggle_off_rounded, size: 15, color: AppColors.primary),
              label: const Text('Yesterday'),
              backgroundColor: _shiftDateQuickFilter == 'YESTERDAY'
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : Colors.grey.shade100,
              side: BorderSide(
                color: _shiftDateQuickFilter == 'YESTERDAY' ? AppColors.primary : AppColors.border,
                width: _shiftDateQuickFilter == 'YESTERDAY' ? 1.5 : 1,
              ),
              onPressed: () {
                setState(() {
                  _shiftSelectedDate = DateTime.now().subtract(const Duration(days: 1));
                  _shiftDateQuickFilter = 'YESTERDAY';
                });
              },
            ),

            // Date Picker Chip
            if (_shiftSelectedDate != null)
              InputChip(
                avatar: const Icon(Icons.event_available_rounded, size: 15, color: Colors.white),
                label: Text(
                  DateFormat('dd MMM yyyy').format(_shiftSelectedDate!),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                backgroundColor: AppColors.primary,
                deleteIconColor: Colors.white70,
                onDeleted: () {
                  setState(() {
                    _shiftSelectedDate = null;
                    _shiftDateQuickFilter = 'ALL';
                  });
                },
                onPressed: () => _pickShiftDate(context),
              )
            else
              ActionChip(
                avatar: Icon(Icons.calendar_month_rounded, size: 15, color: AppColors.primary),
                label: const Text('Select Date...'),
                backgroundColor: Colors.grey.shade100,
                side: BorderSide(color: AppColors.border),
                onPressed: () => _pickShiftDate(context),
              ),

            // Reset filters button
            if (isFiltered)
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                label: const Text('Reset', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: _resetShiftFilters,
              ),
          ],
        );

        // Search Input Field
        final searchField = TextField(
          controller: _shiftSearchController,
          onChanged: (val) => setState(() => _shiftSearchQuery = val),
          decoration: InputDecoration(
            hintText: 'Search shifts by date (YYYY-MM-DD), name, notes...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: (_shiftSearchQuery.isNotEmpty || _shiftSelectedDate != null)
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    tooltip: 'Clear search',
                    onPressed: _resetShiftFilters,
                  )
                : null,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isNarrow) ...[
              filterChips,
              const SizedBox(height: 10),
              searchField,
            ] else ...[
              Row(
                children: [
                  Expanded(flex: 3, child: filterChips),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: searchField),
                ],
              ),
            ],
            if (isFiltered) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Showing $filteredCount of $totalCount shifts',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                  if (_shiftSelectedDate != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Date: ${DateFormat('yyyy-MM-dd').format(_shiftSelectedDate!)}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                  ],
                  const Spacer(),
                  InkWell(
                    onTap: _resetShiftFilters,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.clear_all_rounded, size: 14, color: AppColors.error),
                          SizedBox(width: 4),
                          Text('Clear Filters', style: TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildActiveShiftBanner(SaleSessionModel active, String currency) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1050;

        final leftInfo = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.timer_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'ACTIVE SHIFT: ${active.sessionName}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'OPEN / IN PROGRESS',
                          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Started at ${active.startTimeFormatted}  |  Business Date: ${active.businessDate}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        );

        final statsList = Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: isWide ? WrapAlignment.end : WrapAlignment.start,
          children: [
            _buildLiveBannerStat('Opening Float', '$currency ${active.openingCash.toStringAsFixed(0)}'),
            _buildLiveBannerStat('Shift Sales', '$currency ${active.totalSales.toStringAsFixed(0)}'),
            _buildLiveBannerStat('Total Counter Money', '$currency ${active.totalCounterCash.toStringAsFixed(0)}', isHighlight: true),
            _buildLiveBannerStat('Shift Expenses', '- $currency ${active.totalExpenses.toStringAsFixed(0)}'),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.stop_circle_rounded, size: 18),
              label: const Text('End Sale Shift', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
              onPressed: () => SaleSessionDialogs.showEndSaleDialog(context),
            ),
          ],
        );

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.green.shade800,
                Colors.teal.shade700,
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: isWide
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(flex: 4, child: leftInfo),
                    const SizedBox(width: 16),
                    Expanded(flex: 7, child: statsList),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    leftInfo,
                    const SizedBox(height: 12),
                    const Divider(color: Colors.white24, height: 1),
                    const SizedBox(height: 12),
                    statsList,
                  ],
                ),
        );
      },
    );
  }

  Widget _buildLiveBannerStat(String label, String value, {bool isHighlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isHighlight ? Colors.white : Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isHighlight ? Colors.green.shade900 : Colors.white70,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: isHighlight ? Colors.green.shade900 : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallShiftStats(
    List<SaleSessionModel> sessions,
    String currency, {
    bool isFiltered = false,
    int totalAllCount = 0,
  }) {
    final totalRevenue = sessions.fold(0.0, (sum, s) => sum + s.totalSales);
    final totalExpenses = sessions.fold(0.0, (sum, s) => sum + s.totalExpenses);
    final netProfit = totalRevenue - totalExpenses;

    final profitTitle = isFiltered ? 'Filtered Shift Profit' : 'Overall Shift Profit';
    final countTitle = isFiltered ? 'Filtered Shifts' : 'Total Shifts Recorded';
    final countSubtitle = isFiltered
        ? '${sessions.length} of $totalAllCount Shifts ($currency ${totalRevenue.toStringAsFixed(0)})'
        : '${sessions.length} Shifts ($currency ${totalRevenue.toStringAsFixed(0)})';

    return Consumer<DashboardProvider>(
      builder: (context, dashboard, _) {
        final cards = [
          _buildStatCard('Weekly Sales', '$currency ${dashboard.weeklySales.toStringAsFixed(0)}', Icons.date_range_rounded, AppColors.info),
          _buildStatCard('Monthly Sales', '$currency ${dashboard.monthlySales.toStringAsFixed(0)}', Icons.calendar_month_rounded, AppColors.secondary),
          _buildStatCard(
            profitTitle,
            '$currency ${netProfit.toStringAsFixed(0)}',
            Icons.trending_up_rounded,
            netProfit >= 0 ? Colors.green.shade700 : AppColors.error,
          ),
          _buildStatCard(
            countTitle,
            countSubtitle,
            Icons.history_rounded,
            AppColors.primary,
          ),
        ];

        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 800) {
              return Column(
                children: [
                  Row(children: [cards[0], const SizedBox(width: 10), cards[1]]),
                  const SizedBox(height: 10),
                  Row(children: [cards[2], const SizedBox(width: 10), cards[3]]),
                ],
              );
            }
            return Row(
              children: [
                cards[0],
                const SizedBox(width: 10),
                cards[1],
                const SizedBox(width: 10),
                cards[2],
                const SizedBox(width: 10),
                cards[3],
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftCard(SaleSessionModel s, String currency) {
    final settings = Provider.of<SettingsProvider>(context, listen: false).settings;

    return InkWell(
      onTap: () => DailySaleDetailDialog.show(context, s),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: s.isActive ? Colors.green.shade400 : AppColors.border,
            width: s.isActive ? 1.5 : 1,
          ),
          boxShadow: s.isActive
              ? [
                  BoxShadow(
                    color: Colors.green.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Shift Title, Timing & Status (Responsive)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: s.isActive
                              ? Colors.green.withValues(alpha: 0.12)
                              : AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          s.isActive ? Icons.storefront_rounded : Icons.history_rounded,
                          color: s.isActive ? Colors.green : AppColors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  s.sessionName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: s.isActive
                                        ? Colors.green.withValues(alpha: 0.15)
                                        : Colors.grey.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: s.isActive ? Colors.green : Colors.grey,
                                      width: 0.6,
                                    ),
                                  ),
                                  child: Text(
                                    s.isActive ? '🟢 ACTIVE' : '⚪ CLOSED',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: s.isActive ? Colors.green.shade800 : Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Business Date: ${s.businessDate}  |  Started: ${s.startTimeFormatted}  ${s.endTime != null ? '-> Ended: ${s.endTimeFormatted}' : '-> Currently Active'}',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.receipt_long_rounded, size: 16),
                      label: const Text('View All Invoices & Detail', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () => DailySaleDetailDialog.show(context, s),
                    ),
                    if (s.isActive)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.stop_circle_rounded, size: 16),
                        label: const Text('End Sale', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () => SaleSessionDialogs.showEndSaleDialog(context),
                      )
                    else
                      IconButton(
                        icon: Icon(Icons.print_rounded, color: AppColors.primary, size: 20),
                        tooltip: 'Print Z-Report Thermal Slip',
                        onPressed: () => SaleSessionDialogs.printShiftZReport(
                          session: s,
                          currency: currency,
                          cafeName: settings.cafeName,
                        ),
                      ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Row 2: Financial Breakdown Tiles (Responsive 1-row or 2-row Layout)
            LayoutBuilder(
              builder: (context, constraints) {
                final tile1 = _buildShiftMetricTile(
                  'Opening Cash (Float)',
                  '$currency ${s.openingCash.toStringAsFixed(0)}',
                  subtitle: 'Counter change',
                  icon: Icons.account_balance_wallet_outlined,
                  color: Colors.blue.shade700,
                  bgColor: Colors.blue.shade50,
                );
                final tile2 = _buildShiftMetricTile(
                  'Cash Sales',
                  '$currency ${s.cashSales.toStringAsFixed(0)}',
                  subtitle: 'Cash collected',
                  icon: Icons.payments_outlined,
                  color: Colors.teal.shade700,
                  bgColor: Colors.teal.shade50,
                );
                final tile3 = _buildShiftMetricTile(
                  'TOTAL COUNTER CASH',
                  '$currency ${s.totalCounterCash.toStringAsFixed(0)}',
                  subtitle: 'Opening + Cash Sales',
                  icon: Icons.savings_outlined,
                  color: Colors.green.shade900,
                  bgColor: Colors.green.shade100,
                  isHighlight: true,
                );
                final tile4 = _buildShiftMetricTile(
                  'Total Sales Revenue',
                  '$currency ${s.totalSales.toStringAsFixed(0)}',
                  subtitle: 'All payment methods',
                  icon: Icons.point_of_sale_rounded,
                  color: AppColors.primary,
                  bgColor: AppColors.primary.withValues(alpha: 0.08),
                );
                final tile5 = _buildShiftMetricTile(
                  'Total Expenses',
                  '$currency ${s.totalExpenses.toStringAsFixed(0)}',
                  subtitle: 'Paid from shift',
                  icon: Icons.money_off_rounded,
                  color: AppColors.error,
                  bgColor: Colors.red.shade50,
                );
                final tile6 = _buildShiftMetricTile(
                  'Net Shift Profit',
                  '$currency ${s.netProfit.toStringAsFixed(0)}',
                  subtitle: 'Sales - Expenses',
                  icon: Icons.trending_up_rounded,
                  color: s.netProfit >= 0 ? Colors.green.shade800 : AppColors.error,
                  bgColor: s.netProfit >= 0 ? Colors.green.shade50 : Colors.red.shade50,
                );

                if (constraints.maxWidth < 920) {
                  return Column(
                    children: [
                      Row(children: [tile1, const SizedBox(width: 8), tile2, const SizedBox(width: 8), tile3]),
                      const SizedBox(height: 8),
                      Row(children: [tile4, const SizedBox(width: 8), tile5, const SizedBox(width: 8), tile6]),
                    ],
                  );
                }

                return Row(
                  children: [
                    tile1,
                    const SizedBox(width: 8),
                    tile2,
                    const SizedBox(width: 8),
                    tile3,
                    const SizedBox(width: 8),
                    tile4,
                    const SizedBox(width: 8),
                    tile5,
                    const SizedBox(width: 8),
                    tile6,
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftMetricTile(
    String label,
    String value, {
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
    bool isHighlight = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isHighlight ? color : color.withValues(alpha: 0.3),
            width: isHighlight ? 1.5 : 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isHighlight ? FontWeight.w900 : FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                color: color.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}