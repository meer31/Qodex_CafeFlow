import 'package:flutter/material.dart';
import '../models/waiter_model.dart';
import '../repositories/waiter_repository.dart';

class WaiterProvider with ChangeNotifier {
  final WaiterRepository _repository = WaiterRepository();
  List<WaiterModel> _waiters = [];
  bool _isLoading = false;

  List<WaiterModel> get waiters => _waiters;
  bool get isLoading => _isLoading;

  WaiterProvider() {
    loadWaiters();
  }

  Future<void> loadWaiters() async {
    _isLoading = true;
    notifyListeners();

    _waiters = await _repository.getAllWaiters();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addWaiter(WaiterModel waiter) async {
    await _repository.insertWaiter(waiter);
    await loadWaiters();
  }

  Future<void> updateWaiter(WaiterModel waiter) async {
    await _repository.updateWaiter(waiter);
    await loadWaiters();
  }

  Future<void> deleteWaiter(int id) async {
    await _repository.deleteWaiter(id);
    await loadWaiters();
  }
}
