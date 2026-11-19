import '../database/database_helper.dart';
import '../models/stock_item_model.dart';
import '../models/stock_transaction_model.dart';

class StockRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<StockItemModel>> getAllStock() async {
    final db = await _dbHelper.database;
    final maps = await db.query('stock', orderBy: 'name ASC');
    return maps.map((map) => StockItemModel.fromMap(map)).toList();
  }

  Future<List<StockItemModel>> getLowStockItems() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'stock',
      where: 'quantity <= min_threshold',
      orderBy: 'quantity ASC',
    );
    return maps.map((map) => StockItemModel.fromMap(map)).toList();
  }

  Future<int> insertStock(StockItemModel stock) async {
    final db = await _dbHelper.database;
    final id = await db.insert('stock', stock.toMap());

    // Record initial stock transaction
    if (stock.quantity > 0) {
      await db.insert('stock_transactions', {
        'stock_id': id,
        'stock_name': stock.name,
        'type': 'IN',
        'quantity': stock.quantity,
        'unit': stock.unit,
        'date_time': DateTime.now().toIso8601String(),
        'notes': 'Initial Stock Creation',
      });
    }

    return id;
  }

  Future<void> addStockQuantity({
    required int stockId,
    required String stockName,
    required double addedQty,
    required String unit,
    String? notes,
  }) async {
    final db = await _dbHelper.database;
    final nowStr = DateTime.now().toIso8601String();

    await db.rawUpdate('''
      UPDATE stock
      SET quantity = quantity + ?, last_updated = ?
      WHERE id = ?
    ''', [addedQty, nowStr, stockId]);

    await db.insert('stock_transactions', {
      'stock_id': stockId,
      'stock_name': stockName,
      'type': 'IN',
      'quantity': addedQty,
      'unit': unit,
      'date_time': nowStr,
      'notes': notes ?? 'Stock Addition',
    });
  }

  Future<int> updateStock(StockItemModel stock) async {
    final db = await _dbHelper.database;
    return await db.update(
      'stock',
      stock.toMap(),
      where: 'id = ?',
      whereArgs: [stock.id],
    );
  }

  Future<int> deleteStock(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'stock',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<StockTransactionModel>> getStockTransactions({int limit = 50}) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'stock_transactions',
      orderBy: 'id DESC',
      limit: limit,
    );
    return maps.map((map) => StockTransactionModel.fromMap(map)).toList();
  }
}
