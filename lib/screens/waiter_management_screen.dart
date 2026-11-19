import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../models/waiter_model.dart';
import '../providers/waiter_provider.dart';
import '../providers/settings_provider.dart';

class WaiterManagementScreen extends StatelessWidget {
  const WaiterManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final waiterProvider = Provider.of<WaiterProvider>(context);
    final settings = Provider.of<SettingsProvider>(context).settings;

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
                      'Waiter Staff',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Track waiter sales performance and activity',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded),
                          tooltip: 'Refresh Waiters & Stats',
                          onPressed: () => waiterProvider.loadWaiters(),
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.person_add_rounded, size: 16),
                          label: const Text('Add Waiter', style: TextStyle(fontSize: 12)),
                          onPressed: () => _showAddEditWaiterModal(context),
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
                          'Waiter Staff Management',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Track waiter sales performance, assigned orders, and activity',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded),
                          tooltip: 'Refresh Waiters & Stats',
                          onPressed: () => waiterProvider.loadWaiters(),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.person_add_rounded),
                          label: const Text('Add New Waiter'),
                          onPressed: () => _showAddEditWaiterModal(context),
                        ),
                      ],
                    ),
                  ],
                ),
              const SizedBox(height: 16),

          Expanded(
            child: waiterProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 20,
                          headingRowHeight: 48,
                          columns: const [
                            DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('ID', style: TextStyle(fontWeight: FontWeight.bold))))),
                            DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Waiter Name', style: TextStyle(fontWeight: FontWeight.bold))))),
                            DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Phone Number', style: TextStyle(fontWeight: FontWeight.bold))))),
                            DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Total Orders Served', style: TextStyle(fontWeight: FontWeight.bold))))),
                            DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Total Sales Generated', style: TextStyle(fontWeight: FontWeight.bold))))),
                            DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))))),
                            DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))))),
                          ],
                          rows: waiterProvider.waiters.map((w) {
                            return DataRow(cells: [
                              DataCell(Text('#${w.id}')),
                              DataCell(Text(w.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Text(w.phone)),
                              DataCell(Text('${w.ordersCount} orders')),
                              DataCell(Text(
                                '${settings.currencySymbol} ${w.totalSales.toStringAsFixed(0)}',
                                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                              )),
                              DataCell(Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: w.status == 'Active' ? AppColors.accent.withOpacity(0.15) : AppColors.error.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  w.status,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: w.status == 'Active' ? AppColors.accent : AppColors.error,
                                  ),
                                ),
                              )),
                              DataCell(Row(
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
                                    onPressed: () => _showAddEditWaiterModal(context, waiter: w),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                                    onPressed: () => _confirmDelete(context, w.id!),
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

  void _showAddEditWaiterModal(BuildContext context, {WaiterModel? waiter}) {
    final nameController = TextEditingController(text: waiter?.name ?? '');
    final phoneController = TextEditingController(text: waiter?.phone ?? '');
    String status = waiter?.status ?? 'Active';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(waiter == null ? 'Add Waiter' : 'Edit Waiter'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Waiter Full Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: ['Active', 'Inactive'].map((s) => DropdownMenuItem<String>(
                  value: s,
                  child: Text(s),
                )).toList(),
                onChanged: (val) {
                  if (val != null) status = val;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              final waiterProv = Provider.of<WaiterProvider>(context, listen: false);

              if (waiter == null) {
                await waiterProv.addWaiter(WaiterModel(
                  name: nameController.text.trim(),
                  phone: phoneController.text.trim(),
                  status: status,
                ));
              } else {
                await waiterProv.updateWaiter(WaiterModel(
                  id: waiter.id,
                  name: nameController.text.trim(),
                  phone: phoneController.text.trim(),
                  status: status,
                  totalSales: waiter.totalSales,
                  ordersCount: waiter.ordersCount,
                ));
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save Waiter'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Waiter?'),
        content: const Text('Are you sure you want to delete this waiter record?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              await Provider.of<WaiterProvider>(context, listen: false).deleteWaiter(id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}