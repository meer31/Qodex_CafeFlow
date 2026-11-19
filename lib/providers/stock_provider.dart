import 'package:flutter/material.dart';
import '../models/stock_item_model.dart';
import '../models/stock_transaction_model.dart';
import '../repositories/stock_repository.dart';

class StockProvider with ChangeNotifier {
  final StockRepository _repository = StockRepository();
  List<StockItemModel> _stockList = [];
  List<StockTransactionModel> _transactions = [];
  bool _isLoading = false;

  List<StockItemModel> get stockList => _stockList;
  List<StockTransactionModel> get transactions => _transactions;
  bool get isLoading => _isLoading;

  List<StockItemModel> get lowStockItems =>
      _stockList.where((item) => item.isLowStock).toList();

  StockItemModel? findStockByProductName(String productName) {
    final clean = productName.trim().toLowerCase();
    for (var s in _stockList) {
      if (s.name.trim().toLowerCase() == clean) return s;
    }
    for (var s in _stockList) {
      final sName = s.name.trim().toLowerCase();
      if (sName.contains(clean) || clean.contains(sName)) return s;
    }
    return null;
  }

  StockProvider() {
    loadStockData();
  }

  Future<void> loadStockData() async {
    _isLoading = true;
    notifyListeners();

    _stockList = await _repository.getAllStock();
    _transactions = await _repository.getStockTransactions(limit: 50);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addStockItem(StockItemModel item) async {
    await _repository.insertStock(item);
    await loadStockData();
  }

  Future<void> addQuantity({
    required int stockId,
    required String stockName,
    required double qty,
    required String unit,
    String? notes,
  }) async {
    await _repository.addStockQuantity(
      stockId: stockId,
      stockName: stockName,
      addedQty: qty,
      unit: unit,
      notes: notes,
    );
    await loadStockData();
  }

  Future<void> updateStockItem(StockItemModel item) async {
    await _repository.updateStock(item);
    await loadStockData();
  }

  Future<void> deleteStockItem(int id) async {
    await _repository.deleteStock(id);
    await loadStockData();
  }
}
