import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../models/product_model.dart';
import '../providers/stock_provider.dart';
import '../services/stock_deduction_service.dart';
import '../services/unit_conversion_service.dart';

class OutOfStockDialog extends StatefulWidget {
  final ProductModel product;
  final List<DepletedStockItem> depletedItems;
  final VoidCallback onStockAddedAndSelect;

  const OutOfStockDialog({
    super.key,
    required this.product,
    required this.depletedItems,
    required this.onStockAddedAndSelect,
  });

  static Future<void> show({
    required BuildContext context,
    required ProductModel product,
    required List<DepletedStockItem> depletedItems,
    required VoidCallback onStockAddedAndSelect,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => OutOfStockDialog(
        product: product,
        depletedItems: depletedItems,
        onStockAddedAndSelect: onStockAddedAndSelect,
      ),
    );
  }

  @override
  State<OutOfStockDialog> createState() => _OutOfStockDialogState();
}

class _OutOfStockDialogState extends State<OutOfStockDialog> {
  int _selectedItemIndex = 0;
  late final TextEditingController _qtyController;
  late final TextEditingController _notesController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final initialItem = widget.depletedItems.isNotEmpty ? widget.depletedItems[0] : null;
    final defaultQty = initialItem != null
        ? (initialItem.shortage > 0 ? (initialItem.shortage < 1 ? '1' : initialItem.shortage.ceil().toString()) : '10')
        : '10';
    _qtyController = TextEditingController(text: defaultQty);
    _notesController = TextEditingController(text: 'Quick Restock (POS Alert)');
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onItemTabChanged(int index) {
    setState(() {
      _selectedItemIndex = index;
      final item = widget.depletedItems[index];
      final defaultQty = item.shortage > 0
          ? (item.shortage < 1 ? '1' : item.shortage.ceil().toString())
          : '10';
      _qtyController.text = defaultQty;
    });
  }

  Future<void> _handleAddStock() async {
    final double? qty = double.tryParse(_qtyController.text.trim());
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Barahe karam sahi quantity darj karein (e.g. 1, 5, 10).'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (widget.depletedItems.isEmpty) return;
    final currentItem = widget.depletedItems[_selectedItemIndex];

    setState(() {
      _isSubmitting = true;
    });

    try {
      final stockProvider = Provider.of<StockProvider>(context, listen: false);
      await stockProvider.addQuantity(
        stockId: currentItem.stockId,
        stockName: currentItem.stockName,
        qty: qty,
        unit: currentItem.unit,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : 'POS Out-of-Stock Restock',
      );

      if (!mounted) return;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Stock kamiyabi se add ho gaya: +$qty ${currentItem.unit} (${currentItem.stockName})',
          ),
          backgroundColor: AppColors.accent,
          duration: const Duration(seconds: 3),
        ),
      );

      // Automatically add product to cart now that stock is available
      widget.onStockAddedAndSelect();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding stock: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentItem = widget.depletedItems.isNotEmpty
        ? widget.depletedItems[_selectedItemIndex]
        : null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 6,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header with Icon
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.red.shade200, width: 1.5),
                    ),
                    child: Icon(
                      Icons.remove_shopping_cart_rounded,
                      color: Colors.red.shade700,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Stock Khatam Ho Gaya Hai!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF991B1B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Out of Stock: ${widget.product.name}',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 20, color: AppColors.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 2. Info Warning Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFB91C1C)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Is item ka stock khatam ho chuka hai ya kam hai. Stock minus me nahi ja sakta. Isay select karne ke liye pehle stock add karein.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade900,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 3. Multi-item Tabs (if recipe has multiple depleted items)
              if (widget.depletedItems.length > 1) ...[
                Text(
                  'Khatam Shuda Items / Depleted Ingredients:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(widget.depletedItems.length, (i) {
                      final item = widget.depletedItems[i];
                      final isSelected = i == _selectedItemIndex;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          selected: isSelected,
                          label: Text('${item.stockName} (${UnitConversionService.formatQuantity(item.currentStock)} ${item.unit})'),
                          selectedColor: Colors.red.shade100,
                          labelStyle: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.red.shade900 : AppColors.textSecondary,
                          ),
                          onSelected: (_) => _onItemTabChanged(i),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // 4. Current Stock Status Card
              if (currentItem != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 16, color: AppColors.textSecondary),
                              const SizedBox(width: 6),
                              Text(
                                currentItem.stockName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: currentItem.currentStock <= 0 ? Colors.red.shade600 : Colors.orange.shade700,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              currentItem.currentStock <= 0
                                  ? 'Stock: 0 ${currentItem.unit} (Khatam)'
                                  : 'Available: ${UnitConversionService.formatQuantity(currentItem.currentStock)} ${currentItem.unit}',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              (currentItem.ingredientUnit != null && currentItem.ingredientUnit != currentItem.unit)
                                  ? 'Zaroorat (Need): ${UnitConversionService.formatQuantity(currentItem.requiredStock)} ${currentItem.unit} (${UnitConversionService.formatQuantity(currentItem.ingredientRequiredQty ?? 0)} ${currentItem.ingredientUnit})'
                                  : 'Zaroorat (Need): ${UnitConversionService.formatQuantity(currentItem.requiredStock)} ${currentItem.unit}',
                              style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Kami: ${UnitConversionService.formatQuantity(currentItem.shortage)} ${currentItem.unit}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.red.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),

              // 5. Quick Add Stock Section
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green.shade50.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.add_circle_outline_rounded, color: Colors.green.shade800, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Whin py Stock Add Karein (Quick Restock)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _qtyController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Add Quantity (${currentItem?.unit ?? ''})',
                              labelStyle: const TextStyle(fontSize: 12),
                              hintText: 'e.g. 10',
                              isDense: true,
                              filled: true,
                              fillColor: Colors.white,
                              prefixIcon: const Icon(Icons.add_rounded, size: 18),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Quick increment pills
                        Expanded(
                          flex: 2,
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [5, 10, 20].map((quickVal) {
                              return InkWell(
                                onTap: () {
                                  _qtyController.text = quickVal.toString();
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.green.shade300),
                                  ),
                                  child: Text(
                                    '+$quickVal',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade800,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes / Supplier details',
                        labelStyle: TextStyle(fontSize: 12),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: Icon(Icons.edit_note_rounded, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 6. Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: const Text('Cancel / Band Karein'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _handleAddStock,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF166534),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.add_shopping_cart_rounded, size: 18),
                    label: Text(
                      _isSubmitting ? 'Adding...' : 'Stock Add Karein & Select',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}