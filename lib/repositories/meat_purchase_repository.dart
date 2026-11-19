import '../database/database_helper.dart';
import '../models/meat_purchase_model.dart';

class MeatPurchaseRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<String> generateNextMeatInvoiceNumber() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> seqMaps = await db.query('meat_invoice_sequence');
    int lastSeq = 1000;
    if (seqMaps.isNotEmpty) {
      lastSeq = seqMaps.first['last_seq'] as int;
    }
    final nextSeq = lastSeq + 1;
    final now = DateTime.now();
    return 'MEAT-${now.year}-${nextSeq.toString().padLeft(4, '0')}';
  }

  Future<MeatPurchaseModel> saveMeatPurchase({
    required List<MeatPurchaseItemModel> items,
    required double grandTotal,
  }) async {
    final db = await _dbHelper.database;
    final invoiceNum = await generateNextMeatInvoiceNumber();
    final nowStr = DateTime.now().toIso8601String();

    late int purchaseId;

    await db.transaction((txn) async {
      // Increment meat sequence counter
      await txn.rawUpdate(
        'UPDATE meat_invoice_sequence SET last_seq = last_seq + 1',
      );

      // Insert meat purchase header
      purchaseId = await txn.insert('meat_purchases', {
        'invoice_number': invoiceNum,
        'date_time': nowStr,
        'grand_total': grandTotal,
      });

      // Insert meat purchase items
      for (var item in items) {
        await txn.insert('meat_purchase_items', {
          'purchase_id': purchaseId,
          'meat_type': item.meatType,
          'quantity_kg': item.quantityKg,
          'rate_per_kg': item.ratePerKg,
          'total_amount': item.totalAmount,
        });
      }
    });

    return MeatPurchaseModel(
      id: purchaseId,
      invoiceNumber: invoiceNum,
      dateTime: nowStr,
      grandTotal: grandTotal,
      items: items,
    );
  }

  Future<List<MeatPurchaseModel>> getAllMeatPurchases({int limit = 100}) async {
    final db = await _dbHelper.database;
    final purchaseMaps = await db.query('meat_purchases', orderBy: 'id DESC', limit: limit);
    final List<MeatPurchaseModel> purchases = [];

    for (var pm in purchaseMaps) {
      final purchaseId = pm['id'] as int;
      final itemMaps = await db.query(
        'meat_purchase_items',
        where: 'purchase_id = ?',
        whereArgs: [purchaseId],
      );
      final items = itemMaps.map((im) => MeatPurchaseItemModel.fromMap(im)).toList();
      purchases.add(MeatPurchaseModel.fromMap(pm, items: items));
    }

    return purchases;
  }

  Future<List<MeatPurchaseModel>> getMeatPurchasesByDateRange(DateTime start, DateTime end) async {
    final db = await _dbHelper.database;
    final startStr = start.toIso8601String();
    final endStr = end.toIso8601String();

    final purchaseMaps = await db.query(
      'meat_purchases',
      where: 'date_time >= ? AND date_time <= ?',
      whereArgs: [startStr, endStr],
      orderBy: 'id DESC',
    );

    final List<MeatPurchaseModel> purchases = [];
    for (var pm in purchaseMaps) {
      final purchaseId = pm['id'] as int;
      final itemMaps = await db.query(
        'meat_purchase_items',
        where: 'purchase_id = ?',
        whereArgs: [purchaseId],
      );
      final items = itemMaps.map((im) => MeatPurchaseItemModel.fromMap(im)).toList();
      purchases.add(MeatPurchaseModel.fromMap(pm, items: items));
    }

    return purchases;
  }

  Future<int> deleteMeatPurchase(int id) async {
    final db = await _dbHelper.database;
    // Items are cascade-deleted via FK
    return await db.delete('meat_purchases', where: 'id = ?', whereArgs: [id]);
  }
}
