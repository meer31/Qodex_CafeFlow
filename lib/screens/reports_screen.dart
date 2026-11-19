import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../models/sale_model.dart';
import '../models/expense_model.dart';
import '../repositories/sale_repository.dart';
import '../repositories/expense_repository.dart';
import '../providers/settings_provider.dart';
import '../services/report_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final SaleRepository _saleRepo = SaleRepository();
  final ExpenseRepository _expenseRepo = ExpenseRepository();

  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  bool _isLoading = false;
  bool _isExporting = false;
  double _totalRevenue = 0.0;
  double _totalCost = 0.0;
  double _totalExpenses = 0.0;
  List<SaleModel> _reportSales = [];
  List<ExpenseModel> _reportExpenses = [];

  @override
  void initState() {
    super.initState();
    _generateReport();
  }

  DateTime get _monthStart => DateTime(_selectedYear, _selectedMonth, 1);
  DateTime get _monthEnd {
    final nextMonth = _selectedMonth == 12
        ? DateTime(_selectedYear + 1, 1, 1)
        : DateTime(_selectedYear, _selectedMonth + 1, 1);
    return nextMonth.subtract(const Duration(seconds: 1));
  }

  Future<void> _generateReport() async {
    setState(() => _isLoading = true);

    _reportSales = await _saleRepo.getSalesByDateRange(_monthStart, _monthEnd);
    _reportExpenses = await _expenseRepo.getExpensesByDateRange(_monthStart, _monthEnd);

    final clearedSales = _reportSales.where((s) => s.isCleared).toList();
    _totalRevenue = clearedSales.fold(0.0, (sum, s) => sum + s.grandTotal);
    _totalCost = clearedSales.fold(0.0, (sum, s) => sum + s.totalCost);
    _totalExpenses = _reportExpenses.fold(0.0, (sum, e) => sum + e.amount);

    setState(() => _isLoading = false);
  }

  Future<void> _exportMonthlyReport() async {
    setState(() => _isExporting = true);

    try {
      final settings = Provider.of<SettingsProvider>(context, listen: false).settings;
      await ReportService.printMonthlyReport(
        settings: settings,
        year: _selectedYear,
        month: _selectedMonth,
        sales: _reportSales,
        expenses: _reportExpenses,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting report: ${e.toString()}'), backgroundColor: AppColors.error),
        );
      }
    }

    setState(() => _isExporting = false);
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context).settings;
    final currency = settings.currencySymbol;
    final double grossProfit = _totalRevenue - _totalCost;
    final double netProfit = grossProfit - _totalExpenses;

    final monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 700;
        final padding = isNarrow ? 12.0 : 24.0;

        return Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Responsive Header ──
              if (isNarrow)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Monthly Reports & Analytics',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Sales, expenses, and profit analysis',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded),
                          tooltip: 'Refresh Report Data',
                          onPressed: _generateReport,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            icon: _isExporting
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.picture_as_pdf_rounded, size: 18),
                            label: Text(
                              _isExporting ? 'Generating...' : 'Export PDF Report',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            onPressed: _isExporting ? null : _exportMonthlyReport,
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Monthly Reports & Analytics',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Generate monthly financial reports with sales, expenses, and profit analysis',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded),
                          tooltip: 'Refresh Report Data',
                          onPressed: _generateReport,
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          icon: _isExporting
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.picture_as_pdf_rounded),
                          label: Text(_isExporting ? 'Generating...' : 'Export Monthly PDF Report'),
                          onPressed: _isExporting ? null : _exportMonthlyReport,
                        ),
                      ],
                    ),
                  ],
                ),
              const SizedBox(height: 16),

              // ── Responsive Month/Year Selector ──
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                  border: Border.all(color: AppColors.border),
                ),
                child: LayoutBuilder(
                  builder: (context, filterConstraints) {
                    final isFilterNarrow = filterConstraints.maxWidth < 600;

                    if (isFilterNarrow) {
                      return Column(
                        children: [
                          Row(
                            children: [
                              // Month Picker
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  initialValue: _selectedMonth,
                                  decoration: const InputDecoration(
                                    labelText: 'Month',
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  items: List.generate(12, (i) => i + 1)
                                      .map((m) => DropdownMenuItem(value: m, child: Text(monthNames[m - 1], style: const TextStyle(fontSize: 13))))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedMonth = val);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Year Picker
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  initialValue: _selectedYear,
                                  decoration: const InputDecoration(
                                    labelText: 'Year',
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  items: List.generate(5, (i) => DateTime.now().year - 2 + i)
                                      .map((y) => DropdownMenuItem(value: y, child: Text('$y', style: const TextStyle(fontSize: 13))))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedYear = val);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 40,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.filter_alt_rounded, size: 18),
                              label: const Text('Generate Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              onPressed: _generateReport,
                            ),
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        // Month Picker
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: _selectedMonth,
                            decoration: const InputDecoration(labelText: 'Month'),
                            items: List.generate(12, (i) => i + 1)
                                .map((m) => DropdownMenuItem(value: m, child: Text(monthNames[m - 1])))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedMonth = val);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Year Picker
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: _selectedYear,
                            decoration: const InputDecoration(labelText: 'Year'),
                            items: List.generate(5, (i) => DateTime.now().year - 2 + i)
                                .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedYear = val);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 16),

                        ElevatedButton.icon(
                          icon: const Icon(Icons.filter_alt_rounded),
                          label: const Text('Generate Report'),
                          onPressed: _generateReport,
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // ── Responsive Summary Financial KPI Header ──
              LayoutBuilder(
                builder: (context, kpiConstraints) {
                  final width = kpiConstraints.maxWidth;
                  final cols = width < 550 ? 2 : (width < 950 ? 3 : 5);
                  final tileWidth = (width - ((cols - 1) * 12)) / cols;

                  final tiles = [
                    _buildSummaryTile('TOTAL REVENUE', '$currency ${_totalRevenue.toStringAsFixed(2)}', AppColors.primary),
                    _buildSummaryTile('COST OF GOODS', '$currency ${_totalCost.toStringAsFixed(2)}', AppColors.secondary),
                    _buildSummaryTile('EXPENSES', '$currency ${_totalExpenses.toStringAsFixed(2)}', AppColors.error),
                    _buildSummaryTile('GROSS PROFIT', '$currency ${grossProfit.toStringAsFixed(2)}', grossProfit >= 0 ? AppColors.accent : AppColors.error),
                    _buildSummaryTile('NET PROFIT', '$currency ${netProfit.toStringAsFixed(2)}', netProfit >= 0 ? AppColors.accent : AppColors.error),
                  ];

                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: tiles.map((t) => SizedBox(width: tileWidth, child: t)).toList(),
                  );
                },
              ),
              const SizedBox(height: 16),

              // ── Report Data Table (Dual Scroll) ──
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.cardBg,
                          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: _reportSales.isEmpty
                            ? Center(child: Text('No sales records for ${monthNames[_selectedMonth - 1]} $_selectedYear'))
                            : LayoutBuilder(
                                builder: (context, tableConstraints) {
                                  return SingleChildScrollView(
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(minWidth: tableConstraints.maxWidth),
                                        child: DataTable(
                                          columnSpacing: 20,
                                          headingRowHeight: 44,
                                          columns: const [
                                            DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Invoice #', style: TextStyle(fontWeight: FontWeight.bold))))),
                                            DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))))),
                                            DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Table', style: TextStyle(fontWeight: FontWeight.bold))))),
                                            DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Waiter', style: TextStyle(fontWeight: FontWeight.bold))))),
                                            DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Subtotal', style: TextStyle(fontWeight: FontWeight.bold))))),
                                            DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Discount', style: TextStyle(fontWeight: FontWeight.bold))))),
                                            DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Grand Total', style: TextStyle(fontWeight: FontWeight.bold))))),
                                            DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Est. Profit', style: TextStyle(fontWeight: FontWeight.bold))))),
                                          ],
                                          rows: _reportSales.map((s) {
                                            return DataRow(cells: [
                                              DataCell(Text('#${s.invoiceNumber}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.primary))),
                                              DataCell(Text(s.dateTime.split('T').first)),
                                              DataCell(Text(s.tableName ?? 'Takeaway')),
                                              DataCell(Text(s.waiterName ?? '-')),
                                              DataCell(Text('$currency ${s.subtotal.toStringAsFixed(0)}')),
                                              DataCell(Text('$currency ${s.discount.toStringAsFixed(0)}')),
                                              DataCell(Text('$currency ${s.grandTotal.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold))),
                                              DataCell(Text('$currency ${s.profit.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.bold, color: s.profit >= 0 ? AppColors.accent : AppColors.error))),
                                            ]);
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryTile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color)),
          ),
        ],
      ),
    );
  }
}