import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../models/category_model.dart';
import '../models/sale_model.dart';
import '../providers/settings_provider.dart';
import '../services/report_center_service.dart';
import '../services/report_service.dart';
import '../widgets/invoice_dialogs.dart';

class ReportCenterScreen extends StatefulWidget {
  const ReportCenterScreen({super.key});

  @override
  State<ReportCenterScreen> createState() => _ReportCenterScreenState();
}

class _ReportCenterScreenState extends State<ReportCenterScreen> with SingleTickerProviderStateMixin {
  final ReportCenterService _service = ReportCenterService();

  ReportFilterType _currentFilter = ReportFilterType.thisMonth;
  DateTime? _specificDate;
  int? _specificMonth;
  int? _specificYear;

  bool _isLoading = true;
  String? _errorMessage;
  ReportCenterData? _reportData;

  late TabController _tabController;

  // Search filters
  String _salesSearchQuery = '';
  String _itemsSearchQuery = '';
  String _stockSearchQuery = '';
  String _salesStatusFilter = 'ALL'; // ALL, CLEARED, REMAINING

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    final now = DateTime.now();
    _specificDate = now;
    _specificMonth = now.month;
    _specificYear = now.year;
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _service.loadReportData(
        filterType: _currentFilter,
        specificDate: _specificDate,
        specificMonth: _specificMonth,
        specificYear: _specificYear,
      );

      if (mounted) {
        setState(() {
          _reportData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickSpecificDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _specificDate ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
              brightness: Theme.of(context).brightness,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _specificDate = picked;
        _currentFilter = ReportFilterType.specificDate;
      });
      _loadData();
    }
  }

  Future<void> _pickSpecificMonth() async {
    final now = DateTime.now();
    int selectedM = _specificMonth ?? now.month;
    int selectedY = _specificYear ?? now.year;

    final monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.cardBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.calendar_month_rounded, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Text('Select Specific Month', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 340,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Year selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Year:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_left_rounded, size: 28),
                              onPressed: () => setDialogState(() => selectedY--),
                            ),
                            Text('$selectedY', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.arrow_right_rounded, size: 28),
                              onPressed: () => setDialogState(() => selectedY++),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    // Month Grid
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(12, (index) {
                        final mNum = index + 1;
                        final isSel = selectedM == mNum;
                        return ChoiceChip(
                          selected: isSel,
                          selectedColor: AppColors.primary,
                          backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          label: Text(
                            monthNames[index].substring(0, 3),
                            style: TextStyle(
                              color: isSel ? Colors.white : AppColors.textPrimary,
                              fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          onSelected: (val) {
                            if (val) setDialogState(() => selectedM = mNum);
                          },
                        );
                      }),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _specificMonth = selectedM;
                      _specificYear = selectedY;
                      _currentFilter = ReportFilterType.specificMonth;
                    });
                    _loadData();
                  },
                  child: const Text('Apply Filter'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCategoryReportModal([int? preSelectedCategoryId]) {
    if (_reportData == null || _reportData!.allCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No categories available to report on.')),
      );
      return;
    }

    int activeCatId = preSelectedCategoryId ?? _reportData!.allCategories.first.id!;
    bool isGeneratingPdf = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final settings = Provider.of<SettingsProvider>(context, listen: false).settings;
            final currency = settings.currencySymbol;

            return FutureBuilder(
              future: _service.getCategoryReportDetail(
                categoryId: activeCatId,
                data: _reportData!,
              ),
              builder: (context, snapshot) {
                final detail = snapshot.data;
                final isLoadingDetail = snapshot.connectionState == ConnectionState.waiting;

                return AlertDialog(
                  backgroundColor: AppColors.cardBg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  actionsPadding: const EdgeInsets.all(16),
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.summarize_rounded, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Category Performance Report', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                            Text('Filter: ${_reportData!.filterLabel}', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  content: SizedBox(
                    width: 650,
                    height: 520,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category Selector Dropdown
                        Row(
                          children: [
                            const Text('Select Category: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.border),
                                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: activeCatId,
                                    isExpanded: true,
                                    items: _reportData!.allCategories.map((c) {
                                      return DropdownMenuItem<int>(
                                        value: c.id,
                                        child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                      );
                                    }).toList(),
                                    onChanged: (id) {
                                      if (id != null) {
                                        setDialogState(() => activeCatId = id);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        if (isLoadingDetail || detail == null)
                          const Expanded(child: Center(child: CircularProgressIndicator()))
                        else
                          Expanded(
                            child: ListView(
                              children: [
                                // Mini KPI cards for this category
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildMiniKpiCard(
                                        title: 'Category Revenue',
                                        value: '$currency ${detail.totalRevenue.toStringAsFixed(0)}',
                                        icon: Icons.payments_rounded,
                                        color: const Color(0xFF10B981),
                                        isDark: isDark,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _buildMiniKpiCard(
                                        title: 'Units Sold',
                                        value: '${detail.totalSold} Items',
                                        icon: Icons.shopping_bag_rounded,
                                        color: const Color(0xFF3B82F6),
                                        isDark: isDark,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _buildMiniKpiCard(
                                        title: 'Unique Items',
                                        value: '${detail.products.length} Products',
                                        icon: Icons.fastfood_rounded,
                                        color: const Color(0xFF8B5CF6),
                                        isDark: isDark,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Product Breakdown
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Products Sold in ${detail.category.name}',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      'Sorted by Units Sold',
                                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (detail.products.isEmpty)
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'No sales recorded for this category in the selected filter period.',
                                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                    ),
                                  )
                                else
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: AppColors.border),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Table(
                                        columnWidths: const {
                                          0: FlexColumnWidth(0.8),
                                          1: FlexColumnWidth(3.5),
                                          2: FlexColumnWidth(1.8),
                                          3: FlexColumnWidth(1.5),
                                          4: FlexColumnWidth(2),
                                        },
                                        children: [
                                          TableRow(
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                            ),
                                            children: const [
                                              Padding(padding: EdgeInsets.all(8), child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                              Padding(padding: EdgeInsets.all(8), child: Text('Product', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                              Padding(padding: EdgeInsets.all(8), child: Text('Price', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.right)),
                                              Padding(padding: EdgeInsets.all(8), child: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.right)),
                                              Padding(padding: EdgeInsets.all(8), child: Text('Revenue', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.right)),
                                            ],
                                          ),
                                          ...detail.products.asMap().entries.map((entry) {
                                            final idx = entry.key + 1;
                                            final p = entry.value;
                                            return TableRow(
                                              children: [
                                                Padding(padding: const EdgeInsets.all(8), child: Text('$idx', style: const TextStyle(fontSize: 11))),
                                                Padding(padding: const EdgeInsets.all(8), child: Text(p.productName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                                                Padding(padding: const EdgeInsets.all(8), child: Text('$currency ${p.avgPrice.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11), textAlign: TextAlign.right)),
                                                Padding(padding: const EdgeInsets.all(8), child: Text('${p.totalSold}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary), textAlign: TextAlign.right)),
                                                Padding(padding: const EdgeInsets.all(8), child: Text('$currency ${p.totalRevenue.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                                              ],
                                            );
                                          }),
                                        ],
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 16),

                                // Raw Material & Stock Consumed
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Stock & Ingredients Consumed (${detail.category.name})',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      'Based on Sold Items Recipes',
                                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (detail.ingredientsUsed.isEmpty)
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'No recipe items configured or consumed for products in this category.',
                                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                    ),
                                  )
                                else
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: AppColors.border),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Table(
                                        columnWidths: const {
                                          0: FlexColumnWidth(0.8),
                                          1: FlexColumnWidth(4.5),
                                          2: FlexColumnWidth(2.5),
                                          3: FlexColumnWidth(2),
                                        },
                                        children: [
                                          TableRow(
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                            ),
                                            children: const [
                                              Padding(padding: EdgeInsets.all(8), child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                              Padding(padding: EdgeInsets.all(8), child: Text('Ingredient / Stock Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                              Padding(padding: EdgeInsets.all(8), child: Text('Total Consumed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.right)),
                                              Padding(padding: EdgeInsets.all(8), child: Text('Unit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                            ],
                                          ),
                                          ...detail.ingredientsUsed.asMap().entries.map((entry) {
                                            final idx = entry.key + 1;
                                            final ing = entry.value;
                                            final qtyStr = ing.totalQuantity % 1 == 0
                                                ? ing.totalQuantity.toInt().toString()
                                                : ing.totalQuantity.toStringAsFixed(2);
                                            return TableRow(
                                              children: [
                                                Padding(padding: const EdgeInsets.all(8), child: Text('$idx', style: const TextStyle(fontSize: 11))),
                                                Padding(padding: const EdgeInsets.all(8), child: Text(ing.stockName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                                                Padding(padding: const EdgeInsets.all(8), child: Text(qtyStr, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B)), textAlign: TextAlign.right)),
                                                Padding(padding: const EdgeInsets.all(8), child: Text(ing.unit, style: const TextStyle(fontSize: 11))),
                                              ],
                                            );
                                          }),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close'),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: isGeneratingPdf
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.print_rounded, size: 18),
                      label: const Text('Print / Export PDF'),
                      onPressed: (detail == null || isGeneratingPdf)
                          ? null
                          : () async {
                              setDialogState(() => isGeneratingPdf = true);
                              try {
                                await ReportService.printCategoryReport(
                                  settings: settings,
                                  categoryName: detail.category.name,
                                  filterLabel: _reportData!.filterLabel,
                                  totalSold: detail.totalSold,
                                  totalRevenue: detail.totalRevenue,
                                  products: detail.products,
                                  ingredientsUsed: detail.ingredientsUsed,
                                );
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error generating report: $e'), backgroundColor: AppColors.error),
                                  );
                                }
                              } finally {
                                if (dialogCtx.mounted) {
                                  setDialogState(() => isGeneratingPdf = false);
                                }
                              }
                            },
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMiniKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context).settings;
    final currency = settings.currencySymbol;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 750;
          final padding = isNarrow ? 12.0 : 20.0;

          return Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header
                _buildHeader(isNarrow),
                const SizedBox(height: 14),

                // Unified Filter Bar
                _buildFilterBar(isDark),
                const SizedBox(height: 14),

                // Main Content or Loading State
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _errorMessage != null
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.error_outline_rounded, color: Colors.red, size: 40),
                                  const SizedBox(height: 10),
                                  Text('Failed to load reports: $_errorMessage'),
                                  const SizedBox(height: 12),
                                  ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
                                ],
                              ),
                            )
                          : _reportData == null
                              ? const Center(child: Text('No data found.'))
                              : Column(
                                  children: [
                                    // KPI Overview Row
                                    _buildKpiOverview(currency, isDark),
                                    const SizedBox(height: 14),

                                    // Tab Navigation Bar
                                    _buildTabBar(isDark),
                                    const SizedBox(height: 10),

                                    // Tab Views
                                    Expanded(
                                      child: TabBarView(
                                        controller: _tabController,
                                        children: [
                                          _buildSalesRecordTab(currency, isDark),
                                          _buildSellingItemsTab(currency, isDark),
                                          _buildCategorySellingTab(currency, isDark),
                                          _buildStockUsageTab(isDark),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(bool isNarrow) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.summarize_rounded, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Report Center',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Sales breakdown, top-selling items, category ranking & stock deductions',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh Reports',
              onPressed: _loadData,
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
              label: Text(isNarrow ? 'Category' : 'Generate Category Report'),
              onPressed: () => _showCategoryReportModal(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Icon(Icons.filter_alt_rounded, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              'Filter:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 8),

            // All Time
            _buildFilterChip('All Time', ReportFilterType.allTime, Icons.all_inclusive_rounded),
            const SizedBox(width: 6),

            // Today
            _buildFilterChip('Today', ReportFilterType.today, Icons.today_rounded),
            const SizedBox(width: 6),

            // Last 10 Days
            _buildFilterChip('Last 10 Days', ReportFilterType.last10Days, Icons.date_range_rounded),
            const SizedBox(width: 6),

            // This Month
            _buildFilterChip('This Month', ReportFilterType.thisMonth, Icons.calendar_today_rounded),
            const SizedBox(width: 6),

            // Specific Date
            FilterChip(
              selected: _currentFilter == ReportFilterType.specificDate,
              selectedColor: AppColors.primary,
              avatar: Icon(
                Icons.event_rounded,
                size: 16,
                color: _currentFilter == ReportFilterType.specificDate ? Colors.white : AppColors.primary,
              ),
              label: Text(
                _currentFilter == ReportFilterType.specificDate && _specificDate != null
                    ? DateFormat('dd MMM yyyy').format(_specificDate!)
                    : 'Specific Date',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _currentFilter == ReportFilterType.specificDate ? Colors.white : AppColors.textPrimary,
                ),
              ),
              onSelected: (_) => _pickSpecificDate(),
            ),
            const SizedBox(width: 6),

            // Specific Month
            FilterChip(
              selected: _currentFilter == ReportFilterType.specificMonth,
              selectedColor: AppColors.primary,
              avatar: Icon(
                Icons.calendar_month_rounded,
                size: 16,
                color: _currentFilter == ReportFilterType.specificMonth ? Colors.white : AppColors.primary,
              ),
              label: Text(
                _currentFilter == ReportFilterType.specificMonth && _specificMonth != null && _specificYear != null
                    ? DateFormat('MMM yyyy').format(DateTime(_specificYear!, _specificMonth!))
                    : 'Specific Month',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _currentFilter == ReportFilterType.specificMonth ? Colors.white : AppColors.textPrimary,
                ),
              ),
              onSelected: (_) => _pickSpecificMonth(),
            ),

            if (_reportData != null) ...[
              const SizedBox(width: 14),
              Container(height: 18, width: 1, color: AppColors.border),
              const SizedBox(width: 14),
              Text(
                'Active: ${_reportData!.filterLabel}',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, ReportFilterType filterType, IconData icon) {
    final isSelected = _currentFilter == filterType;
    return FilterChip(
      selected: isSelected,
      selectedColor: AppColors.primary,
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected ? Colors.white : AppColors.primary,
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isSelected ? Colors.white : AppColors.textPrimary,
        ),
      ),
      onSelected: (_) {
        setState(() => _currentFilter = filterType);
        _loadData();
      },
    );
  }

  Widget _buildKpiOverview(String currency, bool isDark) {
    final ov = _reportData!.overview;

    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            title: 'Total Sales Revenue',
            value: '$currency ${ov.totalGrossSales.toStringAsFixed(0)}',
            subtitle: 'Net: $currency ${ov.totalNetRevenue.toStringAsFixed(0)}',
            icon: Icons.payments_rounded,
            color: const Color(0xFF10B981),
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricCard(
            title: 'Total Orders / Invoices',
            value: '${ov.totalOrders}',
            subtitle: '${ov.clearedOrders} Cleared | ${ov.remainingOrders} Remaining',
            icon: Icons.receipt_long_rounded,
            color: const Color(0xFF3B82F6),
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricCard(
            title: 'Payment Breakdown',
            value: 'Cash: $currency ${ov.cashTotal.toStringAsFixed(0)}',
            subtitle: 'Online/Card: $currency ${ov.onlineTotal.toStringAsFixed(0)}',
            icon: Icons.account_balance_wallet_rounded,
            color: const Color(0xFFF59E0B),
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricCard(
            title: 'Average Order Value',
            value: '$currency ${ov.avgOrderValue.toStringAsFixed(0)}',
            subtitle: 'Per completed bill',
            icon: Icons.trending_up_rounded,
            color: const Color(0xFF8B5CF6),
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 10, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(bool isDark) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textSecondary,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: AppColors.primary,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        tabs: const [
          Tab(icon: Icon(Icons.receipt_rounded, size: 16), text: 'Sales Record'),
          Tab(icon: Icon(Icons.local_fire_department_rounded, size: 16), text: 'Selling Items (Top to Bottom)'),
          Tab(icon: Icon(Icons.category_rounded, size: 16), text: 'Category Selling'),
          Tab(icon: Icon(Icons.inventory_2_rounded, size: 16), text: 'Total Stock Used'),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // TAB 1: SALES RECORD
  // ────────────────────────────────────────────────────────────
  Widget _buildSalesRecordTab(String currency, bool isDark) {
    final filteredSales = _reportData!.salesList.where((s) {
      final matchesQuery = _salesSearchQuery.isEmpty ||
          s.invoiceNumber.toLowerCase().contains(_salesSearchQuery.toLowerCase()) ||
          (s.customerName ?? '').toLowerCase().contains(_salesSearchQuery.toLowerCase()) ||
          (s.tableName ?? '').toLowerCase().contains(_salesSearchQuery.toLowerCase()) ||
          (s.waiterName ?? '').toLowerCase().contains(_salesSearchQuery.toLowerCase()) ||
          s.cashierName.toLowerCase().contains(_salesSearchQuery.toLowerCase());

      final isCleared = s.isCleared;
      final matchesStatus = _salesStatusFilter == 'ALL' ||
          (_salesStatusFilter == 'CLEARED' && isCleared) ||
          (_salesStatusFilter == 'REMAINING' && !isCleared);

      return matchesQuery && matchesStatus;
    }).toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Filter & Search Controls
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by Invoice #, Table, Waiter, Customer...',
                      hintStyle: const TextStyle(fontSize: 12),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (val) => setState(() => _salesSearchQuery = val),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'ALL', label: Text('All', style: TextStyle(fontSize: 11))),
                  ButtonSegment(value: 'CLEARED', label: Text('Cleared', style: TextStyle(fontSize: 11))),
                  ButtonSegment(value: 'REMAINING', label: Text('Remaining', style: TextStyle(fontSize: 11))),
                ],
                selected: {_salesStatusFilter},
                onSelectionChanged: (set) => setState(() => _salesStatusFilter = set.first),
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Sales List
          Expanded(
            child: filteredSales.isEmpty
                ? Center(
                    child: Text(
                      'No sales records found matching the filter.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  )
                : ListView.separated(
                    itemCount: filteredSales.length,
                    separatorBuilder: (ctx, i) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final sale = filteredSales[index];
                      final isCleared = sale.isCleared;

                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: (isCleared ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.15),
                          child: Icon(
                            isCleared ? Icons.check_circle_outline_rounded : Icons.pending_actions_rounded,
                            color: isCleared ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            size: 18,
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(
                              sale.invoiceNumber,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(width: 8),
                            if (sale.tableName != null && sale.tableName!.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  sale.tableName!,
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
                              ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (sale.paymentMethod.toUpperCase() == 'CASH' ? Colors.green : Colors.blue).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                sale.paymentMethod.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: sale.paymentMethod.toUpperCase() == 'CASH' ? Colors.green : Colors.blue,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          '${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(sale.dateTime))} • Waiter: ${sale.waiterName ?? 'None'} • Cashier: ${sale.cashierName} • ${sale.items.length} items',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$currency ${sale.grandTotal.toStringAsFixed(0)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(Icons.receipt_rounded, size: 18),
                              tooltip: 'View Invoice',
                              onPressed: () => InvoiceDialogs.showInvoiceDetailsDialog(
                                context: context,
                                sale: sale,
                                currencySymbol: currency,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // TAB 2: SELLING ITEMS (TOP SELLING IN DESCENDING ORDER)
  // ────────────────────────────────────────────────────────────
  Widget _buildSellingItemsTab(String currency, bool isDark) {
    final items = _reportData!.itemSales.where((i) {
      return _itemsSearchQuery.isEmpty ||
          i.productName.toLowerCase().contains(_itemsSearchQuery.toLowerCase()) ||
          i.categoryName.toLowerCase().contains(_itemsSearchQuery.toLowerCase());
    }).toList();

    final maxSold = items.isNotEmpty ? items.first.totalSold : 1;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Search & Sort Info
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search products by name or category...',
                      hintStyle: const TextStyle(fontSize: 12),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (val) => setState(() => _itemsSearchQuery = val),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.arrow_downward_rounded, size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Ranked by Highest Sold',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Items List
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text(
                      'No items sold in this filter period.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  )
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (ctx, i) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final rank = index + 1;
                      final progress = maxSold > 0 ? (item.totalSold / maxSold) : 0.0;

                      Color rankColor;
                      if (rank == 1) {
                        rankColor = const Color(0xFFF59E0B); // Gold
                      } else if (rank == 2) {
                        rankColor = const Color(0xFF94A3B8); // Silver
                      } else if (rank == 3) {
                        rankColor = const Color(0xFFB45309); // Bronze
                      } else {
                        rankColor = AppColors.primary;
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        child: Row(
                          children: [
                            // Rank Badge
                            Container(
                              width: 34,
                              height: 34,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: rankColor.withValues(alpha: 0.18),
                                border: Border.all(color: rankColor.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                '#$rank',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: rankColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Product & Category Details
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.productName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          item.categoryName,
                                          style: TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Avg Price: $currency ${item.avgPrice.toStringAsFixed(0)}',
                                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  // Visual Volume Bar
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 4,
                                      backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                      valueColor: AlwaysStoppedAnimation<Color>(rankColor),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Units Sold
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${item.totalSold} Sold',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '$currency ${item.totalRevenue.toStringAsFixed(0)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // TAB 3: CATEGORY SELLING (KONSI CATEGORY SAB SY ZYADA CHALI)
  // ────────────────────────────────────────────────────────────
  Widget _buildCategorySellingTab(String currency, bool isDark) {
    final categories = _reportData!.categorySales;
    final maxRevenue = categories.isNotEmpty ? categories.first.totalRevenue : 1.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Category Performance & Market Share', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  Text('Sorted descending by category revenue and popularity', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 14),
                label: const Text('Generate Category Report', style: TextStyle(fontSize: 11)),
                onPressed: () => _showCategoryReportModal(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Expanded(
            child: categories.isEmpty
                ? Center(
                    child: Text(
                      'No category sales data for this filter period.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  )
                : ListView.separated(
                    itemCount: categories.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final cat = categories[index];
                      final rank = index + 1;
                      final progress = maxRevenue > 0 ? (cat.totalRevenue / maxRevenue) : 0.0;

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                // Rank Indicator
                                Container(
                                  width: 32,
                                  height: 32,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: (rank == 1 ? const Color(0xFFF59E0B) : AppColors.primary).withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '#$rank',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: rank == 1 ? const Color(0xFFF59E0B) : AppColors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Category Name & Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        cat.categoryName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${cat.uniqueProductsCount} products sold • ${cat.totalSold} total units',
                                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),

                                // Revenue & Share
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '$currency ${cat.totalRevenue.toStringAsFixed(0)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    const SizedBox(height: 2),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${cat.percentageShare.toStringAsFixed(1)}% of Sales',
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 10),

                                // Direct Report Button
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  icon: const Icon(Icons.description_rounded, size: 14),
                                  label: const Text('Report', style: TextStyle(fontSize: 11)),
                                  onPressed: () => _showCategoryReportModal(cat.categoryId),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Progress Bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 6,
                                backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                                valueColor: AlwaysStoppedAnimation<Color>(rank == 1 ? const Color(0xFFF59E0B) : AppColors.primary),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // TAB 4: TOTAL STOCK USED / DEDUCTED PER ITEM
  // ────────────────────────────────────────────────────────────
  Widget _buildStockUsageTab(bool isDark) {
    final stockItems = _reportData!.stockUsage.where((s) {
      return _stockSearchQuery.isEmpty ||
          s.stockName.toLowerCase().contains(_stockSearchQuery.toLowerCase());
    }).toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Search & Summary Header
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search raw materials / stock items...',
                      hintStyle: const TextStyle(fontSize: 12),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (val) => setState(() => _stockSearchQuery = val),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_rounded, size: 14, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 4),
                    Text(
                      '${stockItems.length} Stock Items Deducted',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Stock Items List
          Expanded(
            child: stockItems.isEmpty
                ? Center(
                    child: Text(
                      'No stock deductions or consumption found in this filter period.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  )
                : ListView.separated(
                    itemCount: stockItems.length,
                    separatorBuilder: (ctx, i) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = stockItems[index];
                      final idx = index + 1;
                      final qtyStr = item.totalQuantity % 1 == 0
                          ? item.totalQuantity.toInt().toString()
                          : item.totalQuantity.toStringAsFixed(2);

                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          child: Text(
                            '#$idx',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF59E0B),
                            ),
                          ),
                        ),
                        title: Text(
                          item.stockName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        subtitle: Text(
                          'Deducted across ${item.usageCount} transactions/orders in this period',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$qtyStr ${item.unit}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFFD97706),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
