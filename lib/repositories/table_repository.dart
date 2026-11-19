import '../database/database_helper.dart';
import '../models/cafe_table_model.dart';

class TableRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<TableSectionModel>> getAllSections() async {
    final db = await _dbHelper.database;
    final maps = await db.query('table_sections', orderBy: 'sort_order ASC, name ASC');
    return maps.map((m) => TableSectionModel.fromMap(m)).toList();
  }

  Future<List<CafeTableModel>> getAllTables() async {
    final db = await _dbHelper.database;
    const query = '''
      SELECT t.*, s.name as section_name
      FROM tables t
      LEFT JOIN table_sections s ON t.section_id = s.id
      ORDER BY s.sort_order ASC, t.table_name ASC
    ''';
    final maps = await db.rawQuery(query);
    final tables = maps.map((m) => CafeTableModel.fromMap(m)).toList();

    try {
      final draftRows = await db.query('table_draft_orders', columns: ['table_id']);
      final draftTableIds = draftRows.map((r) => r['table_id'] as int).toSet();
      return tables.map((t) {
        if (draftTableIds.contains(t.id) && t.status.toUpperCase() == 'AVAILABLE') {
          return t.copyWith(status: 'Occupied');
        }
        return t;
      }).toList();
    } catch (_) {
      return tables;
    }
  }

  Future<int> insertSection(TableSectionModel section) async {
    final db = await _dbHelper.database;
    return await db.insert('table_sections', section.toMap());
  }

  Future<int> insertTable(CafeTableModel table) async {
    final db = await _dbHelper.database;
    return await db.insert('tables', table.toMap());
  }

  Future<int> updateTable(CafeTableModel table) async {
    final db = await _dbHelper.database;
    return await db.update(
      'tables',
      {
        'section_id': table.sectionId,
        'table_name': table.tableName,
        'capacity': table.capacity,
        'status': table.status,
        'active_invoice_number': table.activeInvoiceNumber,
      },
      where: 'id = ?',
      whereArgs: [table.id],
    );
  }

  Future<void> updateTableStatus({
    required int tableId,
    required String status,
    String? invoiceNumber,
  }) async {
    final db = await _dbHelper.database;
    await db.update(
      'tables',
      {
        'status': status,
        'active_invoice_number': invoiceNumber,
      },
      where: 'id = ?',
      whereArgs: [tableId],
    );
  }

  Future<void> swapTables(CafeTableModel tableA, CafeTableModel tableB) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      const tempId = -999999;
      const tempName = '__TEMP_SWAP_TABLE__';

      // 1. Move remaining sales for Table A to temporary ID
      await txn.update(
        'sales',
        {'table_id': tempId, 'table_name': tempName},
        where: "(UPPER(status) = 'REMAINING' OR UPPER(status) = 'PENDING') AND (table_id = ? OR (table_id IS NULL AND table_name = ?))",
        whereArgs: [tableA.id, tableA.tableName],
      );

      // 2. Move remaining sales for Table B to Table A
      await txn.update(
        'sales',
        {'table_id': tableA.id, 'table_name': tableA.tableName},
        where: "(UPPER(status) = 'REMAINING' OR UPPER(status) = 'PENDING') AND (table_id = ? OR (table_id IS NULL AND table_name = ?))",
        whereArgs: [tableB.id, tableB.tableName],
      );

      // 3. Move remaining sales from temporary ID to Table B
      await txn.update(
        'sales',
        {'table_id': tableB.id, 'table_name': tableB.tableName},
        where: "table_id = ?",
        whereArgs: [tempId],
      );

      // 4. Swap table records' status and active_invoice_number
      final aRows = await txn.query('tables', where: 'id = ?', whereArgs: [tableA.id]);
      final bRows = await txn.query('tables', where: 'id = ?', whereArgs: [tableB.id]);

      if (aRows.isNotEmpty && bRows.isNotEmpty) {
        final statusA = aRows.first['status'] as String? ?? 'Available';
        final invA = aRows.first['active_invoice_number'] as String?;
        final statusB = bRows.first['status'] as String? ?? 'Available';
        final invB = bRows.first['active_invoice_number'] as String?;

        await txn.update(
          'tables',
          {'status': statusB, 'active_invoice_number': invB},
          where: 'id = ?',
          whereArgs: [tableA.id],
        );

        await txn.update(
          'tables',
          {'status': statusA, 'active_invoice_number': invA},
          where: 'id = ?',
          whereArgs: [tableB.id],
        );
      }
    });
  }

  Future<int> deleteTable(int id) async {
    final db = await _dbHelper.database;
    return await db.delete('tables', where: 'id = ?', whereArgs: [id]);
  }
}
