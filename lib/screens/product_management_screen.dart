import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../core/theme/app_theme.dart';
import '../models/product_model.dart';
import '../models/category_model.dart';
import '../models/stock_item_model.dart';
import '../providers/product_provider.dart';
import '../providers/category_provider.dart';
import '../providers/stock_provider.dart';
import '../repositories/category_repository.dart';
import '../services/menu_import_service.dart';
import '../widgets/recipe_config_dialog.dart';


class ProductManagementScreen extends StatefulWidget {
  const ProductManagementScreen({super.key});

  @override
  State<ProductManagementScreen> createState() => _ProductManagementScreenState();
}

class _ProductManagementScreenState extends State<ProductManagementScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);
    final categoryProvider = Provider.of<CategoryProvider>(context);
    final stockProvider = Provider.of<StockProvider>(context);

    final searchQuery = _searchController.text.trim().toLowerCase();
    final filteredProducts = productProvider.products.where((product) {
      final matchesName = product.name.toLowerCase().contains(searchQuery);
      final matchesCat = (product.categoryName ?? '').toLowerCase().contains(searchQuery);
      return matchesName || matchesCat;
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 700;
        final padding = isNarrow ? 12.0 : 24.0;

        return Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isNarrow)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Product Management',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Manage menu items, prices, and live stock',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded),
                          tooltip: 'Refresh Products & Stock',
                          onPressed: () async {
                            await productProvider.loadProducts();
                            if (context.mounted) {
                              await stockProvider.loadStockData();
                              await categoryProvider.loadCategories();
                            }
                          },
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.upload_file_rounded, size: 16),
                          label: const Text('Import Menu', style: TextStyle(fontSize: 12)),
                          onPressed: () => _handleImportMenu(context),
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Add Product', style: TextStyle(fontSize: 12)),
                          onPressed: () => _showAddEditProductDialog(
                            context,
                            categories: categoryProvider.categories,
                            stockItems: stockProvider.stockList,
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
                          'Product Management',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Manage menu items, prices, and live stock tracking',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded),
                          tooltip: 'Refresh Products & Stock',
                          onPressed: () async {
                            await productProvider.loadProducts();
                            if (context.mounted) {
                              await stockProvider.loadStockData();
                              await categoryProvider.loadCategories();
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.upload_file_rounded, size: 18),
                          label: const Text('Import Menu'),
                          onPressed: () => _handleImportMenu(context),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add Product'),
                          onPressed: () => _showAddEditProductDialog(
                            context,
                            categories: categoryProvider.categories,
                            stockItems: stockProvider.stockList,
                          ),
                        ),
                      ],
                    ),

                  ],
                ),
              const SizedBox(height: 16),

              // Search Bar
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search products by name or category...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(height: 16),

          Expanded(
            child: productProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: filteredProducts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.restaurant_menu_rounded, size: 48, color: AppColors.textMuted),
                                const SizedBox(height: 12),
                                Text(
                                  _searchController.text.isNotEmpty
                                      ? 'No products match "${_searchController.text}"'
                                      : 'No products found',
                                  style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                                ),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columnSpacing: 20,
                                headingRowHeight: 48,
                                dataRowMinHeight: 52,
                                dataRowMaxHeight: 72,
                                columns: const [
                                  DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('ID', style: TextStyle(fontWeight: FontWeight.bold))))),
                                  DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Product Name', style: TextStyle(fontWeight: FontWeight.bold))))),
                                  DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))))),
                                  DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Selling Price', style: TextStyle(fontWeight: FontWeight.bold))))),
                                  DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Cost Price', style: TextStyle(fontWeight: FontWeight.bold))))),
                                  DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Stock Available', style: TextStyle(fontWeight: FontWeight.bold))))),
                                  DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))))),
                                  DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))))),
                                ],
                                rows: filteredProducts.map((product) {
                                  return DataRow(cells: [
                                    DataCell(Text('#${product.id}')),
                                    DataCell(Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                                    DataCell(Text(product.categoryName ?? '-')),
                                    DataCell(Text('Rs. ${product.sellingPrice.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary))),
                                    DataCell(Text('Rs. ${product.costPrice.toStringAsFixed(0)}')),
                                    DataCell(Builder(
                                      builder: (context) {
                                        if (product.recipeItems.isNotEmpty) {
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFECFDF5),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: const Color(0xFFA7F3D0)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.menu_book_rounded, size: 13, color: Color(0xFF059669)),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Recipe (${product.recipeItems.length} items)',
                                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                                                ),
                                              ],
                                            ),
                                          );
                                        }

                                        final stockItem = stockProvider.findStockByProductName(product.name);
                                        if (stockItem != null) {
                                          final isLow = stockItem.isLowStock;
                                          final isOut = stockItem.quantity <= 0;
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isOut
                                                  ? AppColors.error.withValues(alpha: 0.12)
                                                  : (isLow ? Colors.orange.shade100 : Colors.green.shade100),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  isOut ? Icons.error_outline : (isLow ? Icons.warning_amber_rounded : Icons.check_circle_outline),
                                                  size: 14,
                                                  color: isOut
                                                      ? AppColors.error
                                                      : (isLow ? Colors.orange.shade900 : Colors.green.shade800),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  isOut
                                                      ? '0 in stock (Depleted)'
                                                      : '${stockItem.quantity.toStringAsFixed(0)} ${stockItem.unit}${isLow ? ' (Low)' : ''}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: isOut
                                                        ? AppColors.error
                                                        : (isLow ? Colors.orange.shade900 : Colors.green.shade800),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }

                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'Not in Stock',
                                            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                                          ),
                                        );
                                      },
                                    )),
                                    DataCell(Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: product.isActive ? AppColors.accent.withValues(alpha: 0.15) : AppColors.error.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        product.status,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: product.isActive ? AppColors.accent : AppColors.error,
                                        ),
                                      ),
                                    )),
                                    DataCell(Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            product.recipeItems.isNotEmpty ? Icons.menu_book_rounded : Icons.menu_book_outlined,
                                            color: product.recipeItems.isNotEmpty ? const Color(0xFF10B981) : const Color(0xFF0284C7),
                                            size: 20,
                                          ),
                                          tooltip: product.recipeItems.isNotEmpty
                                              ? 'Edit Recipe (${product.recipeItems.length} ingredients)'
                                              : 'Set Recipe (Auto-Deduct Stock)',
                                          onPressed: () => RecipeConfigDialog.show(context, product),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
                                          onPressed: () => _showAddEditProductDialog(
                                            context,
                                            product: product,
                                            categories: categoryProvider.categories,
                                            stockItems: stockProvider.stockList,
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                                          onPressed: () => _confirmDelete(context, product.id!),
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
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MENU IMPORT
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _handleImportMenu(BuildContext context) async {
    // Pick file
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select Menu File (Excel or CSV)',
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final path = file.path;
    if (path == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not access the selected file.')),
        );
      }
      return;
    }

    // Parse file
    MenuImportResult importResult;
    final ext = file.extension?.toLowerCase() ?? '';
    if (ext == 'csv') {
      importResult = MenuImportService.parseCsvFile(path);
    } else {
      importResult = MenuImportService.parseExcelFile(path);
    }

    if (!context.mounted) return;

    if (!importResult.hasData) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Import Failed'),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: importResult.errors
                .map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• $e', style: const TextStyle(fontSize: 13)),
                    ))
                .toList(),
          ),
          actions: [
            ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ],
        ),
      );
      return;
    }

    // Show preview dialog
    if (context.mounted) {
      await _showImportPreviewDialog(context, importResult);
    }
  }

  Future<void> _showImportPreviewDialog(
    BuildContext context,
    MenuImportResult importResult,
  ) async {
    final rows = importResult.rows;
    final errors = importResult.errors;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDState) {
          bool importing = false;
          String? importStatus;

          return StatefulBuilder(
            builder: (context, setInner) {
              return Dialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.borderRadius)),
                child: Container(
                  width: 680,
                  constraints: const BoxConstraints(maxHeight: 640),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.upload_file_rounded, color: AppColors.primary, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Import Menu Preview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                Text(
                                  '${rows.length} product${rows.length == 1 ? '' : 's'} ready to import',
                                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: importing ? null : () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),

                      // Warnings / errors from parsing
                      if (errors.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(children: [
                                Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 16),
                                SizedBox(width: 6),
                                Text('Parse Warnings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ]),
                              const SizedBox(height: 6),
                              ...errors.map((e) => Text('• $e', style: TextStyle(fontSize: 11, color: AppColors.textSecondary))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],

                      // Info note
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(children: [
                          Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 15),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'New categories will be created automatically. Existing products with the same name will be skipped.',
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 10),

                      // Table header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.cardBg,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Row(
                          children: [
                            Expanded(flex: 2, child: Text('Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            Expanded(flex: 3, child: Text('Product Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            Expanded(flex: 1, child: Text('Price (Rs.)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            Expanded(flex: 1, child: Text('Cost (Rs.)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          ],
                        ),
                      ),

                      // Scrollable product list
                      Flexible(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: rows.length,
                            separatorBuilder: (_, _a) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final row = rows[i];
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                color: i.isEven ? Colors.transparent : AppColors.cardBg.withValues(alpha: 0.4),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.accent.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(row.categoryName,
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accent),
                                            overflow: TextOverflow.ellipsis),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(flex: 3, child: Text(row.productName, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        'Rs. ${row.sellingPrice.toStringAsFixed(0)}',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Text('Rs. ${row.costPrice.toStringAsFixed(0)}', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                       if (importStatus case final String status) ...[
                        const SizedBox(height: 8),
                        Text(status, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],

                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: importing ? null : () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            icon: importing
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.check_circle_outline_rounded, size: 18),
                            label: Text(importing ? 'Importing...' : 'Import ${rows.length} Products'),
                            onPressed: importing
                                ? null
                                : () async {
                                    setInner(() => importing = true);
                                    await _executeImport(context, rows, setInner);
                                    if (ctx.mounted) Navigator.pop(ctx);
                                  },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _executeImport(
    BuildContext context,
    List<ImportedMenuRow> rows,
    StateSetter setInner,
  ) async {
    final catRepo = CategoryRepository();
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);

    // Load fresh categories
    await categoryProvider.loadCategories();
    List<CategoryModel> cats = List.from(categoryProvider.categories);

    int added = 0;
    int skipped = 0;

    for (final row in rows) {
      // Find or create category
      CategoryModel? cat;
      try {
        cat = cats.firstWhere((c) => c.name.toLowerCase().trim() == row.categoryName.toLowerCase().trim());
      } catch (_) {
        cat = null;
      }

      if (cat == null) {
        // Create new category
        final newCatId = await catRepo.insertCategory(CategoryModel(name: row.categoryName));
        cat = CategoryModel(id: newCatId, name: row.categoryName);
        cats.add(cat);
      }

      // Check if product with same name exists
      final existing = productProvider.products.any(
        (p) => p.name.toLowerCase().trim() == row.productName.toLowerCase().trim(),
      );

      if (existing) {
        skipped++;
        continue;
      }

      // Insert product
      await productProvider.addProduct(
        ProductModel(
          name: row.productName,
          categoryId: cat.id!,
          sellingPrice: row.sellingPrice,
          costPrice: row.costPrice,
          status: 'Active',
        ),
        initialStockQty: 100,
        stockUnit: 'Pcs',
      );
      added++;
    }

    // Reload everything
    await categoryProvider.loadCategories();
    await productProvider.loadProducts();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Import complete: $added added, $skipped skipped (already exist).'),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _showAddEditProductDialog(
    BuildContext context, {
    ProductModel? product,
    required List<dynamic> categories,
    required List<StockItemModel> stockItems,
  }) {

    final nameController = TextEditingController(text: product?.name ?? '');
    final sellPriceController = TextEditingController(text: (product?.sellingPrice ?? 0.0).toString());
    final costPriceController = TextEditingController(text: (product?.costPrice ?? 0.0).toString());
    int selectedCatId = product?.categoryId ?? (categories.isNotEmpty ? categories.first.id : 1);
    String selectedStatus = product?.status ?? 'Active';

    final stockProv = Provider.of<StockProvider>(context, listen: false);
    final existingStock = product != null ? stockProv.findStockByProductName(product.name) : null;

    final stockQtyController = TextEditingController(
      text: existingStock != null ? existingStock.quantity.toString() : (product == null ? '100' : ''),
    );
    String selectedUnit = existingStock?.unit ?? 'Cups';

    const unitOptions = ['Cups', 'Pcs', 'KG', 'Liters', 'Portions', 'Packs', 'Bottles', 'Plates'];
    if (!unitOptions.contains(selectedUnit)) {
      selectedUnit = 'Cups';
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.borderRadius)),
            child: Container(
              width: 580,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product == null ? 'Add New Product' : 'Edit Product',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Direct auto stock deduction on invoice generation',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Product Name',
                            hintText: 'e.g. Karak Chai, Samosa',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: selectedCatId,
                          decoration: const InputDecoration(labelText: 'Category'),
                          items: categories.map((cat) => DropdownMenuItem<int>(
                            value: cat.id,
                            child: Text(cat.name, overflow: TextOverflow.ellipsis),
                          )).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => selectedCatId = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: sellPriceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Selling Price (Rs.)'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: costPriceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Cost Price (Rs.)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // DIRECT STOCK DEDUCTION CARD
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.bolt_rounded, color: AppColors.accent, size: 20),
                            SizedBox(width: 6),
                            Text(
                              'Direct Auto Stock Deduction',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Stock is deducted automatically when an invoice is generated for this product. No complex recipes or ingredient connections required.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: stockQtyController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Available Stock Quantity',
                                  hintText: 'e.g. 50',
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                initialValue: selectedUnit,
                                decoration: const InputDecoration(
                                  labelText: 'Unit',
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                items: unitOptions.map((u) => DropdownMenuItem<String>(
                                  value: u,
                                  child: Text(u),
                                )).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => selectedUnit = val);
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedStatus,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(value: 'Active', child: Text('Active')),
                      DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => selectedStatus = val);
                    },
                  ),

                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () async {
                          if (nameController.text.trim().isEmpty) return;
                          final prodProv = Provider.of<ProductProvider>(context, listen: false);
                          final double sellP = double.tryParse(sellPriceController.text) ?? 0.0;
                          final double costP = double.tryParse(costPriceController.text) ?? 0.0;
                          final double? stockQty = double.tryParse(stockQtyController.text.trim());

                          if (product == null) {
                            await prodProv.addProduct(
                              ProductModel(
                                name: nameController.text.trim(),
                                categoryId: selectedCatId,
                                sellingPrice: sellP,
                                costPrice: costP,
                                status: selectedStatus,
                              ),
                              initialStockQty: stockQty,
                              stockUnit: selectedUnit,
                            );
                          } else {
                            await prodProv.updateProduct(
                              ProductModel(
                                id: product.id,
                                name: nameController.text.trim(),
                                categoryId: selectedCatId,
                                sellingPrice: sellP,
                                costPrice: costP,
                                status: selectedStatus,
                              ),
                              initialStockQty: stockQty,
                              stockUnit: selectedUnit,
                            );
                          }

                          if (context.mounted) {
                            await Provider.of<StockProvider>(context, listen: false).loadStockData();
                          }

                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: const Text('Save Product'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, int productId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product?'),
        content: const Text('Are you sure you want to delete this product?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              await Provider.of<ProductProvider>(context, listen: false).deleteProduct(productId);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}