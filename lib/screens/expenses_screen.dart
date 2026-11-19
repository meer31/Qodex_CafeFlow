import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/constants/app_constants.dart';
import '../models/expense_model.dart';
import '../providers/expense_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/sale_session_provider.dart';

class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final expenseProvider = Provider.of<ExpenseProvider>(context);
    final settings = Provider.of<SettingsProvider>(context).settings;
    final currency = settings.currencySymbol;

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
                      'Expense Tracking',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Record operational expenses, bills, and supplies',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded),
                          tooltip: 'Refresh Expenses',
                          onPressed: () => expenseProvider.loadExpenses(),
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Record Expense', style: TextStyle(fontSize: 12)),
                          onPressed: () => _showAddExpenseModal(context),
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
                          'Expense Tracking',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Record operational expenses, electricity bills, salaries, and stock purchases',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded),
                          tooltip: 'Refresh Expenses',
                          onPressed: () => expenseProvider.loadExpenses(),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Record New Expense'),
                          onPressed: () => _showAddExpenseModal(context),
                        ),
                      ],
                    ),
                  ],
                ),
              const SizedBox(height: 16),

          // Today's Expense KPI Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.account_balance_wallet_rounded, color: AppColors.error, size: 28),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TODAY\'S TOTAL EXPENSES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                    Text(
                      '$currency ${expenseProvider.todayExpenseTotal.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.error),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Expanded(
            child: expenseProvider.isLoading
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
                            DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Expense Title', style: TextStyle(fontWeight: FontWeight.bold))))),
                            DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))))),
                            DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold))))),
                            DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Date & Time', style: TextStyle(fontWeight: FontWeight.bold))))),
                            DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Notes', style: TextStyle(fontWeight: FontWeight.bold))))),
                            DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))))),
                          ],
                          rows: expenseProvider.expenses.map((exp) {
                            return DataRow(cells: [
                              DataCell(Text('#${exp.id}')),
                              DataCell(Text(exp.title, style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(exp.category, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                              )),
                              DataCell(Text('$currency ${exp.amount.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error))),
                              DataCell(Text(exp.dateTime.replaceFirst('T', ' ').substring(0, 16))),
                              DataCell(Text(exp.notes ?? '-')),
                              DataCell(IconButton(
                                icon: Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                                onPressed: () => _confirmDelete(context, exp.id!),
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

  void _showAddExpenseModal(BuildContext context) {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    String category = AppConstants.expenseCategories.first;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record New Expense'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Expense Title (e.g. Electricity Bill)'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: AppConstants.expenseCategories.map((c) => DropdownMenuItem<String>(
                  value: c,
                  child: Text(c),
                )).toList(),
                onChanged: (val) {
                  if (val != null) category = val;
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount (Rs.)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Notes / Voucher Details'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.trim().isEmpty) return;
              final double amt = double.tryParse(amountController.text) ?? 0.0;
              if (amt <= 0) return;

              await Provider.of<ExpenseProvider>(context, listen: false).addExpense(
                ExpenseModel(
                  title: titleController.text.trim(),
                  category: category,
                  amount: amt,
                  dateTime: DateTime.now().toIso8601String(),
                  notes: notesController.text.trim(),
                ),
              );
              if (context.mounted) {
                await Provider.of<SaleSessionProvider>(context, listen: false).refreshActiveSessionFinancials();
                if (context.mounted) {
                  Provider.of<DashboardProvider>(context, listen: false).loadDashboardData();
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save Expense'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: const Text('Are you sure you want to delete this expense entry?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              await Provider.of<ExpenseProvider>(context, listen: false).deleteExpense(id);
              if (context.mounted) {
                await Provider.of<SaleSessionProvider>(context, listen: false).refreshActiveSessionFinancials();
                if (context.mounted) {
                  Provider.of<DashboardProvider>(context, listen: false).loadDashboardData();
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}