import '../database/database_helper.dart';
import '../models/expense_model.dart';

class ExpenseRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<ExpenseModel>> getAllExpenses() async {
    final db = await _dbHelper.database;
    final maps = await db.query('expenses', orderBy: 'id DESC');
    return maps.map((m) => ExpenseModel.fromMap(m)).toList();
  }

  Future<int> insertExpense(ExpenseModel expense) async {
    final db = await _dbHelper.database;
    int? effectiveSessionId = expense.sessionId;
    if (effectiveSessionId == null) {
      final activeSessionMaps = await db.query(
        'sale_sessions',
        where: 'status = ?',
        whereArgs: ['ACTIVE'],
        orderBy: 'id DESC',
        limit: 1,
      );
      if (activeSessionMaps.isNotEmpty) {
        effectiveSessionId = activeSessionMaps.first['id'] as int?;
      }
    }
    final map = expense.toMap();
    map['session_id'] = effectiveSessionId;
    return await db.insert('expenses', map);
  }

  Future<int> deleteExpense(int id) async {
    final db = await _dbHelper.database;
    return await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ExpenseModel>> getExpensesByDateRange(DateTime start, DateTime end) async {
    final db = await _dbHelper.database;
    final startStr = start.toIso8601String();
    final endStr = end.toIso8601String();
    final maps = await db.query(
      'expenses',
      where: 'date_time >= ? AND date_time <= ?',
      whereArgs: [startStr, endStr],
      orderBy: 'id DESC',
    );
    return maps.map((m) => ExpenseModel.fromMap(m)).toList();
  }
}
