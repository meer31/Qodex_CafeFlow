import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/constants/app_constants.dart';
import '../models/stock_item_model.dart';
import '../providers/stock_provider.dart';
import '../providers/settings_provider.dart';

class StockManagementScreen extends StatefulWidget {
  const StockManagementScreen({super.key});

  @override
  State<StockManagementScreen> createState() => _StockManagementScreenState();
}

class _StockManagementScreenState extends State<StockManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _inventorySearchController = TextEditingController();
  final TextEditingController _logSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _inventorySearchController.dispose();
    _logSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stockProvider = Provider.of<StockProvider>(context);
    final settings = Provider.of<SettingsProvider>(context).settings;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 720;
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
                      'Stock & Inventory',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Track raw ingredients and stock levels',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded),
                          tooltip: 'Refresh Stock & Inventory',
                          onPressed: () => stockProvider.loadStockData(),
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add_box_rounded, size: 16),
                          label: const Text('Add Stock Item', style: TextStyle(fontSize: 12)),
                          onPressed: () => _showAddEditStockModal(context),
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
                          'Stock & Inventory Management',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Track raw ingredients, stock levels, and automated recipe deductions',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded),
                          tooltip: 'Refresh Stock & Inventory',
                          onPressed: () => stockProvider.loadStockData(),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add_box_rounded),
                          label: const Text('Add New Stock Item'),
                          onPressed: () => _showAddEditStockModal(context),
                        ),
                      ],
                    ),
                  ],
                ),
              const SizedBox(height: 16),

              // Tabs: Current Inventory vs Stock Transaction Log
              TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                tabs: const [
                  Tab(text: 'Current Stock Inventory'),
                  Tab(text: 'Stock Transaction Log (Audit Trail)'),
                ],
              ),
              const SizedBox(height: 16),

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // TAB 1: Inventory Table
                    _buildInventoryTab(context, stockProvider, settings.currencySymbol),

                    // TAB 2: Audit Trail Log
                    _buildAuditLogTab(context, stockProvider),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInventoryTab(BuildContext context, StockProvider stockProvider, String currency) {
    if (stockProvider.isLoading) return const Center(child: CircularProgressIndicator());

    final searchQuery = _inventorySearchController.text.trim().toLowerCase();
    final filteredList = stockProvider.stockList.where((item) {
      final matchesName = item.name.toLowerCase().contains(searchQuery);
      final matchesUnit = item.unit.toLowerCase().contains(searchQuery);
      return matchesName || matchesUnit;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 350),
          child: TextField(
            controller: _inventorySearchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search stock items by name or unit...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _inventorySearchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _inventorySearchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              border: Border.all(color: AppColors.border),
            ),
            child: filteredList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 48, color: AppColors.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          _inventorySearchController.text.isNotEmpty
                              ? 'No stock items match "${_inventorySearchController.text}"'
                              : 'No stock items in inventory',
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
                        columns: const [
                          DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('ID', style: TextStyle(fontWeight: FontWeight.bold))))),
                          DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Stock Name', style: TextStyle(fontWeight: FontWeight.bold))))),
                          DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Current Quantity', style: TextStyle(fontWeight: FontWeight.bold))))),
                          DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Unit', style: TextStyle(fontWeight: FontWeight.bold))))),
                          DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Cost/Unit', style: TextStyle(fontWeight: FontWeight.bold))))),
                          DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Low Stock Alert', style: TextStyle(fontWeight: FontWeight.bold))))),
                          DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))))),
                          DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))))),
                        ],
                        rows: filteredList.map((item) {
                          final isLow = item.isLowStock;
                          return DataRow(cells: [
                            DataCell(Text('#${item.id}')),
                            DataCell(Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(Text(
                              '${item.quantity.toStringAsFixed(2)} ${item.unit}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isLow ? AppColors.error : AppColors.secondary,
                              ),
                            )),
                            DataCell(Text(item.unit)),
                            DataCell(Text('$currency ${item.costPerUnit.toStringAsFixed(0)}')),
                            DataCell(Text('<= ${item.minThreshold.toStringAsFixed(1)} ${item.unit}')),
                            DataCell(Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isLow ? AppColors.error.withOpacity(0.15) : AppColors.accent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isLow ? 'LOW STOCK' : 'OPTIMAL',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isLow ? AppColors.error : AppColors.accent,
                                ),
                              ),
                            )),
                            DataCell(Row(
                              children: [
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    backgroundColor: AppColors.accent,
                                  ),
                                  icon: const Icon(Icons.add_rounded, size: 16),
                                  label: const Text('Stock IN', style: TextStyle(fontSize: 12)),
                                  onPressed: () => _showAddQuantityModal(context, item),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
                                  onPressed: () => _showAddEditStockModal(context, stock: item),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                                  onPressed: () => _confirmDelete(context, item.id!),
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

  Widget _buildAuditLogTab(BuildContext context, StockProvider stockProvider) {
    final logs = stockProvider.transactions;
    final searchQuery = _logSearchController.text.trim().toLowerCase();

    final filteredLogs = logs.where((log) {
      final matchName = log.stockName.toLowerCase().contains(searchQuery);
      final matchType = log.type.toLowerCase().contains(searchQuery);
      final matchInvoice = (log.invoiceNumber ?? '').toLowerCase().contains(searchQuery);
      final matchNotes = (log.notes ?? '').toLowerCase().contains(searchQuery);
      return matchName || matchType || matchInvoice || matchNotes;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 350),
          child: TextField(
            controller: _logSearchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search audit logs by item, type, invoice...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _logSearchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _logSearchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              border: Border.all(color: AppColors.border),
            ),
            child: filteredLogs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 48, color: AppColors.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          _logSearchController.text.isNotEmpty
                              ? 'No audit logs match "${_logSearchController.text}"'
                              : 'No stock transactions logged yet',
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
                        columns: const [
                          DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Date & Time', style: TextStyle(fontWeight: FontWeight.bold))))),
                          DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Item Name', style: TextStyle(fontWeight: FontWeight.bold))))),
                          DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))))),
                          DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Quantity Change', style: TextStyle(fontWeight: FontWeight.bold))))),
                          DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Invoice Ref', style: TextStyle(fontWeight: FontWeight.bold))))),
                          DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Notes', style: TextStyle(fontWeight: FontWeight.bold))))),
                        ],
                        rows: filteredLogs.map((log) {
                          final isDeduction = log.type == 'OUT_SALE';
                          return DataRow(cells: [
                            DataCell(Text(log.dateTime.replaceFirst('T', ' ').substring(0, 16))),
                            DataCell(Text(log.stockName, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDeduction ? AppColors.warning.withOpacity(0.15) : AppColors.accent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                log.type,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDeduction ? AppColors.warning : AppColors.accent,
                                ),
                              ),
                            )),
                            DataCell(Text(
                              '${isDeduction ? '-' : '+'}${log.quantity.toStringAsFixed(3)} ${log.unit}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDeduction ? AppColors.error : AppColors.accent,
                              ),
                            )),
                            DataCell(Text(log.invoiceNumber ?? '-')),
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

  void _showAddEditStockModal(BuildContext context, {StockItemModel? stock}) {
    final nameController = TextEditingController(text: stock?.name ?? '');
    final qtyController = TextEditingController(text: (stock?.quantity ?? 0.0).toString());
    final minController = TextEditingController(text: (stock?.minThreshold ?? 5.0).toString());
    final costController = TextEditingController(text: (stock?.costPerUnit ?? 0.0).toString());
    String selectedUnit = stock?.unit ?? AppConstants.inventoryUnits.first;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(stock == null ? 'Add New Stock Item' : 'Edit Stock Item'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Item Name (e.g. Milk, Sugar, Chicken)'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedUnit,
                decoration: const InputDecoration(labelText: 'Unit of Measurement'),
                items: AppConstants.inventoryUnits.map((u) => DropdownMenuItem<String>(
                  value: u,
                  child: Text(u),
                )).toList(),
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
                      decoration: const InputDecoration(labelText: 'Current Quantity'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: minController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Min Alert Threshold'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: costController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Cost Per Unit (Rs.)'),
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
                ));
              } else {
                await stockProv.updateStockItem(StockItemModel(
                  id: stock.id,
                  name: nameController.text.trim(),
                  unit: selectedUnit,
                  quantity: double.tryParse(qtyController.text) ?? stock.quantity,
                  minThreshold: double.tryParse(minController.text) ?? stock.minThreshold,
                  costPerUnit: double.tryParse(costController.text) ?? stock.costPerUnit,
                ));
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save Stock Item'),
          ),
        ],
      ),
    );
  }

  void _showAddQuantityModal(BuildContext context, StockItemModel item) {
    final qtyController = TextEditingController();
    final notesController = TextEditingController(text: 'Purchase restock');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Stock IN: ${item.name}'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Current Level: ${item.quantity} ${item.unit}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: qtyController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'Added Quantity (${item.unit})'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Notes / Supplier details'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final double q = double.tryParse(qtyController.text) ?? 0.0;
              if (q <= 0) return;
              await Provider.of<StockProvider>(context, listen: false).addQuantity(
                stockId: item.id!,
                stockName: item.name,
                qty: q,
                unit: item.unit,
                notes: notesController.text,
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Confirm Stock IN'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, int stockId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Stock Item?'),
        content: const Text('Are you sure you want to delete this stock item?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              await Provider.of<StockProvider>(context, listen: false).deleteStockItem(stockId);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}