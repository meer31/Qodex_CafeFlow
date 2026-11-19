import '../database/database_helper.dart';
import '../models/sale_session_model.dart';
import '../models/sale_model.dart';
import '../models/expense_model.dart';

class SaleSessionRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Retrieves the currently active sale shift session (if any)
  Future<SaleSessionModel?> getActiveSession() async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'sale_sessions',
      where: 'status = ?',
      whereArgs: ['ACTIVE'],
      orderBy: 'id DESC',
      limit: 1,
    );

    if (results.isEmpty) return null;

    final session = SaleSessionModel.fromMap(results.first);
    // Recalculate live financial totals to ensure current stats are reflected
    return await recalculateSessionFinancials(session.id!);
  }

  /// Starts a new daily sale session with an opening counter cash float
  Future<SaleSessionModel> startSession({
    required double openingCash,
    String? notes,
    DateTime? startTime,
  }) async {
    final db = await _dbHelper.database;
    final now = startTime ?? DateTime.now();
    final nowIso = now.toIso8601String();
    final businessDate =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final amPm = now.hour >= 12 ? 'PM' : 'AM';
    final timeFormatted = '$hour:${now.minute.toString().padLeft(2, '0')} $amPm';
    final sessionName = 'Shift $businessDate ($timeFormatted)';

    final id = await db.insert('sale_sessions', {
      'session_name': sessionName,
      'start_time': nowIso,
      'end_time': null,
      'business_date': businessDate,
      'opening_cash': openingCash,
      'closing_cash': null,
      'total_sales': 0.0,
      'total_expenses': 0.0,
      'cash_sales': 0.0,
      'card_sales': 0.0,
      'online_sales': 0.0,
      'status': 'ACTIVE',
      'notes': notes,
    });

    return SaleSessionModel(
      id: id,
      sessionName: sessionName,
      startTime: nowIso,
      businessDate: businessDate,
      openingCash: openingCash,
      status: 'ACTIVE',
      notes: notes,
    );
  }

  /// Ends and closes a daily sale session
  Future<SaleSessionModel> endSession({
    required int sessionId,
    double? closingCash,
    String? notes,
  }) async {
    final db = await _dbHelper.database;
    final nowIso = DateTime.now().toIso8601String();

    // First recalculate the exact live financial totals from invoices & expenses
    final liveSession = await recalculateSessionFinancials(sessionId);
    if (liveSession == null) {
      throw Exception('Sale session with ID $sessionId not found.');
    }

    await db.update(
      'sale_sessions',
      {
        'end_time': nowIso,
        'closing_cash': closingCash,
        'total_sales': liveSession.totalSales,
        'total_expenses': liveSession.totalExpenses,
        'cash_sales': liveSession.cashSales,
        'card_sales': liveSession.cardSales,
        'online_sales': liveSession.onlineSales,
        'status': 'CLOSED',
        'notes': notes ?? liveSession.notes,
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );

    return liveSession.copyWith(
      endTime: nowIso,
      closingCash: closingCash,
      status: 'CLOSED',
      notes: notes ?? liveSession.notes,
    );
  }

  /// Computes live sales and expenses belonging to a session and updates the record
  Future<SaleSessionModel?> recalculateSessionFinancials(int sessionId) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'sale_sessions',
      where: 'id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );

    if (results.isEmpty) return null;
    final session = SaleSessionModel.fromMap(results.first);

    // Sum all sales tagged with this session_id (or between start and end time if untagged)
    final salesMaps = await db.rawQuery(
      '''
      SELECT grand_total, payment_method, status 
      FROM sales 
      WHERE session_id = ? 
         OR (session_id IS NULL AND date_time >= ? AND (? IS NULL OR date_time <= ?))
      ''',
      [sessionId, session.startTime, session.endTime, session.endTime],
    );

    double totalSales = 0.0;
    double cashSales = 0.0;
    double cardSales = 0.0;
    double onlineSales = 0.0;

    for (var row in salesMaps) {
      final total = (row['grand_total'] as num?)?.toDouble() ?? 0.0;
      final method = (row['payment_method'] as String? ?? 'Cash').toLowerCase();
      final status = (row['status'] as String? ?? 'COMPLETED').toUpperCase();

      final isCleared = status == 'CLEARED' || status == 'COMPLETED' || status == 'PAID';
      if (isCleared) {
        totalSales += total;
        if (method.contains('cash')) {
          cashSales += total;
        } else if (method.contains('card')) {
          cardSales += total;
        } else {
          onlineSales += total;
        }
      }
    }

    // Sum all expenses tagged with this session_id (or between start and end time)
    final expenseMaps = await db.rawQuery(
      '''
      SELECT amount 
      FROM expenses 
      WHERE session_id = ? 
         OR (session_id IS NULL AND date_time >= ? AND (? IS NULL OR date_time <= ?))
      ''',
      [sessionId, session.startTime, session.endTime, session.endTime],
    );

    double totalExpenses = 0.0;
    for (var row in expenseMaps) {
      totalExpenses += (row['amount'] as num?)?.toDouble() ?? 0.0;
    }

    // Update session table with latest calculated values
    await db.update(
      'sale_sessions',
      {
        'total_sales': totalSales,
        'total_expenses': totalExpenses,
        'cash_sales': cashSales,
        'card_sales': cardSales,
        'online_sales': onlineSales,
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );

    return session.copyWith(
      totalSales: totalSales,
      totalExpenses: totalExpenses,
      cashSales: cashSales,
      cardSales: cardSales,
      onlineSales: onlineSales,
    );
  }

  /// Retrieves all sessions ordered from newest to oldest
  Future<List<SaleSessionModel>> getAllSessions() async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'sale_sessions',
      orderBy: 'id DESC',
    );

    final List<SaleSessionModel> sessions = [];
    for (var map in results) {
      final session = SaleSessionModel.fromMap(map);
      if (session.isActive) {
        final refreshed = await recalculateSessionFinancials(session.id!);
        sessions.add(refreshed ?? session);
      } else {
        sessions.add(session);
      }
    }
    return sessions;
  }

  /// Fetches all sales/invoices that belong to a specific session
  Future<List<SaleModel>> getSessionInvoices(int sessionId) async {
    final db = await _dbHelper.database;
    final sessionMap = await db.query(
      'sale_sessions',
      where: 'id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );

    if (sessionMap.isEmpty) return [];
    final session = SaleSessionModel.fromMap(sessionMap.first);

    final salesRows = await db.rawQuery(
      '''
      SELECT * FROM sales 
      WHERE session_id = ? 
         OR (session_id IS NULL AND date_time >= ? AND (? IS NULL OR date_time <= ?))
      ORDER BY id DESC
      ''',
      [sessionId, session.startTime, session.endTime, session.endTime],
    );

    final List<SaleModel> sales = [];
    for (var saleMap in salesRows) {
      final saleId = saleMap['id'] as int;
      final itemsRows = await db.query(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [saleId],
      );
      final items = itemsRows.map((m) => SaleItemModel.fromMap(m)).toList();
      sales.add(SaleModel.fromMap(saleMap, items: items));
    }
    return sales;
  }

  /// Fetches all expenses that belong to a specific session
  Future<List<ExpenseModel>> getSessionExpenses(int sessionId) async {
    final db = await _dbHelper.database;
    final sessionMap = await db.query(
      'sale_sessions',
      where: 'id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );

    if (sessionMap.isEmpty) return [];
    final session = SaleSessionModel.fromMap(sessionMap.first);

    final expenseRows = await db.rawQuery(
      '''
      SELECT * FROM expenses 
      WHERE session_id = ? 
         OR (session_id IS NULL AND date_time >= ? AND (? IS NULL OR date_time <= ?))
      ORDER BY id DESC
      ''',
      [sessionId, session.startTime, session.endTime, session.endTime],
    );

    return expenseRows.map((m) => ExpenseModel.fromMap(m)).toList();
  }

  /// Fetches aggregated selling items breakdown for a specific shift session.
  /// Returns each item with total cups/items sold, price per unit, and total revenue.
  Future<List<SessionSoldItem>> getSessionSoldItems(int sessionId) async {
    final db = await _dbHelper.database;
    final sessionMap = await db.query(
      'sale_sessions',
      where: 'id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );

    if (sessionMap.isEmpty) return [];
    final session = SaleSessionModel.fromMap(sessionMap.first);

    final rows = await db.rawQuery(
      '''
      SELECT 
        si.product_id,
        si.product_name,
        SUM(si.quantity) as total_quantity,
        SUM(si.total_price) as total_revenue,
        SUM(si.unit_cost * si.quantity) as total_cost,
        AVG(si.unit_price) as avg_unit_price
      FROM sale_items si
      JOIN sales s ON si.sale_id = s.id
      WHERE (s.session_id = ? 
         OR (s.session_id IS NULL AND s.date_time >= ? AND (? IS NULL OR s.date_time <= ?)))
        AND UPPER(s.status) != 'CANCELLED'
      GROUP BY si.product_id, si.product_name
      ORDER BY total_quantity DESC, total_revenue DESC
      ''',
      [sessionId, session.startTime, session.endTime, session.endTime],
    );

    return rows.map((r) {
      final totalQty = (r['total_quantity'] as num?)?.toInt() ?? 0;
      final totalRev = (r['total_revenue'] as num?)?.toDouble() ?? 0.0;
      final avgPrice = totalQty > 0
          ? (totalRev / totalQty)
          : ((r['avg_unit_price'] as num?)?.toDouble() ?? 0.0);

      return SessionSoldItem(
        productId: (r['product_id'] as num?)?.toInt() ?? 0,
        productName: r['product_name'] as String? ?? 'Item',
        quantity: totalQty,
        unitPrice: avgPrice,
        totalRevenue: totalRev,
        totalCost: (r['total_cost'] as num?)?.toDouble() ?? 0.0,
      );
    }).toList();
  }

  /// Fetches comprehensive stock report for a shift session:
  /// - Stock In: Quantity added during this shift/day
  /// - Stock Out: Quantity consumed/deducted during this shift/day
  /// - Net Balance: In - Out
  /// - Products Produced: Breakdown of items sold with this ingredient (e.g. Full Tea -> Milk, Chicken Roll -> Chicken)
  Future<List<SessionStockReportItem>> getSessionStockReport(int sessionId) async {
    final db = await _dbHelper.database;
    final sessionMap = await db.query(
      'sale_sessions',
      where: 'id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );

    if (sessionMap.isEmpty) return [];
    final session = SaleSessionModel.fromMap(sessionMap.first);

    // 1. All stock definitions in system
    final stockRows = await db.query('stock', orderBy: 'name ASC');
    final Map<int, Map<String, dynamic>> stockMaster = {};
    final Map<String, int> stockNameIdMap = {};
    for (var s in stockRows) {
      final id = s['id'] as int;
      stockMaster[id] = s;
      stockNameIdMap[(s['name'] as String).trim().toLowerCase()] = id;
    }

    // 2. Inward stock transactions during this session / business day
    final stockInRows = await db.rawQuery(
      '''
      SELECT stock_id, stock_name, unit, SUM(quantity) as total_in
      FROM stock_transactions
      WHERE type LIKE 'IN%'
        AND (
          (date_time >= ? AND (? IS NULL OR date_time <= ?))
          OR (date_time LIKE ? AND ? IS NOT NULL)
        )
      GROUP BY stock_id, stock_name, unit
      ''',
      [
        session.startTime,
        session.endTime,
        session.endTime,
        '${session.businessDate}%',
        session.businessDate,
      ],
    );

    final Map<int, double> stockInMap = {};
    for (var r in stockInRows) {
      final sid = r['stock_id'] as int;
      stockInMap[sid] = (r['total_in'] as num?)?.toDouble() ?? 0.0;
    }

    // 3. Outward stock transactions (type = 'OUT_SALE') for this session
    final salesRows = await db.rawQuery(
      '''
      SELECT id, invoice_number FROM sales 
      WHERE (session_id = ? 
         OR (session_id IS NULL AND date_time >= ? AND (? IS NULL OR date_time <= ?)))
        AND UPPER(status) != 'CANCELLED'
      ''',
      [sessionId, session.startTime, session.endTime, session.endTime],
    );

    final List<String> invoiceNumbers = salesRows
        .map((s) => s['invoice_number'] as String? ?? '')
        .where((inv) => inv.isNotEmpty)
        .toList();

    final Map<int, double> stockOutTxMap = {};
    if (invoiceNumbers.isNotEmpty) {
      final inClause = invoiceNumbers.map((_) => '?').join(',');
      final outRows = await db.rawQuery(
        '''
        SELECT stock_id, stock_name, unit, SUM(quantity) as total_out
        FROM stock_transactions
        WHERE type = 'OUT_SALE' AND invoice_number IN ($inClause)
        GROUP BY stock_id, stock_name, unit
        ''',
        invoiceNumbers,
      );
      for (var r in outRows) {
        final sid = r['stock_id'] as int;
        stockOutTxMap[sid] = (r['total_out'] as num?)?.toDouble() ?? 0.0;
      }
    } else {
      final outRows = await db.rawQuery(
        '''
        SELECT stock_id, stock_name, unit, SUM(quantity) as total_out
        FROM stock_transactions
        WHERE type = 'OUT_SALE'
          AND date_time >= ? AND (? IS NULL OR date_time <= ?)
        GROUP BY stock_id, stock_name, unit
        ''',
        [session.startTime, session.endTime, session.endTime],
      );
      for (var r in outRows) {
        final sid = r['stock_id'] as int;
        stockOutTxMap[sid] = (r['total_out'] as num?)?.toDouble() ?? 0.0;
      }
    }

    // 4. Products sold in this session
    final soldRows = await db.rawQuery(
      '''
      SELECT 
        si.product_id,
        si.product_name,
        SUM(si.quantity) as total_sold
      FROM sale_items si
      JOIN sales s ON si.sale_id = s.id
      WHERE (s.session_id = ? 
         OR (s.session_id IS NULL AND s.date_time >= ? AND (? IS NULL OR s.date_time <= ?)))
        AND UPPER(s.status) != 'CANCELLED'
      GROUP BY si.product_id, si.product_name
      ORDER BY total_sold DESC
      ''',
      [sessionId, session.startTime, session.endTime, session.endTime],
    );

    // 5. Recipe items mapping
    final recipeRows = await db.rawQuery(
      '''
      SELECT ri.product_id, ri.stock_id, ri.stock_name, ri.quantity as recipe_qty, ri.unit
      FROM recipe_items ri
      '''
    );
    final Map<int, List<Map<String, dynamic>>> productRecipesMap = {};
    for (var r in recipeRows) {
      final pid = r['product_id'] as int;
      productRecipesMap.putIfAbsent(pid, () => []).add(r);
    }

    final Map<int, List<SessionStockProductUsage>> stockProductUsageMap = {};
    final Map<int, double> recipeCalculatedOutMap = {};

    for (var sRow in soldRows) {
      final pid = sRow['product_id'] as int;
      final pName = sRow['product_name'] as String? ?? 'Item';
      final soldQty = (sRow['total_sold'] as num?)?.toInt() ?? 0;
      if (soldQty <= 0) continue;

      final recipes = productRecipesMap[pid] ?? [];
      if (recipes.isNotEmpty) {
        for (var rec in recipes) {
          final sid = rec['stock_id'] as int;
          final unit = rec['unit'] as String? ?? '';
          final rQty = (rec['recipe_qty'] as num?)?.toDouble() ?? 0.0;
          final used = rQty * soldQty;

          recipeCalculatedOutMap[sid] = (recipeCalculatedOutMap[sid] ?? 0.0) + used;
          stockProductUsageMap.putIfAbsent(sid, () => []).add(
            SessionStockProductUsage(
              productId: pid,
              productName: pName,
              soldQuantity: soldQty,
              stockUsed: used,
              unit: unit,
            ),
          );
        }
      } else {
        // Direct product match by name with stock
        final cleanPName = pName.trim().toLowerCase();
        final matchedStockId = stockNameIdMap[cleanPName];
        if (matchedStockId != null) {
          final sUnit = stockMaster[matchedStockId]?['unit'] as String? ?? 'pcs';
          final used = soldQty.toDouble();
          recipeCalculatedOutMap[matchedStockId] = (recipeCalculatedOutMap[matchedStockId] ?? 0.0) + used;
          stockProductUsageMap.putIfAbsent(matchedStockId, () => []).add(
            SessionStockProductUsage(
              productId: pid,
              productName: pName,
              soldQuantity: soldQty,
              stockUsed: used,
              unit: sUnit,
            ),
          );
        }
      }
    }

    // 6. Combine all stock items that were either In, Out, or used in products
    final Set<int> relevantStockIds = {
      ...stockInMap.keys,
      ...stockOutTxMap.keys,
      ...recipeCalculatedOutMap.keys,
      ...stockProductUsageMap.keys,
    };

    final List<SessionStockReportItem> report = [];

    for (var sid in relevantStockIds) {
      final stockData = stockMaster[sid];
      final sName = stockData != null ? (stockData['name'] as String) : 'Stock #$sid';
      final sUnit = stockData != null ? (stockData['unit'] as String) : '';

      final stockIn = stockInMap[sid] ?? 0.0;
      final txOut = stockOutTxMap[sid] ?? 0.0;
      final recipeOut = recipeCalculatedOutMap[sid] ?? 0.0;
      final stockOut = txOut > 0 ? txOut : recipeOut;

      final products = stockProductUsageMap[sid] ?? [];
      products.sort((a, b) => b.soldQuantity.compareTo(a.soldQuantity));

      report.add(
        SessionStockReportItem(
          stockId: sid,
          stockName: sName,
          unit: sUnit,
          stockIn: stockIn,
          stockOut: stockOut,
          netBalance: stockIn - stockOut,
          productsProduced: products,
        ),
      );
    }

    report.sort((a, b) {
      final actA = a.stockOut + a.stockIn;
      final actB = b.stockOut + b.stockIn;
      if (actB != actA) return actB.compareTo(actA);
      return a.stockName.toLowerCase().compareTo(b.stockName.toLowerCase());
    });

    return report;
  }
}
