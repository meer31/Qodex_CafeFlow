import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../models/sale_model.dart';
import '../providers/table_provider.dart';
import '../providers/waiter_provider.dart';
import '../providers/settings_provider.dart';
import '../services/invoice_service.dart';

class InvoiceDialogs {
  /// Shows modal to edit an existing invoice (Table, Waiter, Customer, Payment Method, Discount, Status, Number)
  static Future<bool?> showEditDialog({
    required BuildContext context,
    required SaleModel sale,
    required Future<void> Function(SaleModel updatedSale, String oldInvoiceNumber) onSave,
  }) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false).settings;
    final tableProvider = Provider.of<TableProvider>(context, listen: false);
    final waiterProvider = Provider.of<WaiterProvider>(context, listen: false);
    final currency = settings.currencySymbol;

    final invoiceNumController = TextEditingController(text: sale.invoiceNumber);
    final customerNameController = TextEditingController(text: sale.customerName ?? '');
    final customerPhoneController = TextEditingController(text: sale.customerPhone ?? '');
    final discountController = TextEditingController(text: sale.discount.toStringAsFixed(0));
    final taxController = TextEditingController(text: sale.tax.toStringAsFixed(0));

    int? selectedTableId = sale.tableId;
    int? selectedWaiterId = sale.waiterId;
    String selectedPaymentMethod = sale.paymentMethod;
    String selectedStatus = sale.status;

    final formKey = GlobalKey<FormState>();

    return showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final double currentDiscount = double.tryParse(discountController.text.trim()) ?? 0.0;
          final double currentTax = double.tryParse(taxController.text.trim()) ?? 0.0;
          final double calculatedTotal = (sale.subtotal - currentDiscount + currentTax).clamp(0.0, double.infinity);

          return AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '#${sale.invoiceNumber}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Text('Edit Invoice Details', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 540,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 1: Invoice Number & Status
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: invoiceNumController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Invoice Number (Whole Number)',
                                prefixIcon: Icon(Icons.tag_rounded),
                                hintText: 'e.g. 1, 2, 3',
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Enter invoice number';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              initialValue: ['CLEARED', 'REMAINING', 'COMPLETED', 'CANCELLED'].contains(selectedStatus.toUpperCase())
                                  ? selectedStatus.toUpperCase()
                                  : 'CLEARED',
                              decoration: const InputDecoration(
                                labelText: 'Status',
                                prefixIcon: Icon(Icons.info_outline_rounded),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'CLEARED', child: Text('CLEARED (Paid)')),
                                DropdownMenuItem(value: 'REMAINING', child: Text('REMAINING (Unpaid)')),
                                DropdownMenuItem(value: 'COMPLETED', child: Text('COMPLETED')),
                                DropdownMenuItem(value: 'CANCELLED', child: Text('CANCELLED')),
                              ],
                              onChanged: (val) {
                                if (val != null) setModalState(() => selectedStatus = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Row 2: Table & Waiter Selection
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int?>(
                              initialValue: tableProvider.tables.any((t) => t.id == selectedTableId)
                                  ? selectedTableId
                                  : null,
                              decoration: const InputDecoration(
                                labelText: 'Table',
                                prefixIcon: Icon(Icons.table_restaurant_rounded),
                              ),
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('Takeaway / Counter'),
                                ),
                                ...tableProvider.tables.map((t) => DropdownMenuItem<int?>(
                                  value: t.id,
                                  child: Text('${t.tableName} (${t.sectionName})'),
                                )),
                              ],
                              onChanged: (val) {
                                setModalState(() => selectedTableId = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<int?>(
                              initialValue: waiterProvider.waiters.any((w) => w.id == selectedWaiterId)
                                  ? selectedWaiterId
                                  : null,
                              decoration: const InputDecoration(
                                labelText: 'Waiter',
                                prefixIcon: Icon(Icons.person_outline_rounded),
                              ),
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('No Waiter Assigned'),
                                ),
                                ...waiterProvider.waiters.map((w) => DropdownMenuItem<int?>(
                                  value: w.id,
                                  child: Text(w.name),
                                )),
                              ],
                              onChanged: (val) {
                                setModalState(() => selectedWaiterId = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Row 3: Customer Details
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: customerNameController,
                              decoration: const InputDecoration(
                                labelText: 'Customer Name',
                                prefixIcon: Icon(Icons.badge_outlined),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: customerPhoneController,
                              decoration: const InputDecoration(
                                labelText: 'Phone Number',
                                prefixIcon: Icon(Icons.phone_outlined),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Row 4: Payment Method, Discount & Tax
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedPaymentMethod,
                              decoration: const InputDecoration(
                                labelText: 'Payment Method',
                                prefixIcon: Icon(Icons.payment_rounded),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                                DropdownMenuItem(value: 'Card', child: Text('Card')),
                                DropdownMenuItem(value: 'Digital Wallet', child: Text('Digital Wallet')),
                                DropdownMenuItem(value: 'Online', child: Text('Online')),
                              ],
                              onChanged: (val) {
                                if (val != null) setModalState(() => selectedPaymentMethod = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              controller: discountController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Discount ($currency)',
                                prefixIcon: const Icon(Icons.discount_outlined),
                              ),
                              onChanged: (_) => setModalState(() {}),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              controller: taxController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Tax ($currency)',
                                prefixIcon: const Icon(Icons.receipt_outlined),
                              ),
                              onChanged: (_) => setModalState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Financial Summary Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Subtotal:'),
                                Text('$currency ${sale.subtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Discount:'),
                                Text('- $currency ${currentDiscount.toStringAsFixed(2)}', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Tax:'),
                                Text('+ $currency ${currentTax.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const Divider(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Grand Total:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                Text(
                                  '$currency ${calculatedTotal.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Save Changes'),
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;

                  String? newTableName;
                  if (selectedTableId != null) {
                    final found = tableProvider.tables.where((t) => t.id == selectedTableId);
                    if (found.isNotEmpty) newTableName = found.first.tableName;
                  }

                  String? newWaiterName;
                  if (selectedWaiterId != null) {
                    final found = waiterProvider.waiters.where((w) => w.id == selectedWaiterId);
                    if (found.isNotEmpty) newWaiterName = found.first.name;
                  }

                  final oldInv = sale.invoiceNumber;
                  final updatedSale = sale.copyWith(
                    invoiceNumber: invoiceNumController.text.trim(),
                    tableId: selectedTableId,
                    tableName: newTableName,
                    waiterId: selectedWaiterId,
                    waiterName: newWaiterName,
                    customerName: customerNameController.text.trim().isEmpty ? null : customerNameController.text.trim(),
                    customerPhone: customerPhoneController.text.trim().isEmpty ? null : customerPhoneController.text.trim(),
                    discount: currentDiscount,
                    tax: currentTax,
                    grandTotal: calculatedTotal,
                    paymentMethod: selectedPaymentMethod,
                    status: selectedStatus,
                  );

                  await onSave(updatedSale, oldInv);
                  if (ctx.mounted) Navigator.pop(ctx, true);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  /// Shows modal to confirm and execute invoice deletion
  static Future<bool?> showDeleteDialog({
    required BuildContext context,
    required SaleModel sale,
    required Future<void> Function(SaleModel sale) onDelete,
  }) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false).settings;
    final currency = settings.currencySymbol;

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Delete Invoice'),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  children: [
                    const TextSpan(text: 'Are you sure you want to permanently delete Invoice '),
                    TextSpan(
                      text: '#${sale.invoiceNumber}',
                      style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary),
                    ),
                    const TextSpan(text: '?'),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Invoice Details Summary Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Amount:', style: TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          '$currency ${sale.grandTotal.toStringAsFixed(2)}',
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Date & Time:'),
                        Text(sale.dateTime.replaceFirst('T', ' ').substring(0, 16), style: TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Table / Destination:'),
                        Text(sale.tableName ?? 'Takeaway', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Purchased Items:'),
                        Text('${sale.items.length} items', style: TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Stock restoration banner
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.inventory_2_outlined, color: AppColors.accent, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Inventory Auto-Restoration: Any raw ingredient stock deducted for this order will be automatically refunded back into stock.',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF065F46), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'This action cannot be undone and will update all revenue reports.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.delete_forever_rounded, size: 18),
            label: const Text('Delete Invoice'),
            onPressed: () async {
              if (sale.id != null) {
                await onDelete(sale);
              }
              if (ctx.mounted) Navigator.pop(ctx, true);
            },
          ),
        ],
      ),
    );
  }

  /// Shows modal to quickly clear an outstanding/remaining bill and select payment method
  static Future<bool?> showClearBillDialog({
    required BuildContext context,
    required SaleModel sale,
    required Future<void> Function(String paymentMethod) onClear,
  }) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false).settings;
    final currency = settings.currencySymbol;
    String selectedPaymentMethod = sale.paymentMethod.isNotEmpty ? sale.paymentMethod : 'Cash';
    bool isProcessing = false;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Clear Outstanding Bill', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(
                      'Invoice #${sale.invoiceNumber} • ${sale.tableName ?? 'Takeaway'}',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                // Remaining Amount Hero Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AMOUNT TO CLEAR',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accent, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$currency ${sale.grandTotal.toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.primary),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.hourglass_top_rounded, size: 14, color: Colors.orange.shade900),
                            const SizedBox(width: 4),
                            Text(
                              'Remaining',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Order Meta Details
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Destination / Table:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          Text(sale.tableName ?? 'Takeaway / Counter', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      if (sale.waiterName != null && sale.waiterName!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Waiter:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            Text(sale.waiterName!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                      if (sale.customerName != null && sale.customerName!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Customer:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            Text(sale.customerName!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Payment Method Selector
                Text('CONFIRM PAYMENT METHOD RECEIVED:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                const SizedBox(height: 8),
                Row(
                  children: ['Cash', 'Card', 'Online/UPI'].map((method) {
                    final isSelected = selectedPaymentMethod == method;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: InkWell(
                          onTap: () => setModalState(() => selectedPaymentMethod = method),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              method,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // Note explaining immediate total sales update
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 18, color: AppColors.info),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Clearing this bill will update Total Sales immediately, credit waiter statistics, and free the table.',
                          style: TextStyle(fontSize: 11, color: Colors.blue.shade900, fontWeight: FontWeight.w500),
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
              onPressed: isProcessing ? null : () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: isProcessing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded, size: 18),
              label: Text(
                isProcessing ? 'Clearing...' : 'Clear Bill & Update Sales',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: isProcessing
                  ? null
                  : () async {
                      setModalState(() => isProcessing = true);
                      await onClear(selectedPaymentMethod);
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    },
            ),
          ],
        ),
      ),
    );
  }

  /// Shows detailed invoice receipt modal with items breakdown and print actions
  static Future<void> showInvoiceDetailsDialog({
    required BuildContext context,
    required SaleModel sale,
    required String currencySymbol,
  }) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false).settings;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '#${sale.invoiceNumber}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Text('Invoice Details', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      Text(
                        settings.cafeName.trim().isNotEmpty ? settings.cafeName : 'Cafe Flow',
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

                if (sale.isRemaining)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.hourglass_top_rounded, size: 16, color: Colors.orange.shade900),
                            const SizedBox(width: 6),
                            Text(
                              'STATUS: REMAINING (Delayed Payment)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.orange.shade900),
                            ),
                          ],
                        ),
                        Text(
                          'Due: $currencySymbol ${sale.grandTotal.toStringAsFixed(2)}',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.orange.shade900),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_rounded, size: 16, color: AppColors.accent),
                        const SizedBox(width: 6),
                        Text(
                          'STATUS: CLEARED (Paid in Full via ${sale.paymentMethod})',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.accent),
                        ),
                      ],
                    ),
                  ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Date: ${sale.dateTime.replaceFirst('T', ' ').substring(0, 16)}'),
                    Text('Table: ${sale.tableName ?? 'Takeaway'}'),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Cashier: ${sale.cashierName}'),
                    Text('Waiter: ${sale.waiterName ?? 'N/A'}'),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),

                const Text('ITEMS PURCHASED:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 8),

                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sale.items.length,
                  separatorBuilder: (_, _) => const Divider(height: 8),
                  itemBuilder: (context, index) {
                    final item = sale.items[index];
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${item.productName} (x${item.quantity})', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('$currencySymbol ${item.totalPrice.toStringAsFixed(2)}'),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal:'),
                    Text('$currencySymbol ${sale.subtotal.toStringAsFixed(2)}'),
                  ],
                ),
                if (sale.discount > 0)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Discount:'),
                      Text('- $currencySymbol ${sale.discount.toStringAsFixed(2)}'),
                    ],
                  ),
                if (sale.tax > 0)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tax:'),
                      Text('+ $currencySymbol ${sale.tax.toStringAsFixed(2)}'),
                    ],
                  ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('GRAND TOTAL:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('$currencySymbol ${sale.grandTotal.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ElevatedButton.icon(
            icon: const Icon(Icons.print_rounded, size: 18),
            label: const Text('Print Receipt'),
            onPressed: () async {
              await InvoiceService.printInvoice(sale: sale, settings: settings);
            },
          ),
        ],
      ),
    );
  }
}