import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../models/product_model.dart';
import '../models/recipe_item_model.dart';
import '../models/stock_item_model.dart';
import '../providers/product_provider.dart';
import '../providers/stock_provider.dart';
import '../providers/settings_provider.dart';
import '../services/unit_conversion_service.dart';

class RecipeConfigDialog extends StatefulWidget {
  final ProductModel product;

  const RecipeConfigDialog({
    super.key,
    required this.product,
  });

  static Future<void> show(BuildContext context, ProductModel product) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => RecipeConfigDialog(product: product),
    );
  }

  @override
  State<RecipeConfigDialog> createState() => _RecipeConfigDialogState();
}

class _RecipeIngredientRow {
  int? stockId;
  String stockName = '';
  TextEditingController quantityController = TextEditingController(text: '1');
  String unit = 'Gram';
  bool isMilkDerived = false;

  _RecipeIngredientRow({
    this.stockId,
    this.stockName = '',
    String qty = '1',
    this.unit = 'Gram',
    this.isMilkDerived = false,
  }) {
    quantityController.text = qty;
  }

  void dispose() {
    quantityController.dispose();
  }
}

class _RecipeConfigDialogState extends State<RecipeConfigDialog> {
  final List<_RecipeIngredientRow> _rows = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final existingRecipes = widget.product.recipeItems;

    if (existingRecipes.isNotEmpty) {
      for (var item in existingRecipes) {
        _rows.add(_RecipeIngredientRow(
          stockId: item.stockId,
          stockName: item.stockName,
          qty: item.quantity.toString().replaceAll(RegExp(r'\.0$'), ''),
          unit: item.unit,
          isMilkDerived: item.isMilkDerived,
        ));
      }
    } else {
      // Start with 1 blank row for quick entry
      _rows.add(_RecipeIngredientRow());
    }
  }

  @override
  void dispose() {
    for (var r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _addRow() {
    setState(() {
      _rows.add(_RecipeIngredientRow());
    });
  }

  void _removeRow(int index) {
    setState(() {
      final r = _rows.removeAt(index);
      r.dispose();
    });
  }

  double _calculateRowCost(_RecipeIngredientRow row, List<StockItemModel> stockList) {
    if (row.stockId == null) return 0.0;
    final stock = stockList.firstWhere(
      (s) => s.id == row.stockId,
      orElse: () => StockItemModel(id: -1, name: '', unit: '', quantity: 0),
    );
    if (stock.id == -1 || stock.costPerUnit <= 0) return 0.0;

    final qty = double.tryParse(row.quantityController.text.trim()) ?? 0.0;
    if (qty <= 0) return 0.0;

    final convertedQty = UnitConversionService.convertQuantity(
      quantity: qty,
      fromUnit: row.unit,
      toUnit: stock.unit,
    );

    return convertedQty * stock.costPerUnit;
  }

  Future<void> _saveRecipe(BuildContext context) async {
    final stockList = Provider.of<StockProvider>(context, listen: false).stockList;
    final List<RecipeItemModel> validItems = [];

    for (var r in _rows) {
      if (r.stockId == null) continue;
      final qty = double.tryParse(r.quantityController.text.trim()) ?? 0.0;
      if (qty <= 0) continue;

      final stock = stockList.firstWhere(
        (s) => s.id == r.stockId,
        orElse: () => StockItemModel(id: r.stockId!, name: r.stockName, unit: r.unit, quantity: 0),
      );

      validItems.add(RecipeItemModel(
        productId: widget.product.id!,
        stockId: r.stockId!,
        stockName: stock.name,
        quantity: qty,
        unit: r.unit.isNotEmpty ? r.unit : stock.unit,
        isMilkDerived: r.isMilkDerived,
      ));
    }

    setState(() => _isSaving = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      await productProvider.updateProductRecipe(widget.product.id!, validItems);

      if (mounted) {
        navigator.pop();
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  validItems.isEmpty
                      ? 'Recipe cleared for ${widget.product.name}'
                      : 'Recipe saved! ${validItems.length} ingredients will auto-deduct when ${widget.product.name} is ordered.',
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (err) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to save recipe: $err'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final stockProvider = Provider.of<StockProvider>(context);
    final settings = Provider.of<SettingsProvider>(context).settings;
    final stockList = stockProvider.stockList;
    final currency = settings.currencySymbol;

    double totalRecipeCost = 0.0;
    for (var r in _rows) {
      totalRecipeCost += _calculateRowCost(r, stockList);
    }
    final sellingPrice = widget.product.sellingPrice;
    final profitMargin = sellingPrice - totalRecipeCost;
    final marginPercent = sellingPrice > 0 ? ((profitMargin / sellingPrice) * 100.0) : 0.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 680),
        child: Column(
          children: [
            // ── Dialog Header ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              color: AppColors.cardBg,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.menu_book_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              widget.product.name,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (widget.product.categoryName != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  widget.product.categoryName!,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Configure Raw Materials for automatic stock deduction upon sale',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: AppColors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // ── Product Quick Stats & Helper Banner ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: const Color(0xFFF8FAFC),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.auto_fix_high_rounded, size: 16, color: Color(0xFF0284C7)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Each time 1x "${widget.product.name}" is sold, CafeFlow deducts the portions below.',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF0F172A)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      'Price: $currency ${sellingPrice.toStringAsFixed(0)}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // ── Scrollable Recipe Rows ──
            Expanded(
              child: stockList.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.textMuted),
                            const SizedBox(height: 12),
                            const Text(
                              'No Raw Materials Found in Inventory',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Add ingredients (e.g. Milk, Coffee Beans, Sugar, Patties) in Raw Materials first.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.add_box_rounded, size: 18),
                              label: const Text('Add Raw Material'),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'RECIPE INGREDIENTS (${_rows.length})',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _addRow,
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text(
                                'Add Ingredient',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        ...List.generate(_rows.length, (index) {
                          return _buildIngredientCard(index, stockList, currency);
                        }),

                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _addRow,
                          icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                          label: const Text(
                            '+ Add Another Ingredient to Recipe',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
            ),

            const Divider(height: 1),

            // ── Live Costing & Bottom Bar ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              color: const Color(0xFFF8FAFC),
              child: Row(
                children: [
                  // Calculated Cost Summary
                  Expanded(
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'RAW MATERIAL COST',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                            ),
                            Text(
                              '$currency ${totalRecipeCost.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: totalRecipeCost > sellingPrice ? Colors.red.shade700 : AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'EST. MARGIN',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                            ),
                            Text(
                              '$currency ${profitMargin.toStringAsFixed(1)} (${marginPercent.toStringAsFixed(0)}%)',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: profitMargin >= 0 ? const Color(0xFF10B981) : Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Actions
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded, size: 18),
                    label: Text(
                      _isSaving ? 'Saving...' : 'Save Recipe',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: _isSaving ? null : () => _saveRecipe(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIngredientCard(int index, List<StockItemModel> stockList, String currency) {
    final row = _rows[index];
    final rowCost = _calculateRowCost(row, stockList);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Raw Material Dropdown
              Expanded(
                flex: 4,
                child: DropdownButtonFormField<int>(
                  isDense: true,
                  initialValue: stockList.any((s) => s.id == row.stockId) ? row.stockId : null,
                  hint: const Text('Select Raw Material / Ingredient', style: TextStyle(fontSize: 13)),
                  decoration: InputDecoration(
                    labelText: 'Raw Material',
                    labelStyle: const TextStyle(fontSize: 11),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                  items: stockList.map((stock) {
                    return DropdownMenuItem<int>(
                      value: stock.id,
                      child: Text(
                        '${stock.name} (${stock.quantity.toStringAsFixed(1)} ${stock.unit} in stock)',
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (newId) {
                    if (newId != null) {
                      final selectedStock = stockList.firstWhere((s) => s.id == newId);
                      setState(() {
                        row.stockId = newId;
                        row.stockName = selectedStock.name;
                        // Pick default portion unit matching stock unit or friendly gram/ml
                        final sUnit = selectedStock.unit.toLowerCase();
                        if (sUnit == 'kg' || sUnit == 'kilogram') {
                          row.unit = 'Gram';
                        } else if (sUnit == 'litre' || sUnit == 'liter' || sUnit == 'l') {
                          row.unit = 'ML';
                        } else {
                          row.unit = selectedStock.unit;
                        }
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),

              // 2. Quantity input
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: row.quantityController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Portion Qty',
                    labelStyle: const TextStyle(fontSize: 11),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),

              // 3. Unit selector
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  isDense: true,
                  initialValue: row.unit,
                  decoration: InputDecoration(
                    labelText: 'Unit',
                    labelStyle: const TextStyle(fontSize: 11),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Gram', child: Text('Gram', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'KG', child: Text('KG', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'ML', child: Text('ML', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'Litre', child: Text('Litre', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'Piece', child: Text('Piece', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'Packet', child: Text('Packet', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'Cup', child: Text('Cup', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'Slice', child: Text('Slice', style: TextStyle(fontSize: 12))),
                  ],
                  onChanged: (newUnit) {
                    if (newUnit != null) {
                      setState(() => row.unit = newUnit);
                    }
                  },
                ),
              ),
              const SizedBox(width: 6),

              // 4. Delete row button
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                tooltip: 'Remove Ingredient',
                onPressed: () => _removeRow(index),
              ),
            ],
          ),
          if (row.stockId != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'Estimated Ingredient Cost: $currency ${rowCost.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ],
      ),
    );
  }
}