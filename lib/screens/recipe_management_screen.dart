import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/constants/app_constants.dart';
import '../models/product_model.dart';
import '../models/stock_item_model.dart';
import '../providers/settings_provider.dart';
import '../providers/product_provider.dart';
import '../providers/category_provider.dart';
import '../providers/stock_provider.dart';
import '../services/milk_conversion_service.dart';
import '../widgets/milk_ratio_dialog.dart';
import '../widgets/recipe_config_dialog.dart';
import '../services/unit_conversion_service.dart';

class RecipeManagementScreen extends StatefulWidget {
  const RecipeManagementScreen({super.key});

  @override
  State<RecipeManagementScreen> createState() => _RecipeManagementScreenState();
}

class _RecipeManagementScreenState extends State<RecipeManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _recipeSearchController = TextEditingController();
  final TextEditingController _stockSearchController = TextEditingController();
  final TextEditingController _auditSearchController = TextEditingController();

  int? _selectedCategoryId;
  String _recipeFilter = 'ALL'; // ALL, CONFIGURED, PENDING

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _recipeSearchController.dispose();
    _stockSearchController.dispose();
    _auditSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context).settings;
    final productProvider = Provider.of<ProductProvider>(context);
    final stockProvider = Provider.of<StockProvider>(context);
    final categoryProvider = Provider.of<CategoryProvider>(context);

    final double milkRatio = settings.milkCupsPerKg;
    final double fullCupKg = milkRatio > 0 ? (1.0 / milkRatio) : 0.2;
    final double fullCupMl = fullCupKg * 1000.0;

    // Find Milk in inventory
    final milkStock = stockProvider.findStockByProductName('Milk') ??
        (stockProvider.stockList.any((s) => s.name.toLowerCase().contains('milk'))
            ? stockProvider.stockList.firstWhere((s) => s.name.toLowerCase().contains('milk'))
            : null);
    final double currentMilkKg = milkStock?.quantity ?? 0.0;
    final int estimatedCupsLeft =
        MilkConversionService.calculateEstimatedCupsLeft(currentMilkKg, milkRatio);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final bool isCompact = width < 768;
        final double padding = isCompact ? 14 : 22;

        final totalProducts = productProvider.products.length;
        final productsWithRecipes =
            productProvider.products.where((p) => p.recipeItems.isNotEmpty).length;

        return Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Title & Actions ──
              _buildTopHeader(context, isCompact, totalProducts, productsWithRecipes),
              const SizedBox(height: 14),

              // ── Modern Tab Navigation ──
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                tabs: [
                  Tab(
                    icon: const Icon(Icons.menu_book_rounded, size: 18),
                    text: 'Product Recipes ($productsWithRecipes/$totalProducts)',
                  ),
                  Tab(
                    icon: const Icon(Icons.inventory_2_rounded, size: 18),
                    text: 'Raw Materials Stock (${stockProvider.stockList.length})',
                  ),
                  const Tab(
                    icon: Icon(Icons.local_cafe_rounded, size: 18),
                    text: 'Special Milk Engine',
                  ),
                  Tab(
                    icon: const Icon(Icons.history_rounded, size: 18),
                    text: 'Auto-Deduction Audit Trail',
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── Tab Views ──
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // TAB 1: Product Recipes
                    _buildProductRecipesTab(
                      context,
                      productProvider,
                      stockProvider,
                      categoryProvider,
                      settings.currencySymbol,
                      isCompact,
                    ),

                    // TAB 2: Raw Materials Inventory
                    _buildRawMaterialsTab(
                      context,
                      stockProvider,
                      settings.currencySymbol,
                      isCompact,
                    ),

                    // TAB 3: Special Milk Engine
                    _buildMilkEngineTab(
                      context,
                      milkRatio: milkRatio,
                      fullCupKg: fullCupKg,
                      fullCupMl: fullCupMl,
                      currentMilkKg: currentMilkKg,
                      estimatedCupsLeft: estimatedCupsLeft,
                      isCompact: isCompact,
                    ),

                    // TAB 4: Auto Deduction Audit Trail
                    _buildAuditTrailTab(context, stockProvider, isCompact),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TOP HEADER
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildTopHeader(
    BuildContext context,
    bool isCompact,
    int totalProducts,
    int configuredCount,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Raw Materials & Recipe Management',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                'Connect finished products to raw ingredients for automatic stock deduction upon sale',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh Recipes & Stock',
              onPressed: () async {
                await Provider.of<ProductProvider>(context, listen: false).loadProducts();
                if (context.mounted) {
                  await Provider.of<StockProvider>(context, listen: false).loadStockData();
                }
              },
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.add_box_rounded, size: 16),
              label: const Text('+ Add Raw Material', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              onPressed: () => _showAddRawMaterialModal(context),
            ),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 1: PRODUCT RECIPES (AUTO-DEDUCT)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildProductRecipesTab(
    BuildContext context,
    ProductProvider productProvider,
    StockProvider stockProvider,
    CategoryProvider categoryProvider,
    String currency,
    bool isCompact,
  ) {
    var products = productProvider.products;

    // Category filter
    if (_selectedCategoryId != null) {
      products = products.where((p) => p.categoryId == _selectedCategoryId).toList();
    }

    // Status filter
    if (_recipeFilter == 'CONFIGURED') {
      products = products.where((p) => p.recipeItems.isNotEmpty).toList();
    } else if (_recipeFilter == 'PENDING') {
      products = products.where((p) => p.recipeItems.isEmpty).toList();
    }

    // Search query
    final query = _recipeSearchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      products = products.where((p) {
        final matchesName = p.name.toLowerCase().contains(query);
        final matchesCat = (p.categoryName ?? '').toLowerCase().contains(query);
        final matchesIngredient = p.recipeItems.any((r) => r.stockName.toLowerCase().contains(query));
        return matchesName || matchesCat || matchesIngredient;
      }).toList();
    }

    return Column(
      children: [
        // Filter & Search Toolbar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Search input
              SizedBox(
                width: isCompact ? double.infinity : 260,
                child: TextField(
                  controller: _recipeSearchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search products or ingredients...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    suffixIcon: _recipeSearchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 16),
                            onPressed: () {
                              _recipeSearchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),

              // Category dropdown
              DropdownButton<int?>(
                value: _selectedCategoryId,
                hint: const Text('All Categories', style: TextStyle(fontSize: 13)),
                underline: const SizedBox(),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('All Categories')),
                  ...categoryProvider.categories.map((c) => DropdownMenuItem<int?>(
                        value: c.id,
                        child: Text(c.name, style: const TextStyle(fontSize: 13)),
                      )),
                ],
                onChanged: (val) => setState(() => _selectedCategoryId = val),
              ),

              // Status Filter Chips
              Wrap(
                spacing: 6,
                children: [
                  _buildFilterChip('All Products', 'ALL'),
                  _buildFilterChip('With Recipe', 'CONFIGURED'),
                  _buildFilterChip('No Recipe Set', 'PENDING'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Helper explanation banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: const Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: Color(0xFF2563EB), size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Automated Stock Deduction: Selling an item in POS instantly deducts its linked raw ingredients from inventory. Items with no recipe can fall back to 1:1 direct stock deduction.',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF1E40AF), fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Product Cards List
        Expanded(
          child: products.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off_rounded, size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 10),
                      Text(
                        _recipeSearchController.text.isNotEmpty || _selectedCategoryId != null
                            ? 'No products match the selected filters'
                            : 'No products found',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text('Try resetting your search or filter options',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return _buildProductRecipeCard(context, product, stockProvider.stockList, currency);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _recipeFilter == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _recipeFilter = value);
      },
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(color: isSelected ? AppColors.primary : AppColors.textSecondary),
    );
  }

  Widget _buildProductRecipeCard(
    BuildContext context,
    ProductModel product,
    List<StockItemModel> stockList,
    String currency,
  ) {
    final hasRecipe = product.recipeItems.isNotEmpty;

    // Calculate total ingredient cost
    double totalRawCost = 0.0;
    for (var r in product.recipeItems) {
      final stock = stockList.firstWhere(
        (s) => s.id == r.stockId,
        orElse: () => StockItemModel(id: -1, name: '', unit: '', quantity: 0),
      );
      if (stock.id != -1 && stock.costPerUnit > 0) {
        final convertedQty = UnitConversionService.convertQuantity(
          quantity: r.quantity,
          fromUnit: r.unit,
          toUnit: stock.unit,
        );
        totalRawCost += convertedQty * stock.costPerUnit;
      }
    }

    final sellingPrice = product.sellingPrice;
    final estimatedMargin = totalRawCost > 0 ? (sellingPrice - totalRawCost) : 0.0;
    final marginPercent = (sellingPrice > 0 && totalRawCost > 0)
        ? ((estimatedMargin / sellingPrice) * 100.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasRecipe ? AppColors.accent.withValues(alpha: 0.5) : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Product Name & Category
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          product.name,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        if (product.categoryName != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Text(
                              product.categoryName!,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Selling Price: $currency ${sellingPrice.toStringAsFixed(0)}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),

              // Auto-Deduct Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: hasRecipe
                      ? const Color(0xFFECFDF5)
                      : const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: hasRecipe ? const Color(0xFFA7F3D0) : const Color(0xFFFED7AA),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasRecipe ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                      size: 13,
                      color: hasRecipe ? const Color(0xFF059669) : const Color(0xFFD97706),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      hasRecipe
                          ? 'Auto-Deducts (${product.recipeItems.length} Ingredients)'
                          : 'No Recipe Configured',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: hasRecipe ? const Color(0xFF059669) : const Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Configure Recipe Action Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasRecipe ? const Color(0xFF0284C7) : AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.menu_book_rounded, size: 15),
                label: Text(
                  hasRecipe ? 'Edit Recipe' : 'Set Recipe',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: () => RecipeConfigDialog.show(context, product),
              ),
            ],
          ),

          // Recipe Ingredients Preview Row
          if (hasRecipe) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Raw Materials:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
                ...product.recipeItems.map((item) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      '${item.quantity.toString().replaceAll(RegExp(r'\.0$'), '')} ${item.unit} ${item.stockName}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                    ),
                  );
                }),
                if (totalRawCost > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    'Cost: $currency ${totalRawCost.toStringAsFixed(1)} | Margin: ${marginPercent.toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 2: RAW MATERIALS INVENTORY
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildRawMaterialsTab(
    BuildContext context,
    StockProvider stockProvider,
    String currency,
    bool isCompact,
  ) {
    var stockList = stockProvider.stockList;
    final query = _stockSearchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      stockList = stockList.where((s) => s.name.toLowerCase().contains(query)).toList();
    }

    return Column(
      children: [
        // Top Toolbar
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 38,
                child: TextField(
                  controller: _stockSearchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search raw materials (e.g. Milk, Coffee Beans, Patties)...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    suffixIcon: _stockSearchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 16),
                            onPressed: () {
                              _stockSearchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add Raw Material', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              onPressed: () => _showAddRawMaterialModal(context),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Raw Materials Table
        Expanded(
          child: stockList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 10),
                      const Text(
                        'No Raw Materials Found',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text('Add raw ingredients to start tracking recipes and stock.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 14),
                      ElevatedButton(
                        onPressed: () => _showAddRawMaterialModal(context),
                        child: const Text('+ Add Raw Material'),
                      ),
                    ],
                  ),
                )
              : Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                        columns: const [
                          DataColumn(label: Text('Raw Material Name', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Current Stock', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Unit', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Cost / Unit', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Min Alert', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Stock Health', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: stockList.map((stock) {
                          final isLow = stock.isLowStock;
                          final isOut = stock.quantity <= 0;

                          return DataRow(cells: [
                            DataCell(Text(
                              stock.name,
                              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            )),
                            DataCell(Text(
                              stock.quantity.toStringAsFixed(2),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isOut
                                    ? Colors.red.shade700
                                    : (isLow ? Colors.amber.shade800 : const Color(0xFF10B981)),
                              ),
                            )),
                            DataCell(Text(stock.unit)),
                            DataCell(Text('$currency ${stock.costPerUnit.toStringAsFixed(2)}')),
                            DataCell(Text('${stock.minThreshold.toStringAsFixed(1)} ${stock.unit}')),
                            DataCell(Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isOut
                                    ? Colors.red.shade50
                                    : (isLow ? Colors.amber.shade50 : const Color(0xFFECFDF5)),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isOut
                                      ? Colors.red.shade200
                                      : (isLow ? Colors.amber.shade300 : const Color(0xFFA7F3D0)),
                                ),
                              ),
                              child: Text(
                                isOut ? 'OUT OF STOCK' : (isLow ? 'LOW STOCK' : 'IN STOCK'),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isOut
                                      ? Colors.red.shade700
                                      : (isLow ? Colors.amber.shade900 : const Color(0xFF059669)),
                                ),
                              ),
                            )),
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.add_circle_outline_rounded, color: AppColors.primary, size: 20),
                                  tooltip: 'Quick Restock',
                                  onPressed: () => _showRestockModal(context, stock),
                                ),
                                IconButton(
                                  icon: Icon(Icons.edit_outlined, color: AppColors.textSecondary, size: 18),
                                  tooltip: 'Edit Material',
                                  onPressed: () => _showAddRawMaterialModal(context, stock: stock),
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

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 3: SPECIAL MILK ENGINE
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildMilkEngineTab(
    BuildContext context, {
    required double milkRatio,
    required double fullCupKg,
    required double fullCupMl,
    required double currentMilkKg,
    required int estimatedCupsLeft,
    required bool isCompact,
  }) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Active Ratio Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF334155)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.local_cafe_rounded, color: Colors.white, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CURRENT TEA MILK RATIO',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '1 KG Milk = ${milkRatio.toStringAsFixed(1)} Full Cups of Tea',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Base deduction: ${fullCupKg.toStringAsFixed(3)} KG (${fullCupMl.toStringAsFixed(0)} ml) per cup. Automatically deducted upon invoice generation.',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    showDialog(context: context, builder: (_) => const MilkRatioDialog());
                  },
                  child: const Text('Change Ratio'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Live Milk Inventory Stats Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.inventory_2_rounded, color: AppColors.primary, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LIVE MILK INVENTORY',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${currentMilkKg.toStringAsFixed(2)} KG Remaining',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Enough for ~ $estimatedCupsLeft full cups of tea based on current ratio',
                        style: TextStyle(
                          color: estimatedCupsLeft < 20 ? AppColors.error : AppColors.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Portion multipliers
          _buildPortionRatiosRow(fullCupKg, fullCupMl, isCompact),
        ],
      ),
    );
  }

  Widget _buildPortionRatiosRow(double fullCupKg, double fullCupMl, bool isCompact) {
    final portions = [
      {'name': 'Full Tea', 'ratio': 1.0, 'color': AppColors.primary},
      {'name': 'Half Tea', 'ratio': 0.55, 'color': Colors.blue},
      {'name': 'Special Tea', 'ratio': 1.20, 'color': Colors.amber.shade800},
      {'name': 'Large Tea', 'ratio': 1.50, 'color': Colors.purple},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TEA PORTION AUTO-DEDUCTION MULTIPLIERS',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: portions.map((p) {
              final ratio = p['ratio'] as double;
              final kg = fullCupKg * ratio;
              final ml = fullCupMl * ratio;
              final color = p['color'] as Color;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p['name'] as String,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${(ratio * 100).toInt()}% = ${kg.toStringAsFixed(3)} KG (${ml.toStringAsFixed(0)} ml)',
                      style: TextStyle(fontSize: 11, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 4: AUTO-DEDUCTION AUDIT TRAIL
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildAuditTrailTab(BuildContext context, StockProvider stockProvider, bool isCompact) {
    final transactions = stockProvider.transactions.where((t) => t.type.contains('OUT')).toList();
    final query = _auditSearchController.text.trim().toLowerCase();

    final filtered = query.isEmpty
        ? transactions
        : transactions.where((t) {
            final nameMatch = t.stockName.toLowerCase().contains(query);
            final invMatch = (t.invoiceNumber ?? '').toLowerCase().contains(query);
            final notesMatch = (t.notes ?? '').toLowerCase().contains(query);
            return nameMatch || invMatch || notesMatch;
          }).toList();

    return Column(
      children: [
        // Search Toolbar
        SizedBox(
          height: 38,
          child: TextField(
            controller: _auditSearchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search deductions by invoice number or raw material...',
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              suffixIcon: _auditSearchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16),
                      onPressed: () {
                        _auditSearchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(height: 12),

        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history_toggle_off_rounded, size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 10),
                      const Text(
                        'No Auto-Deduction Records Yet',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text('When orders are checked out in POS, auto-deductions will appear here.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                )
              : Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                        columns: const [
                          DataColumn(label: Text('Date & Time', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Raw Material', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Quantity Deducted', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Invoice #', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Notes / Menu Item', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: filtered.map((log) {
                          return DataRow(cells: [
                            DataCell(Text(
                              log.dateTime.length > 16 ? log.dateTime.substring(0, 16) : log.dateTime,
                              style: const TextStyle(fontSize: 12),
                            )),
                            DataCell(Text(
                              log.stockName,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            )),
                            DataCell(Text(
                              '-${log.quantity.toStringAsFixed(3)} ${log.unit}',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade700),
                            )),
                            DataCell(Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                log.invoiceNumber ?? '-',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                            )),
                            DataCell(Text(log.notes ?? '-')),
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

  // ─────────────────────────────────────────────────────────────────────────
  // MODALS
  // ─────────────────────────────────────────────────────────────────────────
  void _showAddRawMaterialModal(BuildContext context, {StockItemModel? stock}) {
    final nameController = TextEditingController(text: stock?.name ?? '');
    final qtyController = TextEditingController(text: (stock?.quantity ?? 0.0).toString());
    final minController = TextEditingController(text: (stock?.minThreshold ?? 5.0).toString());
    final costController = TextEditingController(text: (stock?.costPerUnit ?? 0.0).toString());
    String selectedUnit = stock?.unit ?? AppConstants.inventoryUnits.first;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(stock == null ? 'Add New Raw Material' : 'Edit Raw Material'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Material Name (e.g. Milk, Coffee Beans, Patties)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedUnit,
                decoration: const InputDecoration(labelText: 'Unit of Measurement', border: OutlineInputBorder()),
                items: AppConstants.inventoryUnits
                    .map((u) => DropdownMenuItem<String>(value: u, child: Text(u)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) selectedUnit = val;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: qtyController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Initial Quantity', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: minController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Min Alert Qty', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: costController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Cost Per Unit (Rs.)', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              final stockProv = Provider.of<StockProvider>(context, listen: false);

              if (stock == null) {
                await stockProv.addStockItem(StockItemModel(
                  name: nameController.text.trim(),
                  unit: selectedUnit,
                  quantity: double.tryParse(qtyController.text) ?? 0.0,
                  minThreshold: double.tryParse(minController.text) ?? 5.0,
                  costPerUnit: double.tryParse(costController.text) ?? 0.0,
                  lastUpdated: DateTime.now().toIso8601String(),
                ));
              } else {
                await stockProv.updateStockItem(stock.copyWith(
                  name: nameController.text.trim(),
                  unit: selectedUnit,
                  quantity: double.tryParse(qtyController.text) ?? stock.quantity,
                  minThreshold: double.tryParse(minController.text) ?? stock.minThreshold,
                  costPerUnit: double.tryParse(costController.text) ?? stock.costPerUnit,
                  lastUpdated: DateTime.now().toIso8601String(),
                ));
              }

              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save Material'),
          ),
        ],
      ),
    );
  }

  void _showRestockModal(BuildContext context, StockItemModel stock) {
    final addQtyController = TextEditingController();
    final notesController = TextEditingController(text: 'Restock / Purchase');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Restock "${stock.name}"'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Stock: ${stock.quantity.toStringAsFixed(2)} ${stock.unit}',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: addQtyController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Add Quantity (${stock.unit})',
                  hintText: 'e.g. 5.0',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final added = double.tryParse(addQtyController.text) ?? 0.0;
              if (added <= 0) return;

              final stockProv = Provider.of<StockProvider>(context, listen: false);
              await stockProv.addQuantity(
                stockId: stock.id!,
                stockName: stock.name,
                qty: added,
                unit: stock.unit,
                notes: notesController.text.trim(),
              );

              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Confirm Restock'),
          ),
        ],
      ),
    );
  }
}