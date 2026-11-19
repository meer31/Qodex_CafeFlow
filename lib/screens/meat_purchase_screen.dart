import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../providers/meat_purchase_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/stock_provider.dart';
import '../services/invoice_service.dart';
import '../models/meat_purchase_model.dart';
import '../models/app_settings_model.dart';

class MeatPurchaseScreen extends StatefulWidget {
  const MeatPurchaseScreen({super.key});

  @override
  State<MeatPurchaseScreen> createState() => _MeatPurchaseScreenState();
}

class _MeatPurchaseScreenState extends State<MeatPurchaseScreen> {
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();
  String _searchQuery = '';
  int _meatTabIndex = 0; // 0: Create Invoice, 1: Purchase History (used on compact screens)

  @override
  void dispose() {
    _qtyController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meatProvider = Provider.of<MeatPurchaseProvider>(context);
    final settings = Provider.of<SettingsProvider>(context).settings;
    final currency = settings.currencySymbol;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 960;

        if (isCompact) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Top Segmented Bar for Compact/Mobile/Tablet screens
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _meatTabIndex == 0 ? AppColors.primary : Colors.transparent,
                            foregroundColor: _meatTabIndex == 0 ? Colors.white : AppColors.textPrimary,
                            elevation: _meatTabIndex == 0 ? 2 : 0,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                          label: const Text('New Invoice', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          onPressed: () => setState(() => _meatTabIndex = 0),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _meatTabIndex == 1 ? AppColors.primary : Colors.transparent,
                            foregroundColor: _meatTabIndex == 1 ? Colors.white : AppColors.textPrimary,
                            elevation: _meatTabIndex == 1 ? 2 : 0,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          icon: const Icon(Icons.history_rounded, size: 18),
                          label: Text(
                            'History (${meatProvider.purchases.length})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          onPressed: () => setState(() => _meatTabIndex = 1),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _meatTabIndex == 0
                      ? _buildCreateInvoicePanel(context, meatProvider, settings, currency, isCompact: true)
                      : _buildHistoryPanel(context, meatProvider, settings, currency),
                ),
              ],
            ),
          );
        }

        // Wide screen layout (side-by-side)
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── LEFT PANEL: Create New Meat Invoice ──
              Expanded(
                flex: 5,
                child: _buildCreateInvoicePanel(context, meatProvider, settings, currency, isCompact: false),
              ),

              const SizedBox(width: 20),

              // ── RIGHT PANEL: Purchase History ──
              Expanded(
                flex: 4,
                child: _buildHistoryPanel(context, meatProvider, settings, currency),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCreateInvoicePanel(
    BuildContext context,
    MeatPurchaseProvider meatProvider,
    AppSettingsModel settings,
    String currency, {
    required bool isCompact,
  }) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 16 : 24),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Create Meat Purchase Invoice',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            'Add meat items to generate a purchase invoice for closing-time calculations',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),

          // ── Responsive Input Row: Meat Type, Qty, Rate, Add Button ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: LayoutBuilder(
              builder: (context, inputConstraints) {
                final isNarrowForm = inputConstraints.maxWidth < 460;

                if (isNarrowForm) {
                  return Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: meatProvider.selectedMeatType,
                        decoration: const InputDecoration(
                          labelText: 'Meat Category',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: ['Chicken', 'Beef', 'Mutton'].map((type) {
                          return DropdownMenuItem(value: type, child: Text(type));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) meatProvider.setMeatType(val);
                        },
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _qtyController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Quantity (KG)',
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              onChanged: (val) {
                                meatProvider.setQuantityKg(double.tryParse(val) ?? 0.0);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _rateController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Rate / KG',
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              onChanged: (val) {
                                meatProvider.setRatePerKg(double.tryParse(val) ?? 0.0);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add_circle_rounded, size: 20),
                          label: const Text('Add Item To Invoice', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            meatProvider.addItemToInvoice();
                            _qtyController.clear();
                            _rateController.clear();
                          },
                        ),
                      ),
                    ],
                  );
                }

                // Wide input form (Row layout)
                return Column(
                  children: [
                    Row(
                      children: [
                        // Meat Type Dropdown
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: meatProvider.selectedMeatType,
                            decoration: const InputDecoration(
                              labelText: 'Meat Category',
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            items: ['Chicken', 'Beef', 'Mutton'].map((type) {
                              return DropdownMenuItem(value: type, child: Text(type));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) meatProvider.setMeatType(val);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Quantity KG
                        Expanded(
                          child: TextField(
                            controller: _qtyController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Quantity (KG)',
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onChanged: (val) {
                              meatProvider.setQuantityKg(double.tryParse(val) ?? 0.0);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Rate per KG
                        Expanded(
                          child: TextField(
                            controller: _rateController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Rate / KG',
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onChanged: (val) {
                              meatProvider.setRatePerKg(double.tryParse(val) ?? 0.0);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Add Item Button
                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add_circle_rounded, size: 20),
                        label: const Text('Add Item To Invoice', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          meatProvider.addItemToInvoice();
                          _qtyController.clear();
                          _rateController.clear();
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // ── Current Invoice Items Table ──
          Expanded(
            child: meatProvider.currentItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.textMuted),
                        SizedBox(height: 12),
                        Text('No items added yet', style: TextStyle(color: AppColors.textMuted)),
                        Text('Add meat items above to build the invoice', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: constraints.maxWidth),
                            child: DataTable(
                              columnSpacing: isCompact ? 16 : 24,
                              columns: const [
                                DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))))),
                                DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Qty (KG)', style: TextStyle(fontWeight: FontWeight.bold))))),
                                DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Rate/KG', style: TextStyle(fontWeight: FontWeight.bold))))),
                                DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold))))),
                                DataColumn(label: Text('', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: meatProvider.currentItems.asMap().entries.map((entry) {
                                final index = entry.key;
                                final item = entry.value;
                                return DataRow(cells: [
                                  DataCell(Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        item.meatType == 'Chicken'
                                            ? Icons.egg_alt_rounded
                                            : item.meatType == 'Beef'
                                                ? Icons.lunch_dining_rounded
                                                : Icons.kebab_dining_rounded,
                                        size: 16,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(item.meatType, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    ],
                                  )),
                                  DataCell(Text('${item.quantityKg.toStringAsFixed(2)} KG')),
                                  DataCell(Text('$currency ${item.ratePerKg.toStringAsFixed(0)}')),
                                  DataCell(Text(
                                    '$currency ${item.totalAmount.toStringAsFixed(0)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  )),
                                  DataCell(IconButton(
                                    icon: Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18),
                                    onPressed: () => meatProvider.removeItemFromInvoice(index),
                                  )),
                                ]);
                              }).toList(),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // ── Grand Total & Action Buttons ──
          const Divider(),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (meatProvider.currentItems.isNotEmpty)
                TextButton.icon(
                  icon: Icon(Icons.clear_all_rounded, color: AppColors.error, size: 18),
                  label: Text('Clear All', style: TextStyle(color: AppColors.error)),
                  onPressed: () => meatProvider.clearCurrentInvoice(),
                )
              else
                const SizedBox(),

              Text(
                'TOTAL: $currency ${meatProvider.currentGrandTotal.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              icon: meatProvider.isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save_rounded, size: 20),
              label: Text(
                meatProvider.isSaving ? 'Saving...' : 'Save & Print Meat Invoice',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.borderRadius)),
              ),
              onPressed: meatProvider.isSaving
                  ? null
                  : () async {
                      final purchase = await meatProvider.saveInvoice(
                        onError: (err) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(err), backgroundColor: AppColors.error),
                          );
                        },
                      );

                      if (purchase != null && context.mounted) {
                        Provider.of<StockProvider>(context, listen: false).loadStockData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Meat Invoice #${purchase.invoiceNumber} saved!'),
                            backgroundColor: AppColors.accent,
                          ),
                        );
                        await InvoiceService.printMeatPurchaseInvoice(
                          purchase: purchase,
                          settings: settings,
                        );
                      }
                    },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryPanel(
    BuildContext context,
    MeatPurchaseProvider meatProvider,
    AppSettingsModel settings,
    String currency,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Invoice History',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Refresh Invoices & Stock',
                onPressed: () async {
                  await meatProvider.loadPurchases();
                  if (context.mounted) {
                    await Provider.of<StockProvider>(context, listen: false).loadStockData();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Search
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: const InputDecoration(
              hintText: 'Search by Invoice #...',
              prefixIcon: Icon(Icons.search_rounded),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          const SizedBox(height: 14),

          // History List
          Expanded(
            child: meatProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : Builder(builder: (context) {
                    final filtered = meatProvider.purchases.where((p) {
                      return _searchQuery.isEmpty ||
                          p.invoiceNumber.toLowerCase().contains(_searchQuery.toLowerCase());
                    }).toList();

                    if (filtered.isEmpty) {
                      return Center(child: Text('No meat invoices yet', style: TextStyle(color: AppColors.textMuted)));
                    }

                    return ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const Divider(height: 8),
                      itemBuilder: (context, index) {
                        final purchase = filtered[index];
                        return LayoutBuilder(
                          builder: (context, cardConstraints) {
                            final isCardNarrow = cardConstraints.maxWidth < 360;

                            if (isCardNarrow) {
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.cardBg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          purchase.invoiceNumber,
                                          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13),
                                        ),
                                        Text(
                                          '$currency ${purchase.grandTotal.toStringAsFixed(0)}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      purchase.dateTime.replaceFirst('T', ' ').substring(0, 16),
                                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${purchase.items.length} item${purchase.items.length > 1 ? 's' : ''} — ${purchase.items.map((i) => i.meatType).toSet().join(', ')}',
                                      style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        IconButton(
                                          icon: Icon(Icons.print_rounded, color: AppColors.primary, size: 18),
                                          tooltip: 'Print',
                                          onPressed: () async {
                                            await InvoiceService.printMeatPurchaseInvoice(
                                              purchase: purchase,
                                              settings: settings,
                                            );
                                          },
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.visibility_outlined, color: AppColors.secondary, size: 18),
                                          tooltip: 'View Details',
                                          onPressed: () => _showPurchaseDetails(context, purchase, currency),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18),
                                          tooltip: 'Delete',
                                          onPressed: () => _handleDeleteInvoice(context, meatProvider, purchase),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }

                            // Standard card
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.cardBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  // Invoice info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          purchase.invoiceNumber,
                                          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          purchase.dateTime.replaceFirst('T', ' ').substring(0, 16),
                                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${purchase.items.length} item${purchase.items.length > 1 ? 's' : ''} — ${purchase.items.map((i) => i.meatType).toSet().join(', ')}',
                                          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Total
                                  Text(
                                    '$currency ${purchase.grandTotal.toStringAsFixed(0)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  const SizedBox(width: 8),

                                  // Actions
                                  IconButton(
                                    icon: Icon(Icons.print_rounded, color: AppColors.primary, size: 20),
                                    tooltip: 'Print',
                                    onPressed: () async {
                                      await InvoiceService.printMeatPurchaseInvoice(
                                        purchase: purchase,
                                        settings: settings,
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.visibility_outlined, color: AppColors.secondary, size: 20),
                                    tooltip: 'View Details',
                                    onPressed: () => _showPurchaseDetails(context, purchase, currency),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                                    tooltip: 'Delete',
                                    onPressed: () => _handleDeleteInvoice(context, meatProvider, purchase),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    );
                  }),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteInvoice(BuildContext context, MeatPurchaseProvider meatProvider, MeatPurchaseModel purchase) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Invoice?'),
        content: Text('Delete meat invoice ${purchase.invoiceNumber}? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await meatProvider.deletePurchase(purchase.id!);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invoice deleted'), backgroundColor: AppColors.accent),
        );
      }
    }
  }

  void _showPurchaseDetails(BuildContext context, MeatPurchaseModel purchase, String currency) {
    final settings = Provider.of<SettingsProvider>(context, listen: false).settings;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Meat Invoice #${purchase.invoiceNumber}'),
        content: SizedBox(
          width: 450,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      Text(
                        settings.cafeName.trim().isNotEmpty ? settings.cafeName : 'Cafe Indus',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                        textAlign: TextAlign.center,
                      ),
                      if (settings.address.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          settings.address,
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      if (settings.phone.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Ph: ${settings.phone}',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 8),
                      const Divider(),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text('Date: ${purchase.dateTime.replaceFirst('T', ' ').substring(0, 16)}'),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                const Text('ITEMS:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 8),
                ...purchase.items.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${item.meatType} — ${item.quantityKg.toStringAsFixed(2)} KG @ $currency ${item.ratePerKg.toStringAsFixed(0)}/KG',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Text('$currency ${item.totalAmount.toStringAsFixed(0)}'),
                        ],
                      ),
                    )),
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('GRAND TOTAL:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('$currency ${purchase.grandTotal.toStringAsFixed(2)}',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
}