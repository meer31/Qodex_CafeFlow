import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../models/category_model.dart';
import '../providers/category_provider.dart';

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoryProvider = Provider.of<CategoryProvider>(context);
    final searchQuery = _searchController.text.trim().toLowerCase();

    final filteredCategories = categoryProvider.categories.where((cat) {
      final matchesName = cat.name.toLowerCase().contains(searchQuery);
      final matchesDesc = (cat.description ?? '').toLowerCase().contains(searchQuery);
      return matchesName || matchesDesc;
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
                      'Category Management',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Organize menu items into structured categories',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded),
                          tooltip: 'Refresh Categories',
                          onPressed: () => categoryProvider.loadCategories(),
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Add Category', style: TextStyle(fontSize: 12)),
                          onPressed: () => _showAddEditDialog(context),
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
                          'Category Management',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Organize menu items into structured categories',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded),
                          tooltip: 'Refresh Categories',
                          onPressed: () => categoryProvider.loadCategories(),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add Category'),
                          onPressed: () => _showAddEditDialog(context),
                        ),
                      ],
                    ),
                  ],
                ),
              const SizedBox(height: 16),

              // Search Bar
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 350),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search categories by name or description...',
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
            child: categoryProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: filteredCategories.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off_rounded, size: 48, color: AppColors.textMuted),
                                const SizedBox(height: 12),
                                Text(
                                  _searchController.text.isNotEmpty
                                      ? 'No categories match "${_searchController.text}"'
                                      : 'No categories found',
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
                                columnSpacing: 24,
                                headingRowHeight: 48,
                                columns: const [
                                  DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('ID', style: TextStyle(fontWeight: FontWeight.bold))))),
                                  DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Category Name', style: TextStyle(fontWeight: FontWeight.bold))))),
                                  DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Description', style: TextStyle(fontWeight: FontWeight.bold))))),
                                  DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Sort Order', style: TextStyle(fontWeight: FontWeight.bold))))),
                                  DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))))),
                                ],
                                rows: filteredCategories.map((cat) {
                                  return DataRow(cells: [
                                    DataCell(Text('#${cat.id}')),
                                    DataCell(Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                                    DataCell(Text(cat.description ?? '-')),
                                    DataCell(Text('${cat.sortOrder}')),
                                    DataCell(Row(
                                      children: [
                                        IconButton(
                                          icon: Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
                                          onPressed: () => _showAddEditDialog(context, category: cat),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                                          onPressed: () => _confirmDelete(context, cat.id!),
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

  void _showAddEditDialog(BuildContext context, {CategoryModel? category}) {
    final nameController = TextEditingController(text: category?.name ?? '');
    final descController = TextEditingController(text: category?.description ?? '');
    final orderController = TextEditingController(text: (category?.sortOrder ?? 1).toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(category == null ? 'Add Category' : 'Edit Category'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Category Name (e.g. Tea, Fast Food)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: orderController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Sort Order Index'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              final catProv = Provider.of<CategoryProvider>(context, listen: false);

              if (category == null) {
                await catProv.addCategory(CategoryModel(
                  name: nameController.text.trim(),
                  description: descController.text.trim(),
                  sortOrder: int.tryParse(orderController.text) ?? 1,
                ));
              } else {
                await catProv.updateCategory(CategoryModel(
                  id: category.id,
                  name: nameController.text.trim(),
                  description: descController.text.trim(),
                  sortOrder: int.tryParse(orderController.text) ?? category.sortOrder,
                ));
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, int categoryId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category?'),
        content: const Text('Are you sure you want to delete this category?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              await Provider.of<CategoryProvider>(context, listen: false).deleteCategory(categoryId);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}