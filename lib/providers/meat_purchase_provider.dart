import 'package:flutter/material.dart';
import '../models/meat_purchase_model.dart';
import '../repositories/meat_purchase_repository.dart';

class MeatPurchaseProvider with ChangeNotifier {
  final MeatPurchaseRepository _repository = MeatPurchaseRepository();

  // Current invoice being built
  final List<MeatPurchaseItemModel> _currentItems = [];
  String _selectedMeatType = 'Chicken';
  double _quantityKg = 0.0;
  double _ratePerKg = 0.0;

  // History
  List<MeatPurchaseModel> _purchases = [];
  bool _isLoading = false;
  bool _isSaving = false;

  // Getters
  List<MeatPurchaseItemModel> get currentItems => _currentItems;
  String get selectedMeatType => _selectedMeatType;
  double get quantityKg => _quantityKg;
  double get ratePerKg => _ratePerKg;
  List<MeatPurchaseModel> get purchases => _purchases;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;

  double get currentGrandTotal =>
      _currentItems.fold(0.0, (sum, item) => sum + item.totalAmount);

  MeatPurchaseProvider() {
    loadPurchases();
  }

  void setMeatType(String type) {
    _selectedMeatType = type;
    notifyListeners();
  }

  void setQuantityKg(double qty) {
    _quantityKg = qty;
    notifyListeners();
  }

  void setRatePerKg(double rate) {
    _ratePerKg = rate;
    notifyListeners();
  }

  /// Add an item to the current invoice being built
  void addItemToInvoice() {
    if (_quantityKg <= 0 || _ratePerKg <= 0) return;

    _currentItems.add(MeatPurchaseItemModel(
      meatType: _selectedMeatType,
      quantityKg: _quantityKg,
      ratePerKg: _ratePerKg,
      totalAmount: _quantityKg * _ratePerKg,
    ));

    // Reset input fields
    _quantityKg = 0.0;
    _ratePerKg = 0.0;
    notifyListeners();
  }

  /// Remove an item from the current invoice
  void removeItemFromInvoice(int index) {
    _currentItems.removeAt(index);
    notifyListeners();
  }

  /// Clear all items from the current invoice
  void clearCurrentInvoice() {
    _currentItems.clear();
    _quantityKg = 0.0;
    _ratePerKg = 0.0;
    _selectedMeatType = 'Chicken';
    notifyListeners();
  }

  /// Save the current invoice to the database
  Future<MeatPurchaseModel?> saveInvoice({
    required Function(String error) onError,
  }) async {
    if (_currentItems.isEmpty) {
      onError('No items added to the invoice.');
      return null;
    }

    _isSaving = true;
    notifyListeners();

    try {
      final purchase = await _repository.saveMeatPurchase(
        items: List.from(_currentItems),
        grandTotal: currentGrandTotal,
      );

      clearCurrentInvoice();
      await loadPurchases();

      _isSaving = false;
      notifyListeners();
      return purchase;
    } catch (e) {
      _isSaving = false;
      notifyListeners();
      onError('Error saving invoice: ${e.toString()}');
      return null;
    }
  }

  /// Load purchase history
  Future<void> loadPurchases() async {
    _isLoading = true;
    notifyListeners();

    _purchases = await _repository.getAllMeatPurchases();

    _isLoading = false;
    notifyListeners();
  }

  /// Delete a purchase
  Future<void> deletePurchase(int id) async {
    await _repository.deleteMeatPurchase(id);
    await loadPurchases();
  }
}
