import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/sale_model.dart';
import '../services/stock_deduction_service.dart';

class SaleRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final StockDeductionService _stockDeductionService = StockDeductionService();

  /// Helper to check if a table has any remaining/pending orders left.
  /// If no remaining orders remain, sets table status to 'Available' and clears active_invoice_number.
  /// If other remaining orders still exist, keeps 'Occupied' and points to the next active remaining invoice.
  Future<void> _checkAndReleaseTableIfNoRemainingOrders(
    DatabaseExecutor db,
    int? tableId, {
    String? tableName,
    int? excludingSaleId,
  }) async {
    if (tableId == null && (tableName == null || tableName.isEmpty)) return;

    final List<dynamic> whereArgs = [];
    String whereClause = "(UPPER(status) = 'REMAINING' OR UPPER(status) = 'PENDING')";
    if (excludingSaleId != null) {
      whereClause += " AND id != ?";
      whereArgs.add(excludingSaleId);
    }
    if (tableId != null) {
      whereClause += " AND (table_id = ? OR (table_id IS NULL AND table_name = ?))";
      whereArgs.add(tableId);
      whereArgs.add(tableName ?? '');
    } else {
      whereClause += " AND table_name = ?";
      whereArgs.add(tableName!);
    }

    final remaining = await db.query(
      'sales',
      columns: ['id', 'invoice_number'],
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'id DESC',
    );

    if (remaining.isEmpty) {
      // Table has no remaining or pending orders -> Release to Available!
      if (tableId != null) {
        await db.update(
          'tables',
          {'status': 'Available', 'active_invoice_number': null},
          where: 'id = ?',
          whereArgs: [tableId],
        );
      } else if (tableName != null && tableName.isNotEmpty) {
        await db.update(
          'tables',
          {'status': 'Available', 'active_invoice_number': null},
          where: 'table_name = ?',
          whereArgs: [tableName],
        );
      }
    } else {
      // Table still has another remaining order -> Point to the remaining invoice
      final nextActiveInv = remaining.first['invoice_number'] as String?;
      if (tableId != null) {
        await db.update(
          'tables',
          {'status': 'Occupied', 'active_invoice_number': nextActiveInv},
          where: 'id = ?',
          whereArgs: [tableId],
        );
      } else if (tableName != null && tableName.isNotEmpty) {
        await db.update(
          'tables',
          {'status': 'Occupied', 'active_invoice_number': nextActiveInv},
          where: 'table_name = ?',
          whereArgs: [tableName],
        );
      }
    }
  }

  Future<void> migrateLegacyInvoiceNumbers() async {
    final db = await _dbHelper.database;
    final legacySales = await db.rawQuery(
      "SELECT id, invoice_number FROM sales WHERE invoice_number LIKE 'INV-%' ORDER BY id ASC",
    );
    if (legacySales.isEmpty) return;

    final numSales = await db.rawQuery(
      "SELECT invoice_number FROM sales WHERE invoice_number NOT LIKE 'INV-%'",
    );
    int current = 0;
    for (var r in numSales) {
      final p = int.tryParse(r['invoice_number']?.toString() ?? '');
      if (p != null && p > current) current = p;
    }

    await db.transaction((txn) async {
      for (var sale in legacySales) {
        current++;
        final id = sale['id'] as int;
        final oldInv = sale['invoice_number'] as String;
        final newInv = current.toString();

        await txn.update('sales', {'invoice_number': newInv}, where: 'id = ?', whereArgs: [id]);
        await txn.update('stock_transactions', {'invoice_number': newInv}, where: 'invoice_number = ?', whereArgs: [oldInv]);
        await txn.update('tables', {'active_invoice_number': newInv}, where: 'active_invoice_number = ?', whereArgs: [oldInv]);
      }
      await txn.rawUpdate('UPDATE invoice_sequence SET last_seq = ?', [current]);
    });
  }

  Future<String> generateNextInvoiceNumber({int? sessionId}) async {
    final db = await _dbHelper.database;
    await migrateLegacyInvoiceNumbers();

    // 1. Determine target session (either explicitly passed or current ACTIVE session)
    int? targetSessionId = sessionId;
    if (targetSessionId == null) {
      final activeSessionMaps = await db.query(
        'sale_sessions',
        where: 'status = ?',
        whereArgs: ['ACTIVE'],
        orderBy: 'id DESC',
        limit: 1,
      );
      if (activeSessionMaps.isNotEmpty) {
        targetSessionId = activeSessionMaps.first['id'] as int?;
      }
    }

    if (targetSessionId != null) {
      final sessionRows = await db.query(
        'sale_sessions',
        where: 'id = ?',
        whereArgs: [targetSessionId],
        limit: 1,
      );

      List<Map<String, dynamic>> sales;
      if (sessionRows.isNotEmpty) {
        final startTime = sessionRows.first['start_time'] as String;
        final endTime = sessionRows.first['end_time'] as String?;
        sales = await db.rawQuery(
          '''
          SELECT invoice_number FROM sales 
          WHERE session_id = ? 
             OR (session_id IS NULL AND date_time >= ? AND (? IS NULL OR date_time <= ?))
          ''',
          [targetSessionId, startTime, endTime, endTime],
        );
      } else {
        sales = await db.rawQuery(
          'SELECT invoice_number FROM sales WHERE session_id = ?',
          [targetSessionId],
        );
      }

      int maxSeq = 0;
      for (var s in sales) {
        final invStr = s['invoice_number']?.toString() ?? '';
        final parsed = int.tryParse(invStr);
        if (parsed != null && parsed > maxSeq) {
          maxSeq = parsed;
        }
      }
      // Shift starts numbering from 1!
      return (maxSeq + 1).toString();
    } else {
      // If no shift session is active, count today's sales
      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final sales = await db.rawQuery(
        'SELECT invoice_number FROM sales WHERE session_id IS NULL AND date_time >= ?',
        ['$todayStr 00:00:00'],
      );
      int maxSeq = 0;
      for (var s in sales) {
        final invStr = s['invoice_number']?.toString() ?? '';
        final parsed = int.tryParse(invStr);
        if (parsed != null && parsed > maxSeq) {
          maxSeq = parsed;
        }
      }
      return (maxSeq + 1).toString();
    }
  }

  Future<SaleModel> processCheckout({
    required List<SaleItemModel> cartItems,
    required String cashierName,
    int? waiterId,
    String? waiterName,
    int? tableId,
    String? tableName,
    String? customerName,
    String? customerPhone,
    required double subtotal,
    required double discount,
    required double tax,
    required double grandTotal,
    required String paymentMethod,
    required double milkCupsPerKg,
    String status = 'CLEARED',
    int? sessionId,
  }) async {
    final db = await _dbHelper.database;
    // Auto-detect active session if not explicitly provided
    int? effectiveSessionId = sessionId;
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

    final invoiceNum = await generateNextInvoiceNumber(sessionId: effectiveSessionId);
    final nowStr = DateTime.now().toIso8601String();
    final effectiveStatus = status.trim().toUpperCase();
    final bool isClearedStatus = effectiveStatus == 'CLEARED' ||
        effectiveStatus == 'COMPLETED' ||
        effectiveStatus == 'PAID';

    // Calculate total cost from recipe/product
    double totalCost = 0.0;
    for (var item in cartItems) {
      totalCost += (item.unitCost * item.quantity);
    }

    late int saleId;

    await db.transaction((txn) async {
      // 1. Increment sequence counter
      await txn.rawUpdate(
        'UPDATE invoice_sequence SET last_seq = ?',
        [int.tryParse(invoiceNum) ?? 1],
      );

      // 2. Insert Sale Header
      saleId = await txn.insert('sales', {
        'session_id': effectiveSessionId,
        'invoice_number': invoiceNum,
        'date_time': nowStr,
        'cashier_name': cashierName,
        'waiter_id': waiterId,
        'waiter_name': waiterName,
        'table_id': tableId,
        'table_name': tableName,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'subtotal': subtotal,
        'discount': discount,
        'tax': tax,
        'grand_total': grandTotal,
        'total_cost': totalCost,
        'payment_method': paymentMethod,
        'status': effectiveStatus,
      });

      // 3. Insert Sale Line Items
      for (var item in cartItems) {
        await txn.insert('sale_items', {
          'sale_id': saleId,
          'product_id': item.productId,
          'product_name': item.productName,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
          'unit_cost': item.unitCost,
          'total_price': item.totalPrice,
          'notes': item.notes,
        });
      }

      // 4. Perform Automatic Stock Deduction via Recipe Engine
      await _stockDeductionService.deductStockForSale(
        txn: txn,
        cartItems: cartItems,
        invoiceNumber: invoiceNum,
        milkCupsPerKg: milkCupsPerKg,
      );

      // 5. Update Waiter performance stats (only if bill is cleared/paid immediately)
      if (waiterId != null && isClearedStatus) {
        await txn.rawUpdate('''
          UPDATE waiters
          SET total_sales = total_sales + ?, orders_count = orders_count + 1
          WHERE id = ?
        ''', [grandTotal, waiterId]);
      }

      // 6. Handle Table occupation
      if (tableId != null || (tableName != null && tableName.isNotEmpty)) {
        if (isClearedStatus) {
          // Bill is paid/cleared immediately: release table if no other remaining orders
          await _checkAndReleaseTableIfNoRemainingOrders(txn, tableId, tableName: tableName);
        } else {
          // Bill is remaining/pending payment: keep table occupied and link active invoice
          if (tableId != null) {
            await txn.update(
              'tables',
              {'status': 'Occupied', 'active_invoice_number': invoiceNum},
              where: 'id = ?',
              whereArgs: [tableId],
            );
          } else if (tableName != null) {
            await txn.update(
              'tables',
              {'status': 'Occupied', 'active_invoice_number': invoiceNum},
              where: 'table_name = ?',
              whereArgs: [tableName],
            );
          }
        }
      }
    });

    final createdSale = SaleModel(
      id: saleId,
      sessionId: effectiveSessionId,
      invoiceNumber: invoiceNum,
      dateTime: nowStr,
      cashierName: cashierName,
      waiterId: waiterId,
      waiterName: waiterName,
      tableId: tableId,
      tableName: tableName,
      customerName: customerName,
      customerPhone: customerPhone,
      subtotal: subtotal,
      discount: discount,
      tax: tax,
      grandTotal: grandTotal,
      totalCost: totalCost,
      paymentMethod: paymentMethod,
      status: effectiveStatus,
      items: cartItems,
    );

    return createdSale;
  }

  Future<List<SaleModel>> getAllSales({int limit = 100}) async {
    final db = await _dbHelper.database;
    await migrateLegacyInvoiceNumbers();

    final salesMaps = await db.query('sales', orderBy: 'id DESC', limit: limit);
    final List<SaleModel> sales = [];

    for (var sm in salesMaps) {
      final saleId = sm['id'] as int;
      final itemMaps = await db.query(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [saleId],
      );
      final items = itemMaps.map((im) => SaleItemModel.fromMap(im)).toList();
      sales.add(SaleModel.fromMap(sm, items: items));
    }

    return sales;
  }

  Future<List<SaleModel>> getRemainingSales() async {
    final db = await _dbHelper.database;
    await migrateLegacyInvoiceNumbers();

    final salesMaps = await db.query(
      'sales',
      where: "UPPER(status) = 'REMAINING' OR UPPER(status) = 'PENDING'",
      orderBy: 'id DESC',
    );
    final List<SaleModel> sales = [];

    for (var sm in salesMaps) {
      final saleId = sm['id'] as int;
      final itemMaps = await db.query(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [saleId],
      );
      final items = itemMaps.map((im) => SaleItemModel.fromMap(im)).toList();
      sales.add(SaleModel.fromMap(sm, items: items));
    }

    return sales;
  }

  Future<SaleModel> clearBill(
    int saleId, {
    String? paymentMethod,
  }) async {
    final db = await _dbHelper.database;
    late SaleModel clearedSale;

    await db.transaction((txn) async {
      final rows = await txn.query('sales', where: 'id = ?', whereArgs: [saleId]);
      if (rows.isEmpty) {
        throw Exception('Sale with ID $saleId not found.');
      }
      final saleRow = rows.first;
      final currentStatus = (saleRow['status'] as String? ?? 'COMPLETED').toUpperCase();
      final grandTotal = (saleRow['grand_total'] as num).toDouble();
      final waiterId = saleRow['waiter_id'] as int?;
      final tableId = saleRow['table_id'] as int?;
      final invNum = saleRow['invoice_number'] as String;

      final updateValues = <String, dynamic>{
        'status': 'CLEARED',
      };
      if (paymentMethod != null && paymentMethod.isNotEmpty) {
        updateValues['payment_method'] = paymentMethod;
      }

      await txn.update('sales', updateValues, where: 'id = ?', whereArgs: [saleId]);

      // If it was REMAINING or PENDING, credit waiter stats now
      if (currentStatus == 'REMAINING' || currentStatus == 'PENDING') {
        if (waiterId != null) {
          await txn.rawUpdate('''
            UPDATE waiters
            SET total_sales = total_sales + ?, orders_count = orders_count + 1
            WHERE id = ?
          ''', [grandTotal, waiterId]);
        }
      }

      // Release table if it has no more remaining orders
      await _checkAndReleaseTableIfNoRemainingOrders(
        txn,
        tableId,
        tableName: saleRow['table_name'] as String?,
        excludingSaleId: saleId,
      );

      final itemMaps = await txn.query(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [saleId],
      );
      final items = itemMaps.map((im) => SaleItemModel.fromMap(im)).toList();

      // Verify stock deductions exist for this invoice; if not, deduct stock now upon clearing
      final existingDeductions = await txn.query(
        'stock_transactions',
        where: 'invoice_number = ? AND type = ?',
        whereArgs: [invNum, 'OUT_SALE'],
      );
      if (existingDeductions.isEmpty && items.isNotEmpty) {
        final settingsRows = await txn.query('settings', where: 'key = ?', whereArgs: ['milk_cups_per_kg']);
        final milkRatio = settingsRows.isNotEmpty
            ? (double.tryParse(settingsRows.first['value'] as String? ?? '5.0') ?? 5.0)
            : 5.0;
        await _stockDeductionService.deductStockForSale(
          txn: txn,
          cartItems: items,
          invoiceNumber: invNum,
          milkCupsPerKg: milkRatio,
        );
      }

      final updatedRow = await txn.query('sales', where: 'id = ?', whereArgs: [saleId]);
      clearedSale = SaleModel.fromMap(updatedRow.first, items: items);
    });

    return clearedSale;
  }

  Future<SaleModel> markBillAsRemaining(int saleId) async {
    final db = await _dbHelper.database;
    late SaleModel remainingSale;

    await db.transaction((txn) async {
      final rows = await txn.query('sales', where: 'id = ?', whereArgs: [saleId]);
      if (rows.isEmpty) {
        throw Exception('Sale with ID $saleId not found.');
      }
      final saleRow = rows.first;
      final currentStatus = (saleRow['status'] as String? ?? 'COMPLETED').toUpperCase();
      final grandTotal = (saleRow['grand_total'] as num).toDouble();
      final waiterId = saleRow['waiter_id'] as int?;
      final tableId = saleRow['table_id'] as int?;
      final invNum = saleRow['invoice_number'] as String;

      await txn.update('sales', {'status': 'REMAINING'}, where: 'id = ?', whereArgs: [saleId]);

      // If it was previously credited to waiter, deduct now
      if (currentStatus == 'CLEARED' || currentStatus == 'COMPLETED' || currentStatus == 'PAID') {
        if (waiterId != null) {
          await txn.rawUpdate('''
            UPDATE waiters
            SET total_sales = CASE WHEN total_sales >= ? THEN total_sales - ? ELSE 0.0 END,
                orders_count = CASE WHEN orders_count >= 1 THEN orders_count - 1 ELSE 0 END
            WHERE id = ?
          ''', [grandTotal, grandTotal, waiterId]);
        }
      }

      // Re-occupy table if tableId exists
      if (tableId != null) {
        await txn.update(
          'tables',
          {'status': 'Occupied', 'active_invoice_number': invNum},
          where: 'id = ?',
          whereArgs: [tableId],
        );
      }

      final itemMaps = await txn.query(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [saleId],
      );
      final items = itemMaps.map((im) => SaleItemModel.fromMap(im)).toList();

      final updatedRow = await txn.query('sales', where: 'id = ?', whereArgs: [saleId]);
      remainingSale = SaleModel.fromMap(updatedRow.first, items: items);
    });

    return remainingSale;
  }

  Future<List<SaleModel>> getSalesByDateRange(DateTime start, DateTime end) async {
    final db = await _dbHelper.database;
    final startStr = start.toIso8601String();
    final endStr = end.toIso8601String();

    final salesMaps = await db.query(
      'sales',
      where: 'date_time >= ? AND date_time <= ? AND status != ?',
      whereArgs: [startStr, endStr, 'CANCELLED'],
      orderBy: 'id DESC',
    );

    final List<SaleModel> sales = [];
    for (var sm in salesMaps) {
      final saleId = sm['id'] as int;
      final itemMaps = await db.query(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [saleId],
      );
      final items = itemMaps.map((im) => SaleItemModel.fromMap(im)).toList();
      sales.add(SaleModel.fromMap(sm, items: items));
    }

    return sales;
  }

  Future<void> updateSale(SaleModel sale, {String? oldInvoiceNumber}) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      await txn.update(
        'sales',
        {
          'invoice_number': sale.invoiceNumber,
          'table_id': sale.tableId,
          'table_name': sale.tableName,
          'waiter_id': sale.waiterId,
          'waiter_name': sale.waiterName,
          'customer_name': sale.customerName,
          'customer_phone': sale.customerPhone,
          'subtotal': sale.subtotal,
          'discount': sale.discount,
          'tax': sale.tax,
          'grand_total': sale.grandTotal,
          'payment_method': sale.paymentMethod,
          'status': sale.status,
        },
        where: 'id = ?',
        whereArgs: [sale.id],
      );

      // If invoice number was changed, sync linked records
      if (oldInvoiceNumber != null && oldInvoiceNumber != sale.invoiceNumber) {
        await txn.update(
          'stock_transactions',
          {'invoice_number': sale.invoiceNumber},
          where: 'invoice_number = ?',
          whereArgs: [oldInvoiceNumber],
        );
        await txn.update(
          'tables',
          {'active_invoice_number': sale.invoiceNumber},
          where: 'active_invoice_number = ?',
          whereArgs: [oldInvoiceNumber],
        );
      }
    });
  }

  Future<SaleModel> updateSaleWithItems({
    required int saleId,
    required String invoiceNumber,
    required List<SaleItemModel> cartItems,
    required String cashierName,
    int? waiterId,
    String? waiterName,
    int? tableId,
    String? tableName,
    String? customerName,
    String? customerPhone,
    required double subtotal,
    required double discount,
    required double tax,
    required double grandTotal,
    required String paymentMethod,
    required double milkCupsPerKg,
    String? status,
  }) async {
    final db = await _dbHelper.database;
    final nowStr = DateTime.now().toIso8601String();
    SaleModel? updatedSale;

    await db.transaction((txn) async {
      // 1. Fetch old sale to get previous values
      final oldSaleRows = await txn.query('sales', where: 'id = ?', whereArgs: [saleId]);
      if (oldSaleRows.isEmpty) {
        throw Exception('Sale with ID $saleId not found.');
      }
      final oldSale = oldSaleRows.first;
      final oldGrandTotal = (oldSale['grand_total'] as num).toDouble();
      final oldWaiterId = oldSale['waiter_id'] as int?;
      final oldInvoiceNumber = oldSale['invoice_number'] as String;
      final oldStatus = (oldSale['status'] as String? ?? 'COMPLETED').toUpperCase();
      final effectiveStatus = (status ?? oldStatus).toUpperCase();

      final bool oldWasCleared = oldStatus == 'CLEARED' || oldStatus == 'COMPLETED' || oldStatus == 'PAID';
      final bool newIsCleared = effectiveStatus == 'CLEARED' || effectiveStatus == 'COMPLETED' || effectiveStatus == 'PAID';

      // 2. Revert previous stock deductions recorded under oldInvoiceNumber
      final deductions = await txn.query(
        'stock_transactions',
        where: 'invoice_number = ? AND type = ?',
        whereArgs: [oldInvoiceNumber, 'OUT_SALE'],
      );
      for (var row in deductions) {
        final stockId = row['stock_id'] as int;
        final qty = (row['quantity'] as num).toDouble();
        await txn.rawUpdate(
          'UPDATE stock SET quantity = quantity + ?, last_updated = ? WHERE id = ?',
          [qty, nowStr, stockId],
        );
      }
      await txn.delete(
        'stock_transactions',
        where: 'invoice_number = ? AND type = ?',
        whereArgs: [oldInvoiceNumber, 'OUT_SALE'],
      );

      // 3. Reconcile Waiter Stats accurately based on cleared status
      if (oldWasCleared && !newIsCleared && oldWaiterId != null) {
        // Was cleared before, now remaining: deduct previous credit
        await txn.rawUpdate('''
          UPDATE waiters
          SET total_sales = CASE WHEN total_sales >= ? THEN total_sales - ? ELSE 0.0 END,
              orders_count = CASE WHEN orders_count >= 1 THEN orders_count - 1 ELSE 0 END
          WHERE id = ?
        ''', [oldGrandTotal, oldGrandTotal, oldWaiterId]);
      } else if (!oldWasCleared && newIsCleared && waiterId != null) {
        // Was remaining before, now cleared: credit new amount
        await txn.rawUpdate('''
          UPDATE waiters
          SET total_sales = total_sales + ?,
              orders_count = orders_count + 1
          WHERE id = ?
        ''', [grandTotal, waiterId]);
      } else if (oldWasCleared && newIsCleared) {
        // Both cleared: adjust difference
        if (oldWaiterId != null && oldWaiterId != waiterId) {
          await txn.rawUpdate('''
            UPDATE waiters
            SET total_sales = CASE WHEN total_sales >= ? THEN total_sales - ? ELSE 0.0 END,
                orders_count = CASE WHEN orders_count >= 1 THEN orders_count - 1 ELSE 0 END
            WHERE id = ?
          ''', [oldGrandTotal, oldGrandTotal, oldWaiterId]);
        } else if (oldWaiterId != null && oldWaiterId == waiterId) {
          await txn.rawUpdate('''
            UPDATE waiters
            SET total_sales = CASE WHEN (total_sales - ? + ?) >= 0 THEN (total_sales - ? + ?) ELSE 0.0 END
            WHERE id = ?
          ''', [oldGrandTotal, grandTotal, oldGrandTotal, grandTotal, oldWaiterId]);
        }

        if (waiterId != null && waiterId != oldWaiterId) {
          await txn.rawUpdate('''
            UPDATE waiters
            SET total_sales = total_sales + ?,
                orders_count = orders_count + 1
            WHERE id = ?
          ''', [grandTotal, waiterId]);
        }
      }

      // 4. Delete old line items
      await txn.delete('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);

      // 5. Insert new line items & calculate totalCost
      double totalCost = 0.0;
      for (var item in cartItems) {
        totalCost += (item.unitCost * item.quantity);
        await txn.insert('sale_items', {
          'sale_id': saleId,
          'product_id': item.productId,
          'product_name': item.productName,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
          'unit_cost': item.unitCost,
          'total_price': item.totalPrice,
          'notes': item.notes,
        });
      }

      // 6. Perform new Stock Deduction via Recipe Engine
      await _stockDeductionService.deductStockForSale(
        txn: txn,
        cartItems: cartItems,
        invoiceNumber: invoiceNumber,
        milkCupsPerKg: milkCupsPerKg,
      );

      // 7. Update Sale header record
      await txn.update(
        'sales',
        {
          'invoice_number': invoiceNumber,
          'cashier_name': cashierName,
          'table_id': tableId,
          'table_name': tableName,
          'waiter_id': waiterId,
          'waiter_name': waiterName,
          'customer_name': customerName,
          'customer_phone': customerPhone,
          'subtotal': subtotal,
          'discount': discount,
          'tax': tax,
          'grand_total': grandTotal,
          'total_cost': totalCost,
          'payment_method': paymentMethod,
          'status': effectiveStatus,
        },
        where: 'id = ?',
        whereArgs: [saleId],
      );

      // 8. Update Table status
      if (tableId != null || (tableName != null && tableName.isNotEmpty)) {
        if (newIsCleared) {
          await _checkAndReleaseTableIfNoRemainingOrders(
            txn,
            tableId,
            tableName: tableName,
            excludingSaleId: saleId,
          );
        } else {
          if (tableId != null) {
            await txn.update(
              'tables',
              {'status': 'Occupied', 'active_invoice_number': invoiceNumber},
              where: 'id = ?',
              whereArgs: [tableId],
            );
          } else if (tableName != null) {
            await txn.update(
              'tables',
              {'status': 'Occupied', 'active_invoice_number': invoiceNumber},
              where: 'table_name = ?',
              whereArgs: [tableName],
            );
          }
        }
      }

      updatedSale = SaleModel(
        id: saleId,
        invoiceNumber: invoiceNumber,
        dateTime: oldSale['date_time'] as String,
        cashierName: cashierName,
        waiterId: waiterId,
        waiterName: waiterName,
        tableId: tableId,
        tableName: tableName,
        customerName: customerName,
        customerPhone: customerPhone,
        subtotal: subtotal,
        discount: discount,
        tax: tax,
        grandTotal: grandTotal,
        totalCost: totalCost,
        paymentMethod: paymentMethod,
        status: effectiveStatus,
        items: cartItems,
      );
    });

    return updatedSale!;
  }

  Future<void> deleteSale(int saleId) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      // 1. Fetch sale
      final saleRows = await txn.query('sales', where: 'id = ?', whereArgs: [saleId]);
      if (saleRows.isEmpty) return;
      final sale = saleRows.first;
      final invNum = sale['invoice_number'] as String;
      final grandTotal = (sale['grand_total'] as num).toDouble();
      final waiterId = sale['waiter_id'] as int?;
      final tableId = sale['table_id'] as int?;
      final currentStatus = (sale['status'] as String? ?? 'COMPLETED').toUpperCase();
      final bool wasCleared = currentStatus == 'CLEARED' || currentStatus == 'COMPLETED' || currentStatus == 'PAID';

      // 2. Revert stock deductions recorded under this invoice (scoped to sale time range)
      final saleTime = sale['date_time'] as String;
      final parsedSaleTime = DateTime.tryParse(saleTime);
      List<Map<String, dynamic>> deductions;
      if (parsedSaleTime != null) {
        final startRange = parsedSaleTime.subtract(const Duration(minutes: 5)).toIso8601String();
        final endRange = parsedSaleTime.add(const Duration(minutes: 5)).toIso8601String();
        deductions = await txn.query(
          'stock_transactions',
          where: 'invoice_number = ? AND type = ? AND date_time >= ? AND date_time <= ?',
          whereArgs: [invNum, 'OUT_SALE', startRange, endRange],
        );
        final nowStr = DateTime.now().toIso8601String();
        for (var row in deductions) {
          final stockId = row['stock_id'] as int;
          final qty = (row['quantity'] as num).toDouble();
          await txn.rawUpdate(
            'UPDATE stock SET quantity = quantity + ?, last_updated = ? WHERE id = ?',
            [qty, nowStr, stockId],
          );
        }
        await txn.delete(
          'stock_transactions',
          where: 'invoice_number = ? AND type = ? AND date_time >= ? AND date_time <= ?',
          whereArgs: [invNum, 'OUT_SALE', startRange, endRange],
        );
      } else {
        deductions = await txn.query(
          'stock_transactions',
          where: 'invoice_number = ? AND type = ?',
          whereArgs: [invNum, 'OUT_SALE'],
        );
        final nowStr = DateTime.now().toIso8601String();
        for (var row in deductions) {
          final stockId = row['stock_id'] as int;
          final qty = (row['quantity'] as num).toDouble();
          await txn.rawUpdate(
            'UPDATE stock SET quantity = quantity + ?, last_updated = ? WHERE id = ?',
            [qty, nowStr, stockId],
          );
        }
        await txn.delete('stock_transactions', where: 'invoice_number = ?', whereArgs: [invNum]);
      }

      // 4. Revert waiter statistics ONLY if sale was previously cleared
      if (waiterId != null && wasCleared) {
        await txn.rawUpdate('''
          UPDATE waiters
          SET total_sales = CASE WHEN total_sales >= ? THEN total_sales - ? ELSE 0.0 END,
              orders_count = CASE WHEN orders_count >= 1 THEN orders_count - 1 ELSE 0 END
          WHERE id = ?
        ''', [grandTotal, grandTotal, waiterId]);
      }

      // 5. Release table if currently tied to this invoice or if it was remaining
      await _checkAndReleaseTableIfNoRemainingOrders(
        txn,
        tableId,
        tableName: sale['table_name'] as String?,
        excludingSaleId: saleId,
      );

      // 6. Delete sale line items
      await txn.delete('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);

      // 7. Delete sale record
      await txn.delete('sales', where: 'id = ?', whereArgs: [saleId]);
    });
  }
}
