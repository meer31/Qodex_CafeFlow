import 'package:flutter/material.dart';
import '../models/expense_model.dart';
import '../repositories/expense_repository.dart';

class ExpenseProvider with ChangeNotifier {
  final ExpenseRepository _repository = ExpenseRepository();
  List<ExpenseModel> _expenses = [];
  bool _isLoading = false;

  List<ExpenseModel> get expenses => _expenses;
  bool get isLoading => _isLoading;

  ExpenseProvider() {
    loadExpenses();
  }

  Future<void> loadExpenses() async {
    _isLoading = true;
    notifyListeners();

    _expenses = await _repository.getAllExpenses();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addExpense(ExpenseModel expense) async {
    await _repository.insertExpense(expense);
    await loadExpenses();
  }

  Future<void> deleteExpense(int id) async {
    await _repository.deleteExpense(id);
    await loadExpenses();
  }

  double get todayExpenseTotal {
    final now = DateTime.now();
    final todayStr = DateTime(now.year, now.month, now.day).toIso8601String().split('T').first;
    return _expenses
        .where((e) => e.dateTime.startsWith(todayStr))
        .fold(0.0, (sum, item) => sum + item.amount);
  }
}
