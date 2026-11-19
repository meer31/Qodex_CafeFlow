import 'package:flutter/material.dart';
import '../models/sale_model.dart';
import '../models/sale_session_model.dart';
import '../models/stock_item_model.dart';
import '../repositories/sale_repository.dart';
import '../repositories/sale_session_repository.dart';
import '../repositories/stock_repository.dart';
import '../repositories/expense_repository.dart';
import '../repositories/table_repository.dart';

class ChartDataPoint {
  final String label;
  final double value;

  ChartDataPoint(this.label, this.value);
}

class DashboardProvider with ChangeNotifier {
  final SaleRepository _saleRepository = SaleRepository();
  final SaleSessionRepository _sessionRepository = SaleSessionRepository();
  final StockRepository _stockRepository = StockRepository();
  final ExpenseRepository _expenseRepository = ExpenseRepository();
  final TableRepository _tableRepository = TableRepository();

  bool _isLoading = false;

  SaleSessionModel? _activeSession;

  double _todaySales = 0.0;
  double _todayExpenses = 0.0;
  double _todayProfit = 0.0;
  double _weeklySales = 0.0;
  double _monthlySales = 0.0;
  double _monthlyExpenses = 0.0;
  double _monthlyProfit = 0.0;

  double _todayRemainingSales = 0.0;
  int _todayRemainingCount = 0;
  double _totalRemainingSales = 0.0;
  int _totalRemainingCount = 0;

  int _activeTablesCount = 0;
  List<StockItemModel> _lowStockAlerts = [];
  List<SaleModel> _recentInvoices = [];
  List<Map<String, dynamic>> _topSellingItems = [];

  List<ChartDataPoint> _dailySalesChart = [];
  final List<ChartDataPoint> _weeklySalesChart = [];
  final List<ChartDataPoint> _monthlySalesChart = [];

  bool get isLoading => _isLoading;

  SaleSessionModel? get activeSession => _activeSession;
  bool get hasActiveShift => _activeSession != null;
  double get activeShiftSales => _activeSession?.totalSales ?? 0.0;
  double get activeShiftExpenses => _activeSession?.totalExpenses ?? 0.0;
  double get activeCounterCash => _activeSession?.totalCounterCash ?? 0.0;
  double get activeOpeningCash => _activeSession?.openingCash ?? 0.0;

  double get todaySales => _todaySales;
  double get todayExpenses => _todayExpenses;
  double get todayProfit => _todayProfit;
  double get weeklySales => _weeklySales;
  double get monthlySales => _monthlySales;
  double get monthlyExpenses => _monthlyExpenses;
  double get monthlyProfit => _monthlyProfit;

  double get todayRemainingSales => _todayRemainingSales;
  int get todayRemainingCount => _todayRemainingCount;
  double get totalRemainingSales => _totalRemainingSales;
  int get totalRemainingCount => _totalRemainingCount;

  int get activeTablesCount => _activeTablesCount;
  List<StockItemModel> get lowStockAlerts => _lowStockAlerts;
  List<SaleModel> get recentInvoices => _recentInvoices;
  List<Map<String, dynamic>> get topSellingItems => _topSellingItems;

  List<ChartDataPoint> get dailySalesChart => _dailySalesChart;
  List<ChartDataPoint> get weeklySalesChart => _weeklySalesChart;
  List<ChartDataPoint> get monthlySalesChart => _monthlySalesChart;

  DashboardProvider() {
    loadDashboardData();
  }

  Future<void> loadDashboardData() async {
    _isLoading = true;
    notifyListeners();

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    // Fetch Sales (all non-cancelled)
    final todaySalesList = await _saleRepository.getSalesByDateRange(todayStart, todayEnd);
    final weeklySalesList = await _saleRepository.getSalesByDateRange(weekStart, todayEnd);
    final monthlySalesList = await _saleRepository.getSalesByDateRange(monthStart, todayEnd);
    final allRecentInvoices = await _saleRepository.getAllSales(limit: 10);
    final allRemainingSales = await _saleRepository.getRemainingSales();

    // 1. Fetch Active Shift Session
    final activeSession = await _sessionRepository.getActiveSession();
    _activeSession = activeSession;

    // Fetch Expenses
    final expenses = await _expenseRepository.getAllExpenses();
    final monthStartIso = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    _monthlyExpenses = expenses
        .where((e) => e.dateTime.startsWith(monthStartIso))
        .fold(0.0, (sum, e) => sum + e.amount);

    // Cleared Sales (Completed/Paid) update Weekly and Monthly metrics for Sales & Invoices screen
    _weeklySales = weeklySalesList.where((s) => s.isCleared).fold(0.0, (sum, s) => sum + s.grandTotal);
    _monthlySales = monthlySalesList.where((s) => s.isCleared).fold(0.0, (sum, s) => sum + s.grandTotal);
    _monthlyProfit = _monthlySales - _monthlyExpenses;

    // ACTIVE SHIFT SALES & EXPENSES:
    // Dashboard strictly shows the Total Sale and Total Expense of the active shift session.
    // Must NOT show all-time sales or split cross-midnight shifts by calendar day.
    if (_activeSession != null) {
      _todaySales = _activeSession!.totalSales;
      _todayExpenses = _activeSession!.totalExpenses;
      _todayProfit = _activeSession!.netProfit;
    } else {
      _todaySales = 0.0;
      _todayExpenses = 0.0;
      _todayProfit = 0.0;
    }

    // Remaining / Delayed Sales metrics
    _todayRemainingSales = todaySalesList.where((s) => s.isRemaining).fold(0.0, (sum, s) => sum + s.grandTotal);
    _todayRemainingCount = todaySalesList.where((s) => s.isRemaining).length;
    _totalRemainingSales = allRemainingSales.fold(0.0, (sum, s) => sum + s.grandTotal);
    _totalRemainingCount = allRemainingSales.length;

    // Fetch Active Tables
    final tables = await _tableRepository.getAllTables();
    _activeTablesCount = tables.where((t) => t.status == 'Occupied').length;

    // Fetch Low Stock
    _lowStockAlerts = await _stockRepository.getLowStockItems();

    _recentInvoices = allRecentInvoices;

    // Calculate Top Selling Items: strictly showing items of the active shift with number of sold items
    if (_activeSession != null && _activeSession!.id != null) {
      final shiftSoldItems = await _sessionRepository.getSessionSoldItems(_activeSession!.id!);
      _topSellingItems = shiftSoldItems.take(10).map((e) => {
        'name': e.productName,
        'qty': e.quantity,
        'unit_price': e.unitPrice,
        'total_revenue': e.totalRevenue,
      }).toList();
    } else {
      _topSellingItems = [];
    }

    // Prepare Daily Chart (Last 7 Days) with Cleared Sales
    _dailySalesChart = [];
    for (int i = 6; i >= 0; i--) {
      final day = todayStart.subtract(Duration(days: i));
      final dayEnd = DateTime(day.year, day.month, day.day, 23, 59, 59);
      final daySales = await _saleRepository.getSalesByDateRange(day, dayEnd);
      final total = daySales.where((s) => s.isCleared).fold(0.0, (sum, s) => sum + s.grandTotal);
      final dayLabel = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day.weekday - 1];
      _dailySalesChart.add(ChartDataPoint(dayLabel, total));
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> clearBill(int saleId, {String? paymentMethod}) async {
    await _saleRepository.clearBill(saleId, paymentMethod: paymentMethod);
    await loadDashboardData();
  }

  Future<void> markBillAsRemaining(int saleId) async {
    await _saleRepository.markBillAsRemaining(saleId);
    await loadDashboardData();
  }

  Future<void> deleteSale(int saleId) async {
    await _saleRepository.deleteSale(saleId);
    await loadDashboardData();
  }

  Future<void> updateSale(SaleModel sale, {String? oldInvoiceNumber}) async {
    await _saleRepository.updateSale(sale, oldInvoiceNumber: oldInvoiceNumber);
    await loadDashboardData();
  }
}
