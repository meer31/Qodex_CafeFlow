import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../models/cafe_table_model.dart';
import '../models/sale_model.dart';
import '../models/waiter_model.dart';
import '../providers/table_provider.dart';
import '../providers/pos_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/stock_provider.dart';
import '../providers/sale_session_provider.dart';
import '../providers/waiter_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/invoice_dialogs.dart';
import '../widgets/swap_table_dialog.dart';

class TablesManagementScreen extends StatefulWidget {
  final Function(int)? onNavigate;

  const TablesManagementScreen({super.key, this.onNavigate});

  @override
  State<TablesManagementScreen> createState() => _TablesManagementScreenState();
}

class _TablesManagementScreenState extends State<TablesManagementScreen> {
  int? _selectedSectionId; // null = All Sections

  @override
  Widget build(BuildContext context) {
    final tableProvider = Provider.of<TableProvider>(context);

    final filteredTables = tableProvider.tables.where((t) {
      return _selectedSectionId == null || t.sectionId == _selectedSectionId;
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 750;
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
                      'Tables & Sections',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Floor plan and table occupancy tracking',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded),
                          tooltip: 'Refresh Tables & Floor Plan',
                          onPressed: () => tableProvider.loadTableData(),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.domain_add_rounded, size: 16),
                          label: const Text('Add Section', style: TextStyle(fontSize: 12)),
                          onPressed: () => _showAddSectionModal(context, tableProvider),
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.table_bar_rounded, size: 16),
                          label: const Text('Add Table', style: TextStyle(fontSize: 12)),
                          onPressed: () => _showAddTableModal(context, tableProvider),
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
                          'Tables & Sections Management',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Real-time dining room floor plan and table occupancy tracking',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded),
                          tooltip: 'Refresh Tables & Floor Plan',
                          onPressed: () => tableProvider.loadTableData(),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.domain_add_rounded),
                          label: const Text('Add Section'),
                          onPressed: () => _showAddSectionModal(context, tableProvider),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.table_bar_rounded),
                          label: const Text('Add Table'),
                          onPressed: () => _showAddTableModal(context, tableProvider),
                        ),
                      ],
                    ),
                  ],
                ),
              const SizedBox(height: 16),

              // Section Chips Filter
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: _selectedSectionId == null,
                        label: const Text('All Sections'),
                        onSelected: (_) => setState(() => _selectedSectionId = null),
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: _selectedSectionId == null ? Colors.white : AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    ...tableProvider.sections.map((sec) {
                      final isSelected = _selectedSectionId == sec.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          selected: isSelected,
                          label: Text(sec.name),
                          onSelected: (_) => setState(() => _selectedSectionId = sec.id),
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Responsive Legend Indicators
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _buildLegend('Available', AppColors.statusAvailable),
                  _buildLegend('Occupied', AppColors.statusOccupied),
                  _buildLegend('Reserved', AppColors.statusReserved),
                  _buildLegend('Cleaning', AppColors.statusCleaning),
                ],
              ),
              const SizedBox(height: 16),

              // Tables Visual Grid
              Expanded(
                child: tableProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 240,
                          mainAxisExtent: 260,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: filteredTables.length,
                        itemBuilder: (context, index) {
                          final table = filteredTables[index];
                          return _buildTableCard(context, table, tableProvider);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegend(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildTableCard(BuildContext context, CafeTableModel table, TableProvider provider) {
    final settings = Provider.of<SettingsProvider>(context, listen: false).settings;
    final currency = settings.currencySymbol;

    Color statusColor;
    switch (table.status) {
      case 'Occupied':
        statusColor = AppColors.statusOccupied;
        break;
      case 'Reserved':
        statusColor = AppColors.statusReserved;
        break;
      case 'Cleaning':
        statusColor = AppColors.statusCleaning;
        break;
      default:
        statusColor = AppColors.statusAvailable;
    }

    final remainingSales = provider.getRemainingSalesForTable(table.id ?? 0, tableName: table.tableName);
    final primarySale = provider.getPrimaryRemainingSaleForTable(
      table.id ?? 0,
      tableName: table.tableName,
      activeInvoiceNum: table.activeInvoiceNumber,
    );
    final bool isOccupied = table.status == 'Occupied';
    final bool hasRemaining = isOccupied && remainingSales.isNotEmpty;

    return InkWell(
      onTap: () {
        if (isOccupied && remainingSales.isNotEmpty) {
          _showOccupiedTableDetailsModal(context, table, remainingSales, provider);
        } else {
          _showStatusChangeModal(context, table, provider);
        }
      },
      borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
          border: Border.all(
            color: hasRemaining ? AppColors.error : statusColor,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: (hasRemaining ? AppColors.error : statusColor).withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Section & Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    table.sectionName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    table.status.toUpperCase(),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Table Icon & Table Name
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.table_restaurant_rounded, size: 20, color: statusColor),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    table.tableName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Middle Section: If Occupied with Remaining/Pending order vs regular status
            if (hasRemaining && primarySale != null) ...[
              // Order information badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '#${primarySale.invoiceNumber}',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.error),
                        ),
                        Text(
                          '$currency ${primarySale.grandTotal.toStringAsFixed(0)}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.error),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${primarySale.items.length} item${primarySale.items.length == 1 ? '' : 's'}',
                          style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                        ),
                        if (remainingSales.length > 1)
                          Text(
                            '+${remainingSales.length - 1} more',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              primarySale.status.toUpperCase(),
                              style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.error),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              // Clear Bill Quick Action
              SizedBox(
                width: double.infinity,
                height: 28,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_rounded, size: 14),
                  label: const Text('Clear Bill', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: () => _handleClearBill(primarySale, table, provider),
                ),
              ),
            ] else if (isOccupied) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Table Occupied',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                    ),
                    Text(
                      table.activeInvoiceNumber != null ? 'Inv #${table.activeInvoiceNumber}' : 'No active order recorded',
                      style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                height: 28,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.check_rounded, size: 14),
                  label: const Text('Free Table', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.statusAvailable,
                    side: BorderSide(color: AppColors.statusAvailable),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: () async {
                    await provider.updateTableStatus(table.id!, 'Available');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Table ${table.tableName} is now Available.'), backgroundColor: AppColors.accent),
                      );
                    }
                  },
                ),
              ),
            ] else ...[
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        table.status == 'Available'
                            ? Icons.check_circle_outline_rounded
                            : (table.status == 'Reserved' ? Icons.bookmark_border_rounded : Icons.cleaning_services_outlined),
                        size: 24,
                        color: statusColor.withValues(alpha: 0.7),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        table.status == 'Available' ? 'Ready for guests' : table.status,
                        style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const Spacer(),

            // Bottom row: Seats & Table options/delete
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.people_outline_rounded, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text('${table.capacity} Seats', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Tooltip(
                      message: 'Table Options',
                      child: InkWell(
                        onTap: () => _showStatusChangeModal(context, table, provider),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(Icons.settings_outlined, size: 15, color: AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Tooltip(
                      message: 'Delete Table',
                      child: InkWell(
                        onTap: () => _showDeleteTableConfirmation(context, table, provider),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(Icons.delete_outline_rounded, size: 15, color: AppColors.error),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showOccupiedTableDetailsModal(
    BuildContext context,
    CafeTableModel table,
    List<SaleModel> remainingSales,
    TableProvider provider,
  ) {
    final settings = Provider.of<SettingsProvider>(context, listen: false).settings;
    final currency = settings.currencySymbol;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.statusOccupied.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.table_restaurant_rounded, color: AppColors.statusOccupied, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          table.tableName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.statusOccupied.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'OCCUPIED',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.statusOccupied),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${table.sectionName} • ${table.capacity} Seats • ${remainingSales.length} Pending Order${remainingSales.length == 1 ? '' : 's'}',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                if (remainingSales.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Center(
                      child: Text(
                        'No pending orders recorded for this table.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  )
                else
                  ...remainingSales.map((sale) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Order header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.receipt_long_rounded, size: 18, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Invoice #${sale.invoiceNumber}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  sale.status.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                sale.dateTime.replaceFirst('T', ' ').substring(0, 16),
                                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                              ),
                              if (sale.waiterName != null && sale.waiterName!.isNotEmpty)
                                Text(
                                  'Waiter: ${sale.waiterName}',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                                ),
                            ],
                          ),
                          const Divider(height: 16),

                          // Order Items List
                          Text(
                            'ORDER ITEMS:',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 6),
                          ...sale.items.map((item) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${item.quantity}x',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      item.productName,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  Text(
                                    '$currency ${(item.unitPrice * item.quantity).toStringAsFixed(0)}',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            );
                          }),

                          const Divider(height: 16),

                          // Order Totals Summary
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Subtotal:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              Text('$currency ${sale.subtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                          if (sale.discount > 0) ...[
                            const SizedBox(height: 2),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Discount:', style: TextStyle(fontSize: 12, color: AppColors.error)),
                                Text('- $currency ${sale.discount.toStringAsFixed(2)}', style: TextStyle(fontSize: 12, color: AppColors.error)),
                              ],
                            ),
                          ],
                          if (sale.tax > 0) ...[
                            const SizedBox(height: 2),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Tax:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                Text('+ $currency ${sale.tax.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                          ],
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Remaining Due:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                              Text(
                                '$currency ${sale.grandTotal.toStringAsFixed(2)}',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.error),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Action Buttons: Pay & Clear Bill, Open in POS
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.accent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                                  label: const Text(
                                    'Pay & Clear Bill (Make Available)',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _handleClearBill(sale, table, provider);
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.edit_note_rounded, size: 18),
                                  label: const Text('Edit in POS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _handleEditOrderInPos(sale, table);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
        actions: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.35)),
            ),
            icon: const Icon(Icons.swap_horiz_rounded, size: 16),
            label: const Text('Swap Table Order'),
            onPressed: () {
              Navigator.pop(ctx);
              final posProv = Provider.of<PosProvider>(context, listen: false);
              SwapTableDialog.show(
                context,
                posProvider: posProv,
                tableProvider: provider,
                initialSourceTable: table,
              );
            },
          ),
          TextButton.icon(
            icon: const Icon(Icons.settings_outlined, size: 16),
            label: const Text('Table Options'),
            onPressed: () {
              Navigator.pop(ctx);
              _showStatusChangeModal(context, table, provider);
            },
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showStatusChangeModal(BuildContext context, CafeTableModel table, TableProvider provider) {
    final remainingSales = provider.getRemainingSalesForTable(table.id ?? 0, tableName: table.tableName);
    final primarySale = provider.getPrimaryRemainingSaleForTable(
      table.id ?? 0,
      tableName: table.tableName,
      activeInvoiceNum: table.activeInvoiceNumber,
    );
    final settings = Provider.of<SettingsProvider>(context, listen: false).settings;
    final currency = settings.currencySymbol;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Table: ${table.tableName} (${table.sectionName})'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (remainingSales.isNotEmpty && primarySale != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: AppColors.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Active Order: Inv #${primarySale.invoiceNumber} ($currency ${primarySale.grandTotal.toStringAsFixed(0)}). Clearing this bill will automatically make this table Available.',
                        style: TextStyle(fontSize: 11.5, color: AppColors.error, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 38),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.check_circle_rounded, size: 16),
                label: const Text('Clear Outstanding Bill Now', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.pop(ctx);
                  _handleClearBill(primarySale, table, provider);
                },
              ),
              const SizedBox(height: 10),
              const Divider(),
            ],
            const Text('Change Table Status Manually:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ListTile(
              leading: Icon(Icons.check_circle, color: AppColors.statusAvailable),
              title: const Text('Available'),
              onTap: () async {
                await provider.updateTableStatus(table.id!, 'Available');
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: Icon(Icons.restaurant, color: AppColors.statusOccupied),
              title: const Text('Occupied'),
              onTap: () async {
                await provider.updateTableStatus(table.id!, 'Occupied');
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: Icon(Icons.bookmark, color: AppColors.statusReserved),
              title: const Text('Reserved'),
              onTap: () async {
                await provider.updateTableStatus(table.id!, 'Reserved');
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: Icon(Icons.cleaning_services, color: AppColors.statusCleaning),
              title: const Text('Cleaning'),
              onTap: () async {
                await provider.updateTableStatus(table.id!, 'Cleaning');
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.edit_rounded, color: AppColors.primary),
              title: const Text('Edit Table Details'),
              onTap: () {
                Navigator.pop(ctx);
                _showEditTableModal(context, table, provider);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: AppColors.error),
              title: Text('Delete Table', style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(ctx);
                _showDeleteTableConfirmation(context, table, provider);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleClearBill(
    SaleModel sale,
    CafeTableModel table,
    TableProvider provider,
  ) async {
    await InvoiceDialogs.showClearBillDialog(
      context: context,
      sale: sale,
      onClear: (paymentMethod) async {
        final dashboardProvider = Provider.of<DashboardProvider>(context, listen: false);
        await dashboardProvider.clearBill(sale.id!, paymentMethod: paymentMethod);
        if (!mounted) return;
        Provider.of<SaleSessionProvider>(context, listen: false).loadSessions();
        Provider.of<StockProvider>(context, listen: false).loadStockData();
        await provider.loadTableData();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Table ${table.tableName} bill cleared! Table is now Available.'),
            backgroundColor: AppColors.accent,
          ),
        );
      },
    );
  }

  void _handleEditOrderInPos(SaleModel sale, CafeTableModel table) {
    final waiterProvider = Provider.of<WaiterProvider>(context, listen: false);
    final posProvider = Provider.of<PosProvider>(context, listen: false);

    WaiterModel? matchedWaiter;
    if (sale.waiterId != null) {
      try {
        matchedWaiter = waiterProvider.waiters.firstWhere((w) => w.id == sale.waiterId);
      } catch (_) {}
    }

    posProvider.loadInvoiceForEditing(sale, table: table, waiter: matchedWaiter);

    if (widget.onNavigate != null) {
      widget.onNavigate!(1);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Loaded Table ${table.tableName} (Invoice #${sale.invoiceNumber}) into POS for editing.'),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showEditTableModal(BuildContext context, CafeTableModel table, TableProvider provider) {
    if (provider.sections.isEmpty) return;
    final nameController = TextEditingController(text: table.tableName);
    final capacityController = TextEditingController(text: table.capacity.toString());
    int selectedSecId = table.sectionId;
    String selectedStatus = table.status;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.edit_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Edit Table'),
            ],
          ),
          content: Form(
            key: formKey,
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: provider.sections.any((s) => s.id == selectedSecId)
                        ? selectedSecId
                        : provider.sections.first.id,
                    decoration: const InputDecoration(
                      labelText: 'Section',
                      prefixIcon: Icon(Icons.domain_rounded),
                    ),
                    items: provider.sections.map((s) => DropdownMenuItem<int>(
                      value: s.id,
                      child: Text(s.name),
                    )).toList(),
                    onChanged: (id) {
                      if (id != null) {
                        setDialogState(() => selectedSecId = id);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Table Name / Number (e.g. Table 05)',
                      prefixIcon: Icon(Icons.table_bar_rounded),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter a table name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: capacityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Seating Capacity',
                      prefixIcon: Icon(Icons.people_outline_rounded),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter capacity';
                      }
                      final parsed = int.tryParse(val.trim());
                      if (parsed == null || parsed <= 0) {
                        return 'Please enter a valid number (> 0)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      prefixIcon: Icon(Icons.info_outline_rounded),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Available', child: Text('Available')),
                      DropdownMenuItem(value: 'Occupied', child: Text('Occupied')),
                      DropdownMenuItem(value: 'Reserved', child: Text('Reserved')),
                      DropdownMenuItem(value: 'Cleaning', child: Text('Cleaning')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedStatus = val);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Save Changes'),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final sec = provider.sections.firstWhere(
                  (s) => s.id == selectedSecId,
                  orElse: () => provider.sections.first,
                );
                final updatedTable = table.copyWith(
                  sectionId: selectedSecId,
                  sectionName: sec.name,
                  tableName: nameController.text.trim(),
                  capacity: int.parse(capacityController.text.trim()),
                  status: selectedStatus,
                );
                await provider.updateTable(updatedTable);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Table "${updatedTable.tableName}" updated successfully!'),
                      backgroundColor: AppColors.accent,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteTableConfirmation(BuildContext context, CafeTableModel table, TableProvider provider) {
    final bool isOccupied = table.status == 'Occupied';

    showDialog(
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
            const Text('Delete Table'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  children: [
                    const TextSpan(text: 'Are you sure you want to delete '),
                    TextSpan(
                      text: table.tableName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: ' from section "${table.sectionName}"?'),
                  ],
                ),
              ),
              if (isOccupied) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Warning: This table is currently OCCUPIED${table.activeInvoiceNumber != null ? ' (Invoice: ${table.activeInvoiceNumber})' : ''}! Ensure active orders are completed or moved before deletion.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFB45309),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Text(
                'This action will permanently remove this table from the floor plan.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.delete_forever_rounded, size: 18),
            label: const Text('Delete Table'),
            onPressed: () async {
              if (table.id != null) {
                await provider.deleteTable(table.id!);
              }
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Table "${table.tableName}" has been deleted.'),
                    backgroundColor: AppColors.textPrimary,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showAddSectionModal(BuildContext context, TableProvider provider) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Section'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Section Name (e.g. Terrace, VIP Lounge)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              await provider.addSection(nameController.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Add Section'),
          ),
        ],
      ),
    );
  }

  void _showAddTableModal(BuildContext context, TableProvider provider) {
    if (provider.sections.isEmpty) {
      _showAddSectionModal(context, provider);
      return;
    }

    TableSectionModel currentSection;
    if (_selectedSectionId != null && provider.sections.any((s) => s.id == _selectedSectionId)) {
      currentSection = provider.sections.firstWhere((s) => s.id == _selectedSectionId);
    } else {
      currentSection = provider.sections.first;
    }

    final numberController = TextEditingController();
    final capacityController = TextEditingController(text: '4');
    String? errorText;
    int selectedSecId = currentSection.id!;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final activeSec = provider.sections.firstWhere(
              (s) => s.id == selectedSecId,
              orElse: () => currentSection,
            );
            final enteredNumber = numberController.text.trim();
            final previewName = enteredNumber.isNotEmpty ? 'Table $enteredNumber' : 'Table ...';
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: Row(
                children: [
                  Icon(Icons.table_restaurant_rounded, color: AppColors.primary, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Add Table to ${activeSec.name}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section Selector
                    Text('Section:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                        color: AppColors.cardBg,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: selectedSecId,
                          items: provider.sections.map((s) {
                            return DropdownMenuItem<int>(
                              value: s.id,
                              child: Text(s.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                selectedSecId = val;
                                final newSec = provider.sections.firstWhere((s) => s.id == val, orElse: () => activeSec);
                                final trimmed = numberController.text.trim();
                                if (trimmed.isNotEmpty) {
                                  final prospectiveName = 'Table $trimmed';
                                  final isDup = provider.tables.any(
                                    (t) => t.sectionId == val && t.tableName.trim().toLowerCase() == prospectiveName.toLowerCase(),
                                  );
                                  errorText = isDup ? '$prospectiveName already exists in ${newSec.name}!' : null;
                                } else {
                                  errorText = null;
                                }
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Table Number input
                    Text('Table Number (just enter number):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: numberController,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        prefixIcon: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          child: Text(
                            'Table ',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                        hintText: '1',
                        errorText: errorText,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (val) {
                        setDialogState(() {
                          final trimmed = val.trim();
                          if (trimmed.isNotEmpty) {
                            final prospectiveName = 'Table $trimmed';
                            final isDup = provider.tables.any(
                              (t) => t.sectionId == selectedSecId && t.tableName.trim().toLowerCase() == prospectiveName.toLowerCase(),
                            );
                            if (isDup) {
                              errorText = '$prospectiveName already exists in ${activeSec.name}!';
                            } else {
                              errorText = null;
                            }
                          } else {
                            errorText = null;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 8),

                    // Live preview / error banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: errorText == null
                            ? (isDark ? const Color(0xFF063321) : const Color(0xFFECFDF5))
                            : (isDark ? const Color(0xFF381216) : const Color(0xFFFEF2F2)),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: errorText == null
                              ? (isDark ? const Color(0xFF10B981) : const Color(0xFFA7F3D0))
                              : (isDark ? const Color(0xFFEF4444) : const Color(0xFFFECACA)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            errorText == null ? Icons.info_outline_rounded : Icons.error_outline_rounded,
                            size: 14,
                            color: errorText == null ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              errorText == null
                                  ? 'Table will be named "$previewName" in ${activeSec.name}'
                                  : errorText!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: errorText == null
                                    ? (isDark ? const Color(0xFFA7F3D0) : const Color(0xFF047857))
                                    : (isDark ? const Color(0xFFFECACA) : const Color(0xFFB91C1C)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Capacity (Seats)
                    Text('Capacity (Seats):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: capacityController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '4',
                        prefixIcon: const Icon(Icons.people_outline_rounded, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    final trimmed = numberController.text.trim();
                    if (trimmed.isEmpty) {
                      setDialogState(() => errorText = 'Please enter a table number');
                      return;
                    }
                    final numVal = int.tryParse(trimmed);
                    if (numVal == null || numVal <= 0) {
                      setDialogState(() => errorText = 'Please enter a valid positive number');
                      return;
                    }
                    final tableName = 'Table $numVal';
                    final isDup = provider.tables.any(
                      (t) => t.sectionId == activeSec.id && t.tableName.trim().toLowerCase() == tableName.toLowerCase(),
                    );
                    if (isDup) {
                      setDialogState(() => errorText = '$tableName already exists in ${activeSec.name}!');
                      return;
                    }

                    final capacity = int.tryParse(capacityController.text.trim()) ?? 4;
                    Navigator.of(dialogCtx).pop();

                    await provider.addTable(
                      CafeTableModel(
                        sectionId: activeSec.id!,
                        sectionName: activeSec.name,
                        tableName: tableName,
                        capacity: capacity,
                        status: 'Available',
                      ),
                    );

                    setState(() {
                      _selectedSectionId = activeSec.id;
                    });

                    if (!mounted) return;
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text('$tableName added successfully to ${activeSec.name}!'),
                        backgroundColor: const Color(0xFF10B981),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Text('Add Table'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}