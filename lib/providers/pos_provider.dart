import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../models/sale_model.dart';
import '../models/cafe_table_model.dart';
import '../models/waiter_model.dart';
import '../models/table_draft_model.dart';
import '../repositories/sale_repository.dart';
import '../repositories/table_draft_repository.dart';
import '../repositories/table_repository.dart';
import '../services/stock_deduction_service.dart';

class PosProvider with ChangeNotifier {
  final SaleRepository _saleRepository;
  final StockDeductionService _stockService;
  final TableDraftRepository _draftRepository;
  final TableRepository _tableRepository;

  PosProvider({
    SaleRepository? saleRepository,
    StockDeductionService? stockService,
    TableDraftRepository? draftRepository,
    TableRepository? tableRepository,
    bool autoLoadDrafts = true,
  })  : _saleRepository = saleRepository ?? SaleRepository(),
        _stockService = stockService ?? StockDeductionService(),
        _draftRepository = draftRepository ?? TableDraftRepository(),
        _tableRepository = tableRepository ?? TableRepository() {
    if (autoLoadDrafts) {
      loadSavedTableDrafts();
    }
  }

  int? _selectedCategoryId; // null = All Categories
  String _searchQuery = '';

  final List<SaleItemModel> _cart = [];
  CafeTableModel? _selectedTable;
  WaiterModel? _selectedWaiter;
  String _customerName = '';
  String _customerPhone = '';
  double _discountAmount = 0.0;
  String _paymentMethod = 'Cash';

  String _orderType = 'Dine In'; // 'Dine In', 'Takeaway', 'Delivery'
  SaleModel? _editingSale;
  bool _isProcessing = false;

  int? get selectedCategoryId => _selectedCategoryId;
  String get searchQuery => _searchQuery;
  List<SaleItemModel> get cart => _cart;
  CafeTableModel? get selectedTable => _selectedTable;
  WaiterModel? get selectedWaiter => _selectedWaiter;
  String get customerName => _customerName;
  String get customerPhone => _customerPhone;
  double get discountAmount => _discountAmount;
  String get paymentMethod => _paymentMethod;
  String get orderType => _orderType;
  bool get isProcessing => _isProcessing;
  SaleModel? get editingSale => _editingSale;
  bool get isEditingInvoice => _editingSale != null;

  void setOrderType(String type) {
    _orderType = type;
    if (type != 'Dine In') {
      _selectedTable = null;
    }
    notifyListeners();
  }

  void setSelectedCategory(int? categoryId) {
    _selectedCategoryId = categoryId;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void addToCart(ProductModel product) {
    final existingIndex = _cart.indexWhere((item) => item.productId == product.id);
    if (existingIndex >= 0) {
      final existing = _cart[existingIndex];
      final newQty = existing.quantity + 1;
      _cart[existingIndex] = SaleItemModel(
        id: existing.id,
        productId: existing.productId,
        productName: existing.productName,
        quantity: newQty,
        unitPrice: existing.unitPrice,
        unitCost: existing.unitCost,
        totalPrice: existing.unitPrice * newQty,
        notes: existing.notes,
      );
    } else {
      _cart.add(SaleItemModel(
        productId: product.id!,
        productName: product.name,
        quantity: 1,
        unitPrice: product.sellingPrice,
        unitCost: product.costPrice,
        totalPrice: product.sellingPrice,
      ));
    }
    _syncAndPersistActiveTableCart();
    notifyListeners();
  }

  void updateQuantity(int index, int newQty) {
    if (newQty <= 0) {
      _cart.removeAt(index);
    } else {
      final item = _cart[index];
      _cart[index] = SaleItemModel(
        id: item.id,
        productId: item.productId,
        productName: item.productName,
        quantity: newQty,
        unitPrice: item.unitPrice,
        unitCost: item.unitCost,
        totalPrice: item.unitPrice * newQty,
        notes: item.notes,
      );
    }
    _syncAndPersistActiveTableCart();
    notifyListeners();
  }

  void updateItemNote(int index, String note) {
    final item = _cart[index];
    _cart[index] = SaleItemModel(
      id: item.id,
      productId: item.productId,
      productName: item.productName,
      quantity: item.quantity,
      unitPrice: item.unitPrice,
      unitCost: item.unitCost,
      totalPrice: item.totalPrice,
      notes: note,
    );
    _syncAndPersistActiveTableCart();
    notifyListeners();
  }

  void removeFromCart(int index) {
    _cart.removeAt(index);
    _syncAndPersistActiveTableCart();
    notifyListeners();
  }

  final Map<int, List<SaleItemModel>> _tableCarts = {};
  final Map<int, WaiterModel?> _tableWaiters = {};
  final Map<int, List<SaleItemModel>> _tablePrintedKitchenItems = {};
  final Map<int, String> _tableTokenNumbers = {};
  List<SaleItemModel> _takeawayPrintedKitchenItems = [];
  String? _takeawayTokenNumber;
  List<SaleItemModel> _editingSaleKitchenPrintedItems = [];

  Map<int, List<SaleItemModel>> get tableCarts => _tableCarts;

  /// Loads saved table drafts from persistent SQLite database on startup
  Future<void> loadSavedTableDrafts() async {
    try {
      final drafts = await _draftRepository.getAllDrafts();
      for (final draft in drafts) {
        if (draft.items.isNotEmpty) {
          _tableCarts[draft.tableId] = draft.items;
          if (draft.waiterId != null || draft.waiterName != null) {
            _tableWaiters[draft.tableId] = WaiterModel(
              id: draft.waiterId,
              name: draft.waiterName ?? '',
              phone: '',
            );
          }
          if (draft.kitchenPrintedItems.isNotEmpty) {
            _tablePrintedKitchenItems[draft.tableId] = draft.kitchenPrintedItems;
          }
          if (draft.tokenNumber != null && draft.tokenNumber!.isNotEmpty) {
            _tableTokenNumbers[draft.tableId] = draft.tokenNumber!;
          }
          try {
            await _tableRepository.updateTableStatus(
              tableId: draft.tableId,
              status: 'Occupied',
            );
          } catch (_) {}
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  /// Automatically syncs in-memory tableCart and persists draft to SQLite.
  /// Also marks table as Occupied in tables table when cart has items.
  void _syncAndPersistActiveTableCart() {
    if (_selectedTable != null && _selectedTable!.id != null) {
      final tableId = _selectedTable!.id!;
      if (_cart.isNotEmpty) {
        _tableCarts[tableId] = List.from(_cart);
        _tableWaiters[tableId] = _selectedWaiter;
        final draft = TableDraftModel(
          tableId: tableId,
          waiterId: _selectedWaiter?.id,
          waiterName: _selectedWaiter?.name,
          customerName: _customerName,
          customerPhone: _customerPhone,
          orderType: _orderType,
          discountAmount: _discountAmount,
          paymentMethod: _paymentMethod,
          tokenNumber: _tableTokenNumbers[tableId],
          items: List.from(_cart),
          kitchenPrintedItems: _tablePrintedKitchenItems[tableId] ?? [],
          updatedAt: DateTime.now().toIso8601String(),
        );
        _draftRepository.saveDraft(draft).catchError((_) {});
        _tableRepository.updateTableStatus(
          tableId: tableId,
          status: 'Occupied',
        ).catchError((_) {});
      } else {
        _tableCarts.remove(tableId);
        _tableWaiters.remove(tableId);
        _tablePrintedKitchenItems.remove(tableId);
        _tableTokenNumbers.remove(tableId);
        _draftRepository.deleteDraft(tableId).catchError((_) {});
        _tableRepository.updateTableStatus(
          tableId: tableId,
          status: 'Available',
        ).catchError((_) {});
      }
    }
  }

  void clearCart({bool isCheckout = false}) {
    if (_selectedTable != null && _selectedTable!.id != null) {
      final tableId = _selectedTable!.id!;
      _tableCarts.remove(tableId);
      _tableWaiters.remove(tableId);
      _tablePrintedKitchenItems.remove(tableId);
      _tableTokenNumbers.remove(tableId);
      _draftRepository.deleteDraft(tableId).catchError((_) {});
      if (!isCheckout) {
        _tableRepository.updateTableStatus(
          tableId: tableId,
          status: 'Available',
        ).catchError((_) {});
      }
    } else {
      _takeawayPrintedKitchenItems.clear();
      _takeawayTokenNumber = null;
    }
    _cart.clear();
    _selectedTable = null;
    _selectedWaiter = null;
    _customerName = '';
    _customerPhone = '';
    _discountAmount = 0.0;
    _paymentMethod = 'Cash';
    _orderType = 'Dine In';
    _editingSale = null;
    _editingSaleKitchenPrintedItems.clear();
    notifyListeners();
  }

  /// Clears a specific table's draft order and releases the table to Available
  Future<void> clearTableDraft(int tableId) async {
    _tableCarts.remove(tableId);
    _tableWaiters.remove(tableId);
    _tablePrintedKitchenItems.remove(tableId);
    _tableTokenNumbers.remove(tableId);
    if (_selectedTable?.id == tableId) {
      _cart.clear();
      _selectedTable = null;
      _selectedWaiter = null;
    }
    await _draftRepository.deleteDraft(tableId);
    await _tableRepository.updateTableStatus(
      tableId: tableId,
      status: 'Available',
    );
    notifyListeners();
  }

  void loadInvoiceForEditing(
    SaleModel sale, {
    CafeTableModel? table,
    WaiterModel? waiter,
  }) {
    _editingSale = sale;
    _editingSaleKitchenPrintedItems = List.from(sale.items);
    _cart.clear();
    for (var item in sale.items) {
      _cart.add(SaleItemModel(
        id: item.id,
        productId: item.productId,
        productName: item.productName,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        unitCost: item.unitCost,
        totalPrice: item.totalPrice,
        notes: item.notes,
      ));
    }
    _selectedTable = table;
    _selectedWaiter = waiter;
    _customerName = sale.customerName ?? '';
    _customerPhone = sale.customerPhone ?? '';
    _discountAmount = sale.discount;
    _paymentMethod = sale.paymentMethod;
    notifyListeners();
  }

  void cancelEditingInvoice() {
    _editingSale = null;
    _editingSaleKitchenPrintedItems.clear();
    clearCart();
  }

  /// Returns items already sent/printed to the kitchen for the current order
  List<SaleItemModel> getPreviouslyPrintedKitchenItems() {
    if (_editingSale != null) {
      return _editingSaleKitchenPrintedItems;
    }
    if (_selectedTable != null && _selectedTable!.id != null) {
      return _tablePrintedKitchenItems[_selectedTable!.id!] ?? [];
    }
    return _takeawayPrintedKitchenItems;
  }

  /// Calculates and returns only newly added / delta items since previous kitchen print or original invoice
  List<SaleItemModel> getAdditionalCartItems() {
    final previousItems = getPreviouslyPrintedKitchenItems();
    if (previousItems.isEmpty) {
      return [];
    }

    final Map<int, int> prevQtyMap = {};
    for (var item in previousItems) {
      prevQtyMap[item.productId] = (prevQtyMap[item.productId] ?? 0) + item.quantity;
    }

    final List<SaleItemModel> additionalItems = [];
    for (var item in _cart) {
      final prevQty = prevQtyMap[item.productId] ?? 0;
      final delta = item.quantity - prevQty;
      if (delta > 0) {
        additionalItems.add(SaleItemModel(
          id: item.id,
          productId: item.productId,
          productName: item.productName,
          quantity: delta,
          unitPrice: item.unitPrice,
          unitCost: item.unitCost,
          totalPrice: item.unitPrice * delta,
          notes: item.notes != null && item.notes!.isNotEmpty
              ? '${item.notes} (+$delta add-on, Total: ${item.quantity})'
              : '(+$delta add-on, Total: ${item.quantity})',
        ));
      }
    }
    return additionalItems;
  }

  bool get hasAdditionalItems => getAdditionalCartItems().isNotEmpty;

  int get additionalItemsCount =>
      getAdditionalCartItems().fold(0, (sum, item) => sum + item.quantity);

  /// Mark current cart items as printed to kitchen to prevent duplicate cooking
  void markCurrentCartAsPrintedToKitchen({String? tokenNumber}) {
    final effectiveToken = tokenNumber ?? getActiveTokenOrInvoiceNumber();
    if (_editingSale != null) {
      _editingSaleKitchenPrintedItems = List.from(_cart);
    } else if (_selectedTable != null && _selectedTable!.id != null) {
      _tablePrintedKitchenItems[_selectedTable!.id!] = List.from(_cart);
      _tableTokenNumbers[_selectedTable!.id!] = effectiveToken;
    } else {
      _takeawayPrintedKitchenItems = List.from(_cart);
      _takeawayTokenNumber = effectiveToken;
    }
    notifyListeners();
  }

  /// Retrieves the stable, consistent token or invoice number for the current context
  String getActiveTokenOrInvoiceNumber() {
    if (_editingSale != null) {
      return _editingSale!.invoiceNumber;
    }
    if (_selectedTable != null && _selectedTable!.id != null) {
      if (_selectedTable!.activeInvoiceNumber != null &&
          _selectedTable!.activeInvoiceNumber!.isNotEmpty) {
        return _selectedTable!.activeInvoiceNumber!;
      }
      if (_tableTokenNumbers.containsKey(_selectedTable!.id!)) {
        return _tableTokenNumbers[_selectedTable!.id!]!;
      }
      final cleanName = _selectedTable!.tableName.replaceAll(' ', '');
      final generated = 'T-$cleanName';
      _tableTokenNumbers[_selectedTable!.id!] = generated;
      return generated;
    }
    if (_takeawayTokenNumber != null) {
      return _takeawayTokenNumber!;
    }
    final generated = 'TK-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    _takeawayTokenNumber = generated;
    return generated;
  }

  void selectTable(CafeTableModel? table) {
    if (table != null) {
      _orderType = 'Dine In';
    }
    // 1. Save and persist current cart for previous table if any
    if (_selectedTable != null && _selectedTable!.id != null) {
      _syncAndPersistActiveTableCart();
    }

    _selectedTable = table;

    // 2. Restore cart for newly selected table if saved
    if (table != null && table.id != null && _tableCarts.containsKey(table.id!)) {
      _cart.clear();
      _cart.addAll(_tableCarts[table.id!]!);
      _selectedWaiter = _tableWaiters[table.id!];
    } else if (table != null && table.id != null && !_tableCarts.containsKey(table.id!)) {
      _cart.clear();
      _selectedWaiter = null;
    }
    notifyListeners();
  }

  /// Swaps in-memory cart, waiters, kitchen prints, SQLite drafts, and active selections between two tables
  void swapTableOrders(CafeTableModel tableA, CafeTableModel tableB) {
    if (tableA.id == null || tableB.id == null) return;
    final aId = tableA.id!;
    final bId = tableB.id!;
    if (aId == bId) return;

    // 1. Sync current cart if currently pointing to tableA or tableB
    if (_selectedTable?.id == aId || _selectedTable?.id == bId) {
      _syncAndPersistActiveTableCart();
    }

    // 2. Swap tableCarts
    final cartA = _tableCarts.remove(aId);
    final cartB = _tableCarts.remove(bId);
    if (cartB != null && cartB.isNotEmpty) _tableCarts[aId] = cartB;
    if (cartA != null && cartA.isNotEmpty) _tableCarts[bId] = cartA;

    // 3. Swap tableWaiters
    final waiterA = _tableWaiters.remove(aId);
    final waiterB = _tableWaiters.remove(bId);
    if (waiterB != null) _tableWaiters[aId] = waiterB;
    if (waiterA != null) _tableWaiters[bId] = waiterA;

    // 4. Swap kitchen printed items
    final kitchenA = _tablePrintedKitchenItems.remove(aId);
    final kitchenB = _tablePrintedKitchenItems.remove(bId);
    if (kitchenB != null && kitchenB.isNotEmpty) _tablePrintedKitchenItems[aId] = kitchenB;
    if (kitchenA != null && kitchenA.isNotEmpty) _tablePrintedKitchenItems[bId] = kitchenA;

    // 5. Swap token numbers
    final tokenA = _tableTokenNumbers.remove(aId);
    final tokenB = _tableTokenNumbers.remove(bId);
    if (tokenB != null) _tableTokenNumbers[aId] = tokenB;
    if (tokenA != null) _tableTokenNumbers[bId] = tokenA;

    // 6. Swap SQLite draft records
    _draftRepository.swapDrafts(aId, bId).catchError((_) {});

    // 7. Update currently selected table in POS view
    if (_selectedTable?.id == aId) {
      _selectedTable = tableB;
      _cart.clear();
      if (_tableCarts.containsKey(bId)) {
        _cart.addAll(_tableCarts[bId]!);
        _selectedWaiter = _tableWaiters[bId];
      } else {
        _selectedWaiter = null;
      }
    } else if (_selectedTable?.id == bId) {
      _selectedTable = tableA;
      _cart.clear();
      if (_tableCarts.containsKey(aId)) {
        _cart.addAll(_tableCarts[aId]!);
        _selectedWaiter = _tableWaiters[aId];
      } else {
        _selectedWaiter = null;
      }
    }

    notifyListeners();
  }

  void selectWaiter(WaiterModel? waiter) {
    _selectedWaiter = waiter;
    if (_selectedTable != null && _selectedTable!.id != null) {
      _tableWaiters[_selectedTable!.id!] = waiter;
      _syncAndPersistActiveTableCart();
    }
    notifyListeners();
  }

  void setCustomerInfo(String name, String phone) {
    _customerName = name;
    _customerPhone = phone;
    notifyListeners();
  }

  void setDiscount(double discount) {
    _discountAmount = discount;
    notifyListeners();
  }

  void setPaymentMethod(String method) {
    _paymentMethod = method;
    notifyListeners();
  }

  double get subtotal => _cart.fold(0.0, (sum, item) => sum + item.totalPrice);

  double calculateTax(double taxPercent) {
    final netSubtotal = (subtotal - _discountAmount).clamp(0.0, double.infinity);
    return netSubtotal * (taxPercent / 100.0);
  }

  double calculateGrandTotal(double taxPercent) {
    final netSubtotal = (subtotal - _discountAmount).clamp(0.0, double.infinity);
    return netSubtotal + calculateTax(taxPercent);
  }

  /// Complete Checkout Process
  Future<SaleModel?> checkout({
    required String cashierName,
    required double taxPercent,
    required double milkCupsPerKg,
    required Function(String error) onError,
    required Function(List<String> warnings) onWarnings,
    String status = 'CLEARED',
    int? sessionId,
  }) async {
    if (_cart.isEmpty) {
      onError('Cart is empty. Please add items to checkout.');
      return null;
    }

    _isProcessing = true;
    notifyListeners();

    try {
      // 1. Validate Stock Sufficiency
      final stockResult = await _stockService.validateStockForSale(_cart, milkCupsPerKg);
      if (!stockResult.success) {
        _isProcessing = false;
        notifyListeners();
        onError(stockResult.errorMessage ?? 'Stock validation failed.');
        return null;
      }

      if (stockResult.warningMessages.isNotEmpty) {
        onWarnings(stockResult.warningMessages);
      }

      // 2. Calculate final financial figures
      final sub = subtotal;
      final tax = calculateTax(taxPercent);
      final grand = calculateGrandTotal(taxPercent);

      // 3. Process Atomic DB Checkout
      final completedSale = await _saleRepository.processCheckout(
        cartItems: List.from(_cart),
        cashierName: cashierName,
        waiterId: _selectedWaiter?.id,
        waiterName: _selectedWaiter?.name,
        tableId: _selectedTable?.id,
        tableName: _selectedTable?.tableName,
        customerName: _customerName.isNotEmpty ? _customerName : null,
        customerPhone: _customerPhone.isNotEmpty ? _customerPhone : null,
        subtotal: sub,
        discount: _discountAmount,
        tax: tax,
        grandTotal: grand,
        paymentMethod: _paymentMethod,
        milkCupsPerKg: milkCupsPerKg,
        status: status,
        sessionId: sessionId,
      );

      // Clear Cart after successful checkout
      clearCart(isCheckout: true);
      _isProcessing = false;
      notifyListeners();

      return completedSale;
    } catch (e) {
      _isProcessing = false;
      notifyListeners();
      onError('Error processing transaction: ${e.toString()}');
      return null;
    }
  }

  /// Save and update currently edited invoice with modified items and amounts
  Future<SaleModel?> saveEditedInvoice({
    required String cashierName,
    required double taxPercent,
    required double milkCupsPerKg,
    required Function(String error) onError,
    required Function(List<String> warnings) onWarnings,
    String? status,
  }) async {
    if (_editingSale == null) {
      onError('No invoice is currently loaded for editing.');
      return null;
    }

    if (_cart.isEmpty) {
      onError('Invoice must contain at least 1 item. Remove the invoice using Delete if needed.');
      return null;
    }

    _isProcessing = true;
    notifyListeners();

    try {
      final sub = subtotal;
      final tax = calculateTax(taxPercent);
      final grand = calculateGrandTotal(taxPercent);

      final updatedSale = await _saleRepository.updateSaleWithItems(
        saleId: _editingSale!.id!,
        invoiceNumber: _editingSale!.invoiceNumber,
        cartItems: List.from(_cart),
        cashierName: cashierName,
        waiterId: _selectedWaiter?.id,
        waiterName: _selectedWaiter?.name,
        tableId: _selectedTable?.id,
        tableName: _selectedTable?.tableName,
        customerName: _customerName.isNotEmpty ? _customerName : null,
        customerPhone: _customerPhone.isNotEmpty ? _customerPhone : null,
        subtotal: sub,
        discount: _discountAmount,
        tax: tax,
        grandTotal: grand,
        paymentMethod: _paymentMethod,
        milkCupsPerKg: milkCupsPerKg,
        status: status,
      );

      _editingSale = null;
      clearCart(isCheckout: true);
      _isProcessing = false;
      notifyListeners();

      return updatedSale;
    } catch (e) {
      _isProcessing = false;
      notifyListeners();
      onError('Error updating invoice: ${e.toString()}');
      return null;
    }
  }
}
