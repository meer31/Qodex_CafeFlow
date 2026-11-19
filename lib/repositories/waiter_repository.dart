import '../database/database_helper.dart';
import '../models/waiter_model.dart';

class WaiterRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<WaiterModel>> getAllWaiters() async {
    final db = await _dbHelper.database;
    final maps = await db.query('waiters', orderBy: 'name ASC');
    return maps.map((m) => WaiterModel.fromMap(m)).toList();
  }

  Future<int> insertWaiter(WaiterModel waiter) async {
    final db = await _dbHelper.database;
    return await db.insert('waiters', waiter.toMap());
  }

  Future<int> updateWaiter(WaiterModel waiter) async {
    final db = await _dbHelper.database;
    return await db.update(
      'waiters',
      waiter.toMap(),
      where: 'id = ?',
      whereArgs: [waiter.id],
    );
  }

  Future<int> deleteWaiter(int id) async {
    final db = await _dbHelper.database;
    return await db.delete('waiters', where: 'id = ?', whereArgs: [id]);
  }
}
