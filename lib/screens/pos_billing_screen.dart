import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../models/product_model.dart';
import '../providers/pos_provider.dart';
import '../providers/product_provider.dart';
import '../providers/category_provider.dart';
import '../providers/table_provider.dart';
import '../providers/stock_provider.dart';
import '../providers/waiter_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../models/app_settings_model.dart';
import '../models/sale_model.dart';
import '../services/invoice_service.dart';
import '../providers/sale_session_provider.dart';
import '../widgets/sale_session_dialogs.dart';
import '../widgets/daily_sale_detail_dialog.dart';
import '../widgets/pos_table_selection_dialog.dart';
import '../widgets/pos_waiter_selection_dialog.dart';
import '../widgets/out_of_stock_dialog.dart';
import '../services/stock_deduction_service.dart';

class PosBillingScreen extends StatefulWidget {
  const PosBillingScreen({super.key});

  @override
  State<PosBillingScreen> createState() => _PosBillingScreenState();
}

class _PosBillingScreenState extends State<PosBillingScreen> {
  late final TextEditingController _discountController;
  late final TextEditingController _customerNameController;
  late final TextEditingController _customerPhoneController;
  double _lastKnownDiscount = -1.0;
  String? _lastKnownCustomer;
  int _narrowTabIndex = 0; // 0: Menu, 1: Order & Checkout

  @override
  void initState() {
    super.initState();
    _discountController = TextEditingController();
    _customerNameController = TextEditingController();
    _customerPhoneController = TextEditingController();
  }

  @override
  void dispose() {
    _discountController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final posProvider = Provider.of<PosProvider>(context);
    final productProvider = Provider.of<ProductProvider>(context);
    final categoryProvider = Provider.of<CategoryProvider>(context);
    final tableProvider = Provider.of<TableProvider>(context);
    final waiterProvider = Provider.of<WaiterProvider>(context);
    final settings = Provider.of<SettingsProvider>(context).settings;
    final authProvider = Provider.of<AuthProvider>(context);
    final currency = settings.currencySymbol;

    // Synchronize discount controller when external state updates
    if (posProvider.discountAmount != _lastKnownDiscount) {
      _lastKnownDiscount = posProvider.discountAmount;
      final expectedText = posProvider.discountAmount > 0 ? posProvider.discountAmount.toStringAsFixed(2) : '';
      if (_discountController.text != expectedText) {
        _discountController.text = expectedText;
      }
    }

    // Synchronize customer info controllers
    final currentCustKey = '${posProvider.customerName}_${posProvider.customerPhone}';
    if (currentCustKey != _lastKnownCustomer) {
      _lastKnownCustomer = currentCustKey;
      if (_customerNameController.text != posProvider.customerName) {
        _customerNameController.text = posProvider.customerName;
      }
      if (_customerPhoneController.text != posProvider.customerPhone) {
        _customerPhoneController.text = posProvider.customerPhone;
      }
    }

    // Filter Products based on Category & Search
    final allProducts = productProvider.products;
    final filteredProducts = allProducts.where((p) {
      final matchesCategory = posProvider.selectedCategoryId == null ||
          p.categoryId == posProvider.selectedCategoryId;
      final matchesSearch = posProvider.searchQuery.isEmpty ||
          p.name.toLowerCase().contains(posProvider.searchQuery.toLowerCase());
      return matchesCategory && matchesSearch && p.isActive;
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final bool isNarrow = width < 720;
        final bool isMedium = width >= 720 && width < 1100;

        if (isNarrow) {
          return _buildNarrowLayout(
            context,
            posProvider,
            productProvider,
            categoryProvider,
            tableProvider,
            waiterProvider,
            settings,
            authProvider,
            currency,
            filteredProducts,
          );
        }

        if (isMedium) {
          return _buildMediumLayout(
            context,
            posProvider,
            productProvider,
            categoryProvider,
            tableProvider,
            waiterProvider,
            settings,
            authProvider,
            currency,
            filteredProducts,
          );
        }

        return _buildWideLayout(
          context,
          posProvider,
          productProvider,
          categoryProvider,
          tableProvider,
          waiterProvider,
          settings,
          authProvider,
          currency,
          filteredProducts,
        );
      },
    );
  }

  Widget _buildSegmentTab(int index, String title, IconData icon, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? Colors.white : AppColors.textSecondary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNarrowLayout(
    BuildContext context,
    PosProvider posProvider,
    ProductProvider productProvider,
    CategoryProvider categoryProvider,
    TableProvider tableProvider,
    WaiterProvider waiterProvider,
    AppSettingsModel settings,
    AuthProvider authProvider,
    String currency,
    List<ProductModel> filteredProducts,
  ) {
    return Column(
      children: [
        // Top Segmented Switcher: [ Menu Items | Order & Checkout ]
        Container(
          color: AppColors.cardBg,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              _buildSegmentTab(0, 'Menu Items', Icons.restaurant_menu_rounded, _narrowTabIndex == 0, () {
                setState(() => _narrowTabIndex = 0);
              }),
              const SizedBox(width: 8),
              _buildSegmentTab(
                1,
                'Order & Checkout (${posProvider.cart.length})',
                Icons.receipt_long_rounded,
                _narrowTabIndex == 1,
                () {
                  setState(() => _narrowTabIndex = 1);
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: IndexedStack(
            index: _narrowTabIndex,
            children: [
              Stack(
                children: [
                  _buildProductsContent(context, posProvider, productProvider, categoryProvider, tableProvider, waiterProvider, currency, filteredProducts),
                  if (posProvider.cart.isNotEmpty)
                    Positioned(
                      bottom: 12,
                      left: 16,
                      right: 16,
                      child: InkWell(
                        onTap: () => setState(() => _narrowTabIndex = 1),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${posProvider.cart.length} item${posProvider.cart.length > 1 ? 's' : ''} in cart',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Text(
                                    '$currency ${posProvider.calculateGrandTotal(settings.taxPercent).toStringAsFixed(0)}',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              _buildOrdersCheckoutPanel(
                context,
                posProvider,
                tableProvider,
                waiterProvider,
                settings,
                authProvider,
                currency,
                onBackToMenu: () => setState(() => _narrowTabIndex = 0),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMediumLayout(
    BuildContext context,
    PosProvider posProvider,
    ProductProvider productProvider,
    CategoryProvider categoryProvider,
    TableProvider tableProvider,
    WaiterProvider waiterProvider,
    AppSettingsModel settings,
    AuthProvider authProvider,
    String currency,
    List<ProductModel> filteredProducts,
  ) {
    return Row(
      children: [
        // Left Column: Products Grid (flex 8)
        Expanded(
          flex: 8,
          child: _buildProductsContent(context, posProvider, productProvider, categoryProvider, tableProvider, waiterProvider, currency, filteredProducts),
        ),
        const VerticalDivider(width: 1),
        // Right Column: Orders & Checkout Panel (flex 4 - compact)
        Expanded(
          flex: 4,
          child: _buildOrdersCheckoutPanel(context, posProvider, tableProvider, waiterProvider, settings, authProvider, currency),
        ),
      ],
    );
  }

  Widget _buildWideLayout(
    BuildContext context,
    PosProvider posProvider,
    ProductProvider productProvider,
    CategoryProvider categoryProvider,
    TableProvider tableProvider,
    WaiterProvider waiterProvider,
    AppSettingsModel settings,
    AuthProvider authProvider,
    String currency,
    List<ProductModel> filteredProducts,
  ) {
    return Row(
      children: [
        // LEFT COLUMN: Products Grid (Flex 8 - Maximum space for menu items!)
        Expanded(
          flex: 8,
          child: _buildProductsContent(context, posProvider, productProvider, categoryProvider, tableProvider, waiterProvider, currency, filteredProducts),
        ),
        const VerticalDivider(width: 1),

        // RIGHT COLUMN: Orders Checkout Panel (Flex 3 - sleeker, smaller checkout section)
        Expanded(
          flex: 3,
          child: _buildOrdersCheckoutPanel(context, posProvider, tableProvider, waiterProvider, settings, authProvider, currency),
        ),
      ],
    );
  }

  Widget _buildProductsContent(
    BuildContext context,
    PosProvider posProvider,
    ProductProvider productProvider,
    CategoryProvider categoryProvider,
    TableProvider tableProvider,
    WaiterProvider waiterProvider,
    String currency,
    List<ProductModel> filteredProducts,
  ) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Shift / Daily Sale Session Status Banner
          Consumer<SaleSessionProvider>(
            builder: (context, sessionProv, _) {
              final activeSession = sessionProv.activeSession;
              if (activeSession == null) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFED7AA)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.storefront_rounded, color: Color(0xFFEA580C), size: 24),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Shift is Currently Closed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF9A3412))),
                            Text('Start today\'s sale to enter counter change float & link all night sales.', style: TextStyle(fontSize: 11, color: Color(0xFFC2410C))),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                        label: const Text('Start Sale', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5)),
                        onPressed: () => SaleSessionDialogs.showStartSaleDialog(context),
                      ),
                    ],
                  ),
                );
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Shift Active (${activeSession.businessDate})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF166534)),
                          ),
                          Text(
                            'Opening Float: $currency ${activeSession.openingCash.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF15803D), fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'Sales: $currency ${activeSession.totalSales.toStringAsFixed(0)}',
                            style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Counter Total: $currency ${activeSession.totalCounterCash.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF166534), fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF166534),
                        side: const BorderSide(color: Color(0xFF166534)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      icon: const Icon(Icons.lunch_dining_rounded, size: 16),
                      label: const Text('Items Sold', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: () => DailySaleDetailDialog.show(context, activeSession),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      icon: const Icon(Icons.stop_circle_rounded, color: Colors.white, size: 18),
                      label: const Text('End Sale', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5)),
                      onPressed: () => SaleSessionDialogs.showEndSaleDialog(context),
                    ),
                  ],
                ),
              );
            },
          ),

          // Top Search Header
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (val) => posProvider.setSearchQuery(val),
                  decoration: const InputDecoration(
                    hintText: 'Search product by name or barcode...',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Refresh Menu & Tables',
                onPressed: () async {
                  await productProvider.loadProducts();
                  await categoryProvider.loadCategories();
                  await tableProvider.loadTableData();
                  await waiterProvider.loadWaiters();
                  if (context.mounted) {
                    await Provider.of<StockProvider>(context, listen: false).loadStockData();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Category Chips Filter Horizontal Bar
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: posProvider.selectedCategoryId == null,
                    label: const Text('All Items'),
                    onSelected: (_) => posProvider.setSelectedCategory(null),
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: posProvider.selectedCategoryId == null ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ...categoryProvider.categories.map((cat) {
                  final isSelected = posProvider.selectedCategoryId == cat.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(cat.name),
                      onSelected: (_) => posProvider.setSelectedCategory(cat.id),
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

          // Products Grid View
          Expanded(
            child: filteredProducts.isEmpty
                ? Center(child: Text('No products found', style: TextStyle(color: AppColors.textMuted)))
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 180,
                      childAspectRatio: 0.95,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = filteredProducts[index];
                      return _buildProductCard(context, product, posProvider, currency);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersCheckoutPanel(
    BuildContext context,
    PosProvider posProvider,
    TableProvider tableProvider,
    WaiterProvider waiterProvider,
    AppSettingsModel settings,
    AuthProvider authProvider,
    String currency, {
    VoidCallback? onBackToMenu,
  }) {
    final bool isCartEmpty = posProvider.cart.isEmpty;

    return Container(
      color: AppColors.cardBg,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Narrow screen: Back to Menu navigation button
          if (onBackToMenu != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                label: const Text('Back to Menu Items', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: onBackToMenu,
              ),
            ),
            const SizedBox(height: 4),
          ],

          // 1. TOP 3 BOXES: Dine In | Takeaway | Delivery
          _buildOrderTypeBoxes(context, posProvider, tableProvider, waiterProvider),
          const SizedBox(height: 8),

          // 2. CONTEXT STATUS ROW (Table & Waiter status and quick-switch pills)
          _buildContextStatusRow(context, posProvider, tableProvider, waiterProvider),
          const SizedBox(height: 8),

          // 3. EDITING INVOICE BANNER (if in edit mode)
          if (posProvider.isEditingInvoice) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade400, width: 1.5),
              ),
              child: Row(
                children: [
                  Icon(Icons.edit_note_rounded, color: Colors.amber.shade900, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Editing Invoice #${posProvider.editingSale!.invoiceNumber} (${posProvider.editingSale!.status})',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.amber.shade900),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () => posProvider.cancelEditingInvoice(),
                    child: Icon(Icons.close_rounded, size: 18, color: AppColors.error),
                  ),
                ],
              ),
            ),
          ],

          // 4. ACTIVE ORDER CART HEADER
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Active Order Cart',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: isCartEmpty ? Colors.grey.shade200 : AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${posProvider.cart.length} item${posProvider.cart.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isCartEmpty ? AppColors.textSecondary : Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              if (!isCartEmpty)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: const Size(0, 28),
                  ),
                  icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                  label: const Text('Clear', style: TextStyle(fontSize: 11.5)),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (dialogCtx) => AlertDialog(
                        title: const Text('Clear Cart?'),
                        content: const Text('Are you sure you want to remove all items from this order?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('Cancel')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                            onPressed: () {
                              Navigator.of(dialogCtx).pop();
                              final tableProv = Provider.of<TableProvider>(context, listen: false);
                              posProvider.clearCart();
                              tableProv.loadTableData();
                            },
                            child: const Text('Clear All', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
          const Divider(height: 12),

          // 5. CART ITEMS LIST (EXPANDED & SCROLLABLE)
          Expanded(
            child: isCartEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_outlined, size: 42, color: AppColors.textMuted.withValues(alpha: 0.4)),
                        const SizedBox(height: 8),
                        Text('Cart is empty', style: TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text('Tap menu items to add them to this order', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: posProvider.cart.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = posProvider.cart[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.productName,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    '$currency ${item.unitPrice.toStringAsFixed(0)} each',
                                    style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                  icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
                                  onPressed: () => posProvider.updateQuantity(index, item.quantity - 1),
                                ),
                                Container(
                                  constraints: const BoxConstraints(minWidth: 22),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${item.quantity}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                  icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                                  onPressed: () => _handleCartQuantityIncrease(context, index, item, posProvider),
                                ),
                              ],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$currency ${item.totalPrice.toStringAsFixed(0)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                              icon: Icon(Icons.close_rounded, size: 16, color: AppColors.error),
                              onPressed: () => posProvider.removeFromCart(index),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          const Divider(height: 12),

          // 6. FINANCIAL SUMMARY, PAYMENT METHOD, CUSTOMER & 3 ACTION BUTTONS
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Subtotal & Discount row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Subtotal: $currency ${posProvider.subtotal.toStringAsFixed(0)}',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Disc: ', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                      SizedBox(
                        width: 75,
                        height: 28,
                        child: TextField(
                          controller: _discountController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 12),
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            hintText: '0.0',
                            isDense: true,
                          ),
                          onChanged: (val) {
                            final double? d = double.tryParse(val);
                            _lastKnownDiscount = d ?? 0.0;
                            posProvider.setDiscount(d ?? 0.0);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Tax & Grand Total Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tax (${settings.taxPercent.toStringAsFixed(0)}%): $currency ${posProvider.calculateTax(settings.taxPercent).toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('TOTAL: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                      Text(
                        '$currency ${posProvider.calculateGrandTotal(settings.taxPercent).toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.primary),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Payment method row
              Row(
                children: ['Cash', 'Card', 'Online/UPI'].map((method) {
                  final isSelected = posProvider.paymentMethod == method;
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: InkWell(
                        onTap: () => posProvider.setPaymentMethod(method),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : AppColors.cardBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : AppColors.border,
                              width: 1.2,
                            ),
                          ),
                          child: Text(
                            method,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),

              // Optional Customer info (compact)
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 32,
                      child: TextField(
                        controller: _customerNameController,
                        style: const TextStyle(fontSize: 11.5),
                        decoration: const InputDecoration(
                          hintText: 'Customer Name (optional)',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        ),
                        onChanged: (val) {
                          _lastKnownCustomer = '${val}_${posProvider.customerPhone}';
                          posProvider.setCustomerInfo(val, posProvider.customerPhone);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: SizedBox(
                      height: 32,
                      child: TextField(
                        controller: _customerPhoneController,
                        style: const TextStyle(fontSize: 11.5),
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          hintText: 'Phone (optional)',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        ),
                        onChanged: (val) {
                          _lastKnownCustomer = '${posProvider.customerName}_$val';
                          posProvider.setCustomerInfo(posProvider.customerName, val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 7. THE 3 ACTION BUTTONS (Preserving all logic & edit modes)
              _buildBottomActionButtons(
                context: context,
                posProvider: posProvider,
                settings: settings,
                tableProvider: tableProvider,
                authProvider: authProvider,
                currency: currency,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Top 3 Order Type Boxes: Dine In, Takeaway, Delivery
  Widget _buildOrderTypeBoxes(
    BuildContext context,
    PosProvider posProvider,
    TableProvider tableProvider,
    WaiterProvider waiterProvider,
  ) {
    final currentType = posProvider.orderType;
    final selectedTable = posProvider.selectedTable;

    final options = [
      {
        'type': 'Dine In',
        'label': 'Dine In',
        'icon': Icons.table_restaurant_rounded,
        'subtitle': selectedTable != null ? selectedTable.tableName : 'Select Table',
        'isActive': currentType == 'Dine In' || selectedTable != null,
        'color': const Color(0xFF10B981), // Green
      },
      {
        'type': 'Takeaway',
        'label': 'Takeaway',
        'icon': Icons.takeout_dining_rounded,
        'subtitle': 'Counter Pick',
        'isActive': currentType == 'Takeaway' && selectedTable == null,
        'color': const Color(0xFFF97316), // Orange
      },
      {
        'type': 'Delivery',
        'label': 'Delivery',
        'icon': Icons.delivery_dining_rounded,
        'subtitle': 'Home Delivery',
        'isActive': currentType == 'Delivery' && selectedTable == null,
        'color': const Color(0xFF3B82F6), // Blue
      },
    ];

    return Row(
      children: options.map((opt) {
        final isSelected = opt['isActive'] as bool;
        final type = opt['type'] as String;
        final color = opt['color'] as Color;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: InkWell(
              onTap: () => _handleOrderTypeTap(
                context: context,
                type: type,
                posProvider: posProvider,
                tableProvider: tableProvider,
                waiterProvider: waiterProvider,
              ),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
                decoration: BoxDecoration(
                  color: isSelected ? color.withValues(alpha: 0.16) : AppColors.cardBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? color : AppColors.border,
                    width: isSelected ? 1.8 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.15),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : [],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          opt['icon'] as IconData,
                          size: 17,
                          color: isSelected ? color : AppColors.textSecondary,
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 3),
                          Icon(Icons.check_circle_rounded, size: 12, color: color),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      opt['label'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? color : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      opt['subtitle'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected ? color : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Quick status chip row for active table and waiter
  Widget _buildContextStatusRow(
    BuildContext context,
    PosProvider posProvider,
    TableProvider tableProvider,
    WaiterProvider waiterProvider,
  ) {
    final table = posProvider.selectedTable;
    final waiter = posProvider.selectedWaiter;
    final isDineIn = posProvider.orderType == 'Dine In' || table != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Table / Order Type chip
          Expanded(
            child: InkWell(
              onTap: () async {
                final sel = await PosTableSelectionDialog.show(
                  context,
                  posProvider: posProvider,
                  tableProvider: tableProvider,
                );
                if (sel != null && context.mounted && !posProvider.isEditingInvoice && posProvider.selectedWaiter == null) {
                  await PosWaiterSelectionDialog.show(
                    context,
                    posProvider: posProvider,
                    waiterProvider: waiterProvider,
                  );
                }
              },
              borderRadius: BorderRadius.circular(6),
              child: Row(
                children: [
                  Icon(
                    table != null
                        ? Icons.table_restaurant_rounded
                        : (isDineIn ? Icons.table_restaurant_outlined : Icons.shopping_bag_outlined),
                    size: 16,
                    color: table != null ? const Color(0xFF10B981) : AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      table != null
                          ? '${table.tableName} (${table.sectionName})'
                          : (isDineIn ? 'Choose Table' : posProvider.orderType),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: table != null ? const Color(0xFF10B981) : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_drop_down_rounded, size: 18, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
          const SizedBox(
            height: 16,
            child: VerticalDivider(width: 16, thickness: 1),
          ),
          // Waiter chip
          Expanded(
            child: InkWell(
              onTap: () {
                PosWaiterSelectionDialog.show(
                  context,
                  posProvider: posProvider,
                  waiterProvider: waiterProvider,
                );
              },
              borderRadius: BorderRadius.circular(6),
              child: Row(
                children: [
                  Icon(Icons.badge_rounded, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      waiter != null ? waiter.name : 'Self Service',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: waiter != null ? AppColors.primary : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_drop_down_rounded, size: 18, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Handles when one of the 3 order type boxes is tapped
  /// If Dine In: opens Table dialog, and when table is chosen opens Waiter dialog!
  Future<void> _handleOrderTypeTap({
    required BuildContext context,
    required String type,
    required PosProvider posProvider,
    required TableProvider tableProvider,
    required WaiterProvider waiterProvider,
  }) async {
    posProvider.setOrderType(type);

    if (type == 'Dine In') {
      // 1. Open Table selection dialog
      final selectedTable = await PosTableSelectionDialog.show(
        context,
        posProvider: posProvider,
        tableProvider: tableProvider,
      );

      // 2. If table was selected, automatically open Waiter selection dialog
      if (selectedTable != null && context.mounted && !posProvider.isEditingInvoice && posProvider.selectedWaiter == null) {
        await PosWaiterSelectionDialog.show(
          context,
          posProvider: posProvider,
          waiterProvider: waiterProvider,
        );
      }
    } else if (type == 'Takeaway') {
      posProvider.selectTable(null);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Switched to Takeaway / Counter. Select items from menu.'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else if (type == 'Delivery') {
      posProvider.selectTable(null);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Switched to Delivery order. Select items from menu.'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Bottom action buttons (Kitchen Token, Pay & Clear, Generate Bill - Remaining)
  Widget _buildBottomActionButtons({
    required BuildContext context,
    required PosProvider posProvider,
    required AppSettingsModel settings,
    required TableProvider tableProvider,
    required AuthProvider authProvider,
    required String currency,
  }) {
    if (posProvider.isEditingInvoice) {
      final sale = posProvider.editingSale!;
      if (sale.isRemaining) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Option 1: Save & Clear Bill (Mark as Paid)
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: posProvider.isProcessing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check_circle_rounded, size: 20, color: Colors.white),
                label: Text(
                  posProvider.isProcessing ? 'Processing...' : 'Save & Clear Bill (Mark as Paid)',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                onPressed: posProvider.isProcessing
                    ? null
                    : () => _handleSaveEditedInvoice(
                          context: context,
                          posProvider: posProvider,
                          settings: settings,
                          authProvider: authProvider,
                          status: 'CLEARED',
                        ),
              ),
            ),
            const SizedBox(height: 6),

            // Option 2: Save Changes (Keep Remaining)
            SizedBox(
              width: double.infinity,
              height: 40,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.save_outlined, size: 16),
                label: Text(
                  posProvider.isProcessing ? 'Saving...' : 'Save Changes (Keep Remaining #${sale.invoiceNumber})',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: posProvider.isProcessing
                    ? null
                    : () => _handleSaveEditedInvoice(
                          context: context,
                          posProvider: posProvider,
                          settings: settings,
                          authProvider: authProvider,
                          status: 'REMAINING',
                        ),
              ),
            ),
            const SizedBox(height: 6),

            // Option 3: Print Kitchen Token / Cancel Edit
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade800,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.soup_kitchen_rounded, size: 16, color: Colors.white),
                      label: const Text(
                        'Kitchen Slip',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      onPressed: posProvider.cart.isEmpty
                          ? null
                          : () => _handleKitchenSlipAction(
                                context: context,
                                posProvider: posProvider,
                                settings: settings,
                                tableProvider: tableProvider,
                                authProvider: authProvider,
                              ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  height: 36,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => posProvider.cancelEditingInvoice(),
                    child: const Text('Cancel Edit', style: TextStyle(fontSize: 11.5)),
                  ),
                ),
              ],
            ),
          ],
        );
      } else {
        // Cleared invoice edit
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: posProvider.isProcessing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check_circle_outline_rounded, size: 20),
                label: Text(
                  posProvider.isProcessing ? 'Saving Changes...' : 'Save & Update Invoice #${sale.invoiceNumber}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                onPressed: posProvider.isProcessing
                    ? null
                    : () => _handleSaveEditedInvoice(
                          context: context,
                          posProvider: posProvider,
                          settings: settings,
                          authProvider: authProvider,
                        ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade800,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.soup_kitchen_rounded, size: 16, color: Colors.white),
                      label: const Text(
                        'Kitchen Slip',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      onPressed: posProvider.cart.isEmpty
                          ? null
                          : () => _handleKitchenSlipAction(
                                context: context,
                                posProvider: posProvider,
                                settings: settings,
                                tableProvider: tableProvider,
                                authProvider: authProvider,
                              ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  height: 36,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => posProvider.cancelEditingInvoice(),
                    child: const Text('Cancel Edit', style: TextStyle(fontSize: 11.5)),
                  ),
                ),
              ],
            ),
          ],
        );
      }
    }

    // Standard New Order: The 3 options!
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Separate Kitchen Token Button (For cook)
        SizedBox(
          width: double.infinity,
          height: 42,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade800,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.soup_kitchen_rounded, size: 18, color: Colors.white),
            label: Text(
              posProvider.hasAdditionalItems
                  ? 'Print Kitchen Token (+${posProvider.additionalItemsCount} Add-on)'
                  : 'Print Kitchen Token (For Cook)',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            onPressed: posProvider.cart.isEmpty
                ? null
                : () => _handleKitchenSlipAction(
                      context: context,
                      posProvider: posProvider,
                      settings: settings,
                      tableProvider: tableProvider,
                      authProvider: authProvider,
                    ),
          ),
        ),
        const SizedBox(height: 8),

        // 2. Pay & Clear Bill (Instant Payment)
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: posProvider.isProcessing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.check_circle_rounded, size: 20, color: Colors.white),
            label: Text(
              posProvider.isProcessing ? 'Processing Order...' : 'Pay & Clear Bill',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            onPressed: posProvider.isProcessing || posProvider.cart.isEmpty
                ? null
                : () => _handleCheckout(
                      context: context,
                      posProvider: posProvider,
                      settings: settings,
                      authProvider: authProvider,
                      status: 'CLEARED',
                    ),
          ),
        ),
        const SizedBox(height: 8),

        // 3. Generate Bill (Remaining / Delayed Payment)
        SizedBox(
          width: double.infinity,
          height: 42,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary, width: 1.5),
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: posProvider.isProcessing
                ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
                : Icon(Icons.hourglass_top_rounded, size: 18, color: AppColors.primary),
            label: Text(
              posProvider.isProcessing ? 'Generating Bill...' : 'Generate Bill (Delayed / Remaining)',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
            onPressed: posProvider.isProcessing || posProvider.cart.isEmpty
                ? null
                : () => _handleCheckout(
                      context: context,
                      posProvider: posProvider,
                      settings: settings,
                      authProvider: authProvider,
                      status: 'REMAINING',
                    ),
          ),
        ),
      ],
    );
  }


  Future<void> _handleProductSelection(
    BuildContext context,
    ProductModel product,
    PosProvider posProvider,
  ) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false).settings;
    final stockService = StockDeductionService();

    final stockCheck = await stockService.checkProductStockForCart(
      product: product,
      additionalQuantity: 1,
      currentCart: posProvider.cart,
      milkCupsPerKg: settings.milkCupsPerKg,
    );

    if (!context.mounted) return;

    if (!stockCheck.isAvailable && stockCheck.depletedItems.isNotEmpty) {
      await OutOfStockDialog.show(
        context: context,
        product: product,
        depletedItems: stockCheck.depletedItems,
        onStockAddedAndSelect: () {
          posProvider.addToCart(product);
        },
      );
    } else {
      posProvider.addToCart(product);
    }
  }

  Future<void> _handleCartQuantityIncrease(
    BuildContext context,
    int index,
    SaleItemModel item,
    PosProvider posProvider,
  ) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false).settings;
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final stockService = StockDeductionService();

    ProductModel targetProduct;
    try {
      targetProduct = productProvider.products.firstWhere((p) => p.id == item.productId);
    } catch (_) {
      targetProduct = ProductModel(
        id: item.productId,
        name: item.productName,
        categoryId: 0,
        sellingPrice: item.unitPrice,
        costPrice: item.unitCost,
      );
    }

    final stockCheck = await stockService.checkProductStockForCart(
      product: targetProduct,
      additionalQuantity: 1,
      currentCart: posProvider.cart,
      milkCupsPerKg: settings.milkCupsPerKg,
    );

    if (!context.mounted) return;

    if (!stockCheck.isAvailable && stockCheck.depletedItems.isNotEmpty) {
      await OutOfStockDialog.show(
        context: context,
        product: targetProduct,
        depletedItems: stockCheck.depletedItems,
        onStockAddedAndSelect: () {
          posProvider.updateQuantity(index, item.quantity + 1);
        },
      );
    } else {
      posProvider.updateQuantity(index, item.quantity + 1);
    }
  }

  Widget _buildProductCard(
    BuildContext context,
    ProductModel product,
    PosProvider posProvider,
    String currency,
  ) {
    final stockProvider = Provider.of<StockProvider>(context);
    final matchingStock = stockProvider.findStockByProductName(product.name);
    final bool hasRecipe = product.recipeItems.isNotEmpty;
    final bool isDirectOutOfStock = !hasRecipe && matchingStock != null && matchingStock.quantity <= 0.0;

    return InkWell(
      onTap: () => _handleProductSelection(context, product, posProvider),
      borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
          border: Border.all(
            color: isDirectOutOfStock ? Colors.red.shade300 : AppColors.border,
            width: isDirectOutOfStock ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isDirectOutOfStock ? Colors.red : AppColors.primary).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isDirectOutOfStock ? Icons.remove_shopping_cart_rounded : Icons.fastfood_rounded,
                    color: isDirectOutOfStock ? Colors.red.shade700 : AppColors.primary,
                    size: 20,
                  ),
                ),
                Text(
                  '$currency ${product.sellingPrice.toStringAsFixed(0)}',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: isDirectOutOfStock
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text(
                            'Stock: 0',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade800,
                            ),
                          ),
                        )
                      : Text(
                          product.categoryName ?? 'Menu Item',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                        ),
                ),
                Icon(
                  isDirectOutOfStock ? Icons.add_alert_rounded : Icons.add_circle_rounded,
                  color: isDirectOutOfStock ? Colors.orange.shade800 : AppColors.accent,
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _handleKitchenSlipAction({
    required BuildContext context,
    required PosProvider posProvider,
    required AppSettingsModel settings,
    required TableProvider tableProvider,
    required AuthProvider authProvider,
  }) async {
    if (posProvider.cart.isEmpty) return;

    final previousItems = posProvider.getPreviouslyPrintedKitchenItems();
    final additionalItems = posProvider.getAdditionalCartItems();
    final currentTokenOrInvoice = posProvider.getActiveTokenOrInvoiceNumber();
    final tableName = posProvider.selectedTable?.tableName ?? 'Takeaway';
    final totalItemsCount = posProvider.cart.fold<int>(0, (int sum, i) => sum + i.quantity);

    if (previousItems.isNotEmpty && additionalItems.isNotEmpty) {
      // User has already sent items to kitchen and added more items!
      // Provide options dialog: "Additional Items Only" vs "Full Order Ticket"
      await showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.soup_kitchen_rounded, color: Colors.orange.shade900, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Kitchen Order Slip', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    Text(
                      'Invoice / Token #$currentTokenOrInvoice • $tableName',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.normal),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.orange.shade900),
                        const SizedBox(width: 6),
                        Text(
                          'Previous ticket already sent to kitchen!',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You added +${posProvider.additionalItemsCount} new item(s). Choose what to send to the cook:',
                      style: TextStyle(fontSize: 11.5, color: Colors.orange.shade900),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Option 1: Additional items only (RECOMMENDED)
              InkWell(
                onTap: () async {
                  Navigator.of(dialogCtx).pop();
                  final draftSale = SaleModel(
                    invoiceNumber: currentTokenOrInvoice,
                    dateTime: DateTime.now().toIso8601String(),
                    cashierName: authProvider.currentUser.name,
                    tableName: posProvider.selectedTable?.tableName,
                    waiterName: posProvider.selectedWaiter?.name,
                    subtotal: additionalItems.fold<double>(0.0, (double s, i) => s + i.totalPrice),
                    grandTotal: additionalItems.fold<double>(0.0, (double s, i) => s + i.totalPrice),
                    paymentMethod: posProvider.paymentMethod,
                    items: additionalItems,
                  );

                  if (posProvider.selectedTable?.id != null) {
                    await tableProvider.updateTableStatus(posProvider.selectedTable!.id!, 'Occupied');
                  }

                  posProvider.markCurrentCartAsPrintedToKitchen(tokenNumber: currentTokenOrInvoice);

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Printed +${posProvider.additionalItemsCount} additional items for Cook (Invoice #$currentTokenOrInvoice)!'),
                        backgroundColor: Colors.orange.shade900,
                      ),
                    );
                  }

                  await InvoiceService.printKitchenSlip(
                    sale: draftSale,
                    settings: settings,
                    isAdditionalOnly: true,
                    totalOrderItemsCount: totalItemsCount,
                  );
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.accent, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.add_task_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Additional Items Only (+${posProvider.additionalItemsCount})',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.accent),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'RECOMMENDED',
                                    style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.green.shade900),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Prints ONLY newly added item(s) with SAME Invoice #$currentTokenOrInvoice so cook prepares only what is extra.',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Option 2: Full order ticket
              InkWell(
                onTap: () async {
                  Navigator.of(dialogCtx).pop();
                  final draftSale = SaleModel(
                    invoiceNumber: currentTokenOrInvoice,
                    dateTime: DateTime.now().toIso8601String(),
                    cashierName: authProvider.currentUser.name,
                    tableName: posProvider.selectedTable?.tableName,
                    waiterName: posProvider.selectedWaiter?.name,
                    subtotal: posProvider.subtotal,
                    grandTotal: posProvider.calculateGrandTotal(settings.taxPercent),
                    paymentMethod: posProvider.paymentMethod,
                    items: List.from(posProvider.cart),
                  );

                  if (posProvider.selectedTable?.id != null) {
                    await tableProvider.updateTableStatus(posProvider.selectedTable!.id!, 'Occupied');
                  }

                  posProvider.markCurrentCartAsPrintedToKitchen(tokenNumber: currentTokenOrInvoice);

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Printed full order ticket ($totalItemsCount items) for Cook (Invoice #$currentTokenOrInvoice).'),
                        backgroundColor: Colors.orange.shade900,
                      ),
                    );
                  }

                  await InvoiceService.printKitchenSlip(
                    sale: draftSale,
                    settings: settings,
                    isAdditionalOnly: false,
                  );
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade600,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Full Order Ticket ($totalItemsCount Items Total)',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Reprints the entire order ticket with all items under Invoice #$currentTokenOrInvoice.',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    } else {
      // First time printing for this order, or reprinting when no new items added
      final draftSale = SaleModel(
        invoiceNumber: currentTokenOrInvoice,
        dateTime: DateTime.now().toIso8601String(),
        cashierName: authProvider.currentUser.name,
        tableName: posProvider.selectedTable?.tableName,
        waiterName: posProvider.selectedWaiter?.name,
        subtotal: posProvider.subtotal,
        grandTotal: posProvider.calculateGrandTotal(settings.taxPercent),
        paymentMethod: posProvider.paymentMethod,
        items: List.from(posProvider.cart),
      );

      if (posProvider.selectedTable?.id != null) {
        await tableProvider.updateTableStatus(posProvider.selectedTable!.id!, 'Occupied');
      }

      posProvider.markCurrentCartAsPrintedToKitchen(tokenNumber: currentTokenOrInvoice);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kitchen Token Printed for Cook! Order active for $tableName (Invoice #$currentTokenOrInvoice).'),
            backgroundColor: Colors.orange.shade900,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      await InvoiceService.printKitchenSlip(
        sale: draftSale,
        settings: settings,
        isAdditionalOnly: false,
      );
    }
  }

  Future<void> _handleCheckout({
    required BuildContext context,
    required PosProvider posProvider,
    required AppSettingsModel settings,
    required AuthProvider authProvider,
    required String status,
  }) async {
    final bool isRemaining = status.toUpperCase() == 'REMAINING';

    final sessionProv = Provider.of<SaleSessionProvider>(context, listen: false);

    final sale = await posProvider.checkout(
      cashierName: authProvider.currentUser.name,
      taxPercent: settings.taxPercent,
      milkCupsPerKg: settings.milkCupsPerKg,
      status: status,
      sessionId: sessionProv.activeSession?.id,
      onError: (err) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: AppColors.error),
        );
      },
      onWarnings: (warnings) {
        for (var w in warnings) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(w), backgroundColor: AppColors.warning),
          );
        }
      },
    );

    if (sale != null && context.mounted) {
      await sessionProv.refreshActiveSessionFinancials();
      if (!context.mounted) return;
      await Provider.of<DashboardProvider>(context, listen: false).loadDashboardData();
      if (!context.mounted) return;
      Provider.of<StockProvider>(context, listen: false).loadStockData();
      if (!context.mounted) return;
      Provider.of<TableProvider>(context, listen: false).loadTableData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isRemaining
                ? 'Bill Generated (#${sale.invoiceNumber}) as REMAINING (Payment Delayed). Table is active.'
                : 'Order Paid & Cleared! Invoice #${sale.invoiceNumber} - Total Sales Updated.',
          ),
          backgroundColor: isRemaining ? Colors.orange.shade800 : AppColors.accent,
          duration: const Duration(seconds: 4),
        ),
      );

      // Print Customer Receipt
      await InvoiceService.printInvoice(sale: sale, settings: settings);
    }
  }

  Future<void> _handleSaveEditedInvoice({
    required BuildContext context,
    required PosProvider posProvider,
    required AppSettingsModel settings,
    required AuthProvider authProvider,
    String? status,
  }) async {
    final hadAddOns = posProvider.hasAdditionalItems;
    final addOnCount = posProvider.additionalItemsCount;
    final additionalItems = posProvider.getAdditionalCartItems();
    final invoiceNum = posProvider.editingSale!.invoiceNumber;
    final table = posProvider.selectedTable;
    final waiter = posProvider.selectedWaiter;
    final cashier = authProvider.currentUser.name;
    final bool isClearingNow = status?.toUpperCase() == 'CLEARED';

    final updatedSale = await posProvider.saveEditedInvoice(
      cashierName: authProvider.currentUser.name,
      taxPercent: settings.taxPercent,
      milkCupsPerKg: settings.milkCupsPerKg,
      status: status,
      onError: (err) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: AppColors.error),
        );
      },
      onWarnings: (warnings) {
        for (var w in warnings) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(w), backgroundColor: AppColors.warning),
          );
        }
      },
    );

    if (updatedSale != null && context.mounted) {
      await Provider.of<SaleSessionProvider>(context, listen: false).refreshActiveSessionFinancials();
      if (!context.mounted) return;
      await Provider.of<DashboardProvider>(context, listen: false).loadDashboardData();
      if (!context.mounted) return;
      Provider.of<StockProvider>(context, listen: false).loadStockData();
      if (!context.mounted) return;
      Provider.of<TableProvider>(context, listen: false).loadTableData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isClearingNow
                ? 'Invoice #$invoiceNum updated & CLEARED! Total Sales Updated.'
                : (hadAddOns
                    ? 'Invoice #$invoiceNum updated with +$addOnCount new items!'
                    : 'Invoice #$invoiceNum updated successfully!'),
          ),
          backgroundColor: AppColors.accent,
          duration: const Duration(seconds: 5),
          action: hadAddOns
              ? SnackBarAction(
                  label: 'Print Kitchen Slip (+$addOnCount)',
                  textColor: Colors.white,
                  onPressed: () async {
                    final addOnSale = SaleModel(
                      invoiceNumber: invoiceNum,
                      dateTime: DateTime.now().toIso8601String(),
                      cashierName: cashier,
                      tableName: table?.tableName,
                      waiterName: waiter?.name,
                      subtotal: additionalItems.fold<double>(0.0, (double s, i) => s + i.totalPrice),
                      grandTotal: additionalItems.fold<double>(0.0, (double s, i) => s + i.totalPrice),
                      paymentMethod: updatedSale.paymentMethod,
                      items: additionalItems,
                    );
                    await InvoiceService.printKitchenSlip(
                      sale: addOnSale,
                      settings: settings,
                      isAdditionalOnly: true,
                      totalOrderItemsCount: updatedSale.items.fold<int>(0, (int s, i) => s + i.quantity),
                    );
                  },
                )
              : SnackBarAction(
                  label: 'Print Receipt',
                  textColor: Colors.white,
                  onPressed: () => InvoiceService.printInvoice(sale: updatedSale, settings: settings),
                ),
        ),
      );
    }
  }
}