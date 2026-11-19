import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/table_draft_model.dart';

class TableDraftRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<void> saveDraft(TableDraftModel draft) async {
    try {
      final db = await _dbHelper.database;
      await db.insert(
        'table_draft_orders',
        draft.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  Future<void> deleteDraft(int tableId) async {
    try {
      final db = await _dbHelper.database;
      await db.delete(
        'table_draft_orders',
        where: 'table_id = ?',
        whereArgs: [tableId],
      );
    } catch (_) {}
  }

  Future<void> clearAllDrafts() async {
    try {
      final db = await _dbHelper.database;
      await db.delete('table_draft_orders');
    } catch (_) {}
  }

  Future<List<TableDraftModel>> getAllDrafts() async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query('table_draft_orders', orderBy: 'updated_at DESC');
      return maps.map((m) => TableDraftModel.fromMap(m)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<TableDraftModel?> getDraft(int tableId) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'table_draft_orders',
        where: 'table_id = ?',
        whereArgs: [tableId],
      );
      if (maps.isNotEmpty) {
        return TableDraftModel.fromMap(maps.first);
      }
    } catch (_) {}
    return null;
  }

  Future<void> swapDrafts(int tableIdA, int tableIdB) async {
    try {
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        final draftA = await txn.query('table_draft_orders', where: 'table_id = ?', whereArgs: [tableIdA]);
        final draftB = await txn.query('table_draft_orders', where: 'table_id = ?', whereArgs: [tableIdB]);

        await txn.delete('table_draft_orders', where: 'table_id = ?', whereArgs: [tableIdA]);
        await txn.delete('table_draft_orders', where: 'table_id = ?', whereArgs: [tableIdB]);

        if (draftA.isNotEmpty) {
          final mapA = Map<String, dynamic>.from(draftA.first);
          mapA['table_id'] = tableIdB;
          await txn.insert('table_draft_orders', mapA, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        if (draftB.isNotEmpty) {
          final mapB = Map<String, dynamic>.from(draftB.first);
          mapB['table_id'] = tableIdA;
          await txn.insert('table_draft_orders', mapB, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });
    } catch (_) {}
  }
}
