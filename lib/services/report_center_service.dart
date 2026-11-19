import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/sale_model.dart';
import '../models/category_model.dart';

enum ReportFilterType {
  allTime,
  today,
  last10Days,
  thisMonth,
  specificDate,
  specificMonth,
}

class ItemSalesRecord {
  final int productId;
  final String productName;
  final int categoryId;
  final String categoryName;
  final int totalSold;
  final double totalRevenue;
  final double avgPrice;

  ItemSalesRecord({
    required this.productId,
    required this.productName,
    required this.categoryId,
    required this.categoryName,
    required this.totalSold,
    required this.totalRevenue,
    required this.avgPrice,
  });
}

class CategorySalesRecord {
  final int categoryId;
  final String categoryName;
  final int totalSold;
  final double totalRevenue;
  final int uniqueProductsCount;
  final double percentageShare;

  CategorySalesRecord({
    required this.categoryId,
    required this.categoryName,
    required this.totalSold,
    required this.totalRevenue,
    required this.uniqueProductsCount,
    required this.percentageShare,
  });
}

class StockUsageRecord {
  final int stockId;
  final String stockName;
  final double totalQuantity;
  final String unit;
  final int? categoryId;
  final String? categoryName;
  final int usageCount;

  StockUsageRecord({
    required this.stockId,
    required this.stockName,
    required this.totalQuantity,
    required this.unit,
    this.categoryId,
    this.categoryName,
    this.usageCount = 0,
  });
}

class SalesOverviewSummary {
  final double totalGrossSales;
  final double totalNetRevenue;
  final double totalDiscount;
  final double totalTax;
  final int totalOrders;
  final int clearedOrders;
  final int remainingOrders;
  final double cashTotal;
  final double onlineTotal;
  final double avgOrderValue;

  SalesOverviewSummary({
    required this.totalGrossSales,
    required this.totalNetRevenue,
    required this.totalDiscount,
    required this.totalTax,
    required this.totalOrders,
    required this.clearedOrders,
    required this.remainingOrders,
    required this.cashTotal,
    required this.onlineTotal,
    required this.avgOrderValue,
  });
}

class ReportCenterData {
  final ReportFilterType filterType;
  final String filterLabel;
  final DateTime? startDate;
  final DateTime? endDate;
  final SalesOverviewSummary overview;
  final List<SaleModel> salesList;
  final List<ItemSalesRecord> itemSales;
  final List<CategorySalesRecord> categorySales;
  final List<StockUsageRecord> stockUsage;
  final List<CategoryModel> allCategories;

  ReportCenterData({
    required this.filterType,
    required this.filterLabel,
    this.startDate,
    this.endDate,
    required this.overview,
    required this.salesList,
    required this.itemSales,
    required this.categorySales,
    required this.stockUsage,
    required this.allCategories,
  });
}

class ReportCenterService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  static ({DateTime? start, DateTime? end, String label}) resolveDateRange({
    required ReportFilterType filterType,
    DateTime? specificDate,
    int? specificMonth,
    int? specificYear,
  }) {
    final now = DateTime.now();

    switch (filterType) {
      case ReportFilterType.allTime:
        return (start: null, end: null, label: 'All Time');

      case ReportFilterType.today:
        final start = DateTime(now.year, now.month, now.day, 0, 0, 0);
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        final label = 'Today (${DateFormat('dd MMM yyyy').format(now)})';
        return (start: start, end: end, label: label);

      case ReportFilterType.last10Days:
        final start = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 9))
            .copyWith(hour: 0, minute: 0, second: 0);
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        final label =
            'Last 10 Days (${DateFormat('dd MMM').format(start)} - ${DateFormat('dd MMM yyyy').format(end)})';
        return (start: start, end: end, label: label);

      case ReportFilterType.thisMonth:
        final start = DateTime(now.year, now.month, 1, 0, 0, 0);
        final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        final label = 'This Month (${DateFormat('MMMM yyyy').format(now)})';
        return (start: start, end: end, label: label);

      case ReportFilterType.specificDate:
        final targetDate = specificDate ?? now;
        final start = DateTime(targetDate.year, targetDate.month, targetDate.day, 0, 0, 0);
        final end = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59, 59);
        final label = DateFormat('dd MMMM yyyy').format(targetDate);
        return (start: start, end: end, label: label);

      case ReportFilterType.specificMonth:
        final m = specificMonth ?? now.month;
        final y = specificYear ?? now.year;
        final start = DateTime(y, m, 1, 0, 0, 0);
        final end = DateTime(y, m + 1, 0, 23, 59, 59);
        final label = DateFormat('MMMM yyyy').format(DateTime(y, m, 1));
        return (start: start, end: end, label: label);
    }
  }

  Future<ReportCenterData> loadReportData({
    required ReportFilterType filterType,
    DateTime? specificDate,
    int? specificMonth,
    int? specificYear,
  }) async {
    final db = await _dbHelper.database;
    final range = resolveDateRange(
      filterType: filterType,
      specificDate: specificDate,
      specificMonth: specificMonth,
      specificYear: specificYear,
    );

    // 1. Load Categories
    final catRows = await db.query('categories', orderBy: 'sort_order ASC, name ASC');
    final allCategories = catRows.map((r) => CategoryModel.fromMap(r)).toList();
    final Map<int, String> categoryNameMap = {
      for (var c in allCategories) if (c.id != null) c.id!: c.name,
    };

    // 2. Load Sales with Date Filter
    String salesWhere = "status != 'CANCELLED'";
    List<dynamic> salesArgs = [];
    if (range.start != null && range.end != null) {
      salesWhere += " AND date_time >= ? AND date_time <= ?";
      salesArgs.add(range.start!.toIso8601String());
      salesArgs.add(range.end!.toIso8601String());
    }

    final salesRows = await db.query(
      'sales',
      where: salesWhere,
      whereArgs: salesArgs,
      orderBy: 'id DESC',
    );

    // Load Items for each sale
    final List<SaleModel> salesList = [];
    final List<int> saleIds = [];
    final List<String> invoiceNumbers = [];

    for (var row in salesRows) {
      final sId = row['id'] as int;
      saleIds.add(sId);
      final inv = row['invoice_number'] as String? ?? '';
      if (inv.isNotEmpty) invoiceNumbers.add(inv);

      final itemRows = await db.query('sale_items', where: 'sale_id = ?', whereArgs: [sId]);
      final items = itemRows.map((ir) => SaleItemModel.fromMap(ir)).toList();
      salesList.add(SaleModel.fromMap(row, items: items));
    }

    // 3. Overview Summary
    double totalGross = 0.0;
    double totalDiscount = 0.0;
    double totalTax = 0.0;
    double cashTotal = 0.0;
    double onlineTotal = 0.0;
    int clearedCount = 0;
    int remainingCount = 0;

    for (var s in salesList) {
      totalGross += s.grandTotal;
      totalDiscount += s.discount;
      totalTax += s.tax;

      final pMethod = s.paymentMethod.toUpperCase();
      if (pMethod == 'CASH') {
        cashTotal += s.grandTotal;
      } else {
        onlineTotal += s.grandTotal;
      }

      final st = s.status.toUpperCase();
      if (st == 'CLEARED' || st == 'COMPLETED' || st == 'PAID') {
        clearedCount++;
      } else {
        remainingCount++;
      }
    }

    final int totalOrders = salesList.length;
    final double avgOrder = totalOrders > 0 ? totalGross / totalOrders : 0.0;

    final overview = SalesOverviewSummary(
      totalGrossSales: totalGross,
      totalNetRevenue: totalGross - totalTax,
      totalDiscount: totalDiscount,
      totalTax: totalTax,
      totalOrders: totalOrders,
      clearedOrders: clearedCount,
      remainingOrders: remainingCount,
      cashTotal: cashTotal,
      onlineTotal: onlineTotal,
      avgOrderValue: avgOrder,
    );

    // 4. Products Map for Category Linking
    final prodRows = await db.rawQuery('''
      SELECT p.id, p.name, p.category_id, c.name as category_name
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
    ''');
    final Map<int, int> productCategoryMap = {};
    final Map<int, String> productCategoryNameMap = {};
    for (var p in prodRows) {
      final pid = p['id'] as int;
      final cid = p['category_id'] as int?;
      if (cid != null) {
        productCategoryMap[pid] = cid;
        productCategoryNameMap[pid] = p['category_name'] as String? ?? 'General';
      }
    }

    // 5. Item-wise Selling (Top Selling in Descending Order)
    final Map<int, Map<String, dynamic>> itemMap = {};
    for (var sale in salesList) {
      for (var item in sale.items) {
        final pid = item.productId;
        final catId = productCategoryMap[pid] ?? 0;
        final catName = productCategoryNameMap[pid] ?? 'General';

        if (!itemMap.containsKey(pid)) {
          itemMap[pid] = {
            'productId': pid,
            'productName': item.productName,
            'categoryId': catId,
            'categoryName': catName,
            'quantity': 0,
            'revenue': 0.0,
            'priceSum': 0.0,
            'count': 0,
          };
        }

        itemMap[pid]!['quantity'] = (itemMap[pid]!['quantity'] as int) + item.quantity;
        itemMap[pid]!['revenue'] = (itemMap[pid]!['revenue'] as double) + item.totalPrice;
        itemMap[pid]!['priceSum'] = (itemMap[pid]!['priceSum'] as double) + item.unitPrice;
        itemMap[pid]!['count'] = (itemMap[pid]!['count'] as int) + 1;
      }
    }

    final List<ItemSalesRecord> itemSales = itemMap.values.map((m) {
      final totalQty = m['quantity'] as int;
      final totalRev = m['revenue'] as double;
      final avgP = totalQty > 0 ? totalRev / totalQty : 0.0;
      return ItemSalesRecord(
        productId: m['productId'] as int,
        productName: m['productName'] as String,
        categoryId: m['categoryId'] as int,
        categoryName: m['categoryName'] as String,
        totalSold: totalQty,
        totalRevenue: totalRev,
        avgPrice: avgP,
      );
    }).toList();

    // STRICT DESCENDING ORDER: Top Selling Items on top!
    itemSales.sort((a, b) {
      if (b.totalSold != a.totalSold) {
        return b.totalSold.compareTo(a.totalSold);
      }
      return b.totalRevenue.compareTo(a.totalRevenue);
    });

    // 6. Category-wise Selling (Top Performing Categories)
    final Map<int, Map<String, dynamic>> catMap = {};
    for (var item in itemSales) {
      final cid = item.categoryId;
      final cname = item.categoryName;

      if (!catMap.containsKey(cid)) {
        catMap[cid] = {
          'categoryId': cid,
          'categoryName': cname,
          'totalSold': 0,
          'totalRevenue': 0.0,
          'productsCount': 0,
        };
      }

      catMap[cid]!['totalSold'] = (catMap[cid]!['totalSold'] as int) + item.totalSold;
      catMap[cid]!['totalRevenue'] = (catMap[cid]!['totalRevenue'] as double) + item.totalRevenue;
      catMap[cid]!['productsCount'] = (catMap[cid]!['productsCount'] as int) + 1;
    }

    final double grandRevenue = totalGross > 0 ? totalGross : 1.0;
    final List<CategorySalesRecord> categorySales = catMap.values.map((m) {
      final rev = m['totalRevenue'] as double;
      final share = (rev / grandRevenue) * 100.0;
      return CategorySalesRecord(
        categoryId: m['categoryId'] as int,
        categoryName: m['categoryName'] as String,
        totalSold: m['totalSold'] as int,
        totalRevenue: rev,
        uniqueProductsCount: m['productsCount'] as int,
        percentageShare: share,
      );
    }).toList();

    // STRICT DESCENDING ORDER: Category selling most on top!
    categorySales.sort((a, b) {
      if (b.totalRevenue != a.totalRevenue) {
        return b.totalRevenue.compareTo(a.totalRevenue);
      }
      return b.totalSold.compareTo(a.totalSold);
    });

    // 7. Total Stock Used / Deducted per Item
    // We calculate from two sources for 100% accuracy:
    // (a) Physical `stock_transactions` for the invoices/date range
    // (b) Theoretical recipe ingredient deductions for the sold products
    final Map<int, StockUsageRecord> stockUsageMap = {};

    if (range.start != null && range.end != null) {
      final txRows = await db.rawQuery('''
        SELECT st.stock_id, st.stock_name, st.unit, SUM(st.quantity) as total_qty, COUNT(st.id) as cnt
        FROM stock_transactions st
        WHERE st.type = 'OUT_SALE' AND st.date_time >= ? AND st.date_time <= ?
        GROUP BY st.stock_id, st.stock_name, st.unit
      ''', [range.start!.toIso8601String(), range.end!.toIso8601String()]);

      for (var row in txRows) {
        final sid = row['stock_id'] as int;
        final sname = row['stock_name'] as String;
        final unit = row['unit'] as String;
        final qty = (row['total_qty'] as num?)?.toDouble() ?? 0.0;
        final cnt = (row['cnt'] as int?) ?? 1;

        stockUsageMap[sid] = StockUsageRecord(
          stockId: sid,
          stockName: sname,
          totalQuantity: qty,
          unit: unit,
          usageCount: cnt,
        );
      }
    } else {
      // All Time
      final txRows = await db.rawQuery('''
        SELECT st.stock_id, st.stock_name, st.unit, SUM(st.quantity) as total_qty, COUNT(st.id) as cnt
        FROM stock_transactions st
        WHERE st.type = 'OUT_SALE'
        GROUP BY st.stock_id, st.stock_name, st.unit
      ''');

      for (var row in txRows) {
        final sid = row['stock_id'] as int;
        final sname = row['stock_name'] as String;
        final unit = row['unit'] as String;
        final qty = (row['total_qty'] as num?)?.toDouble() ?? 0.0;
        final cnt = (row['cnt'] as int?) ?? 1;

        stockUsageMap[sid] = StockUsageRecord(
          stockId: sid,
          stockName: sname,
          totalQuantity: qty,
          unit: unit,
          usageCount: cnt,
        );
      }
    }

    // If transactions were empty (e.g., historical sales before transaction logging),
    // calculate directly from recipe_items * itemSales quantity!
    if (stockUsageMap.isEmpty && itemSales.isNotEmpty) {
      final recipeRows = await db.rawQuery('''
        SELECT ri.stock_id, ri.stock_name, ri.unit, ri.quantity as recipe_qty, ri.product_id
        FROM recipe_items ri
      ''');

      final Map<int, List<Map<String, dynamic>>> productRecipes = {};
      for (var r in recipeRows) {
        final pid = r['product_id'] as int;
        productRecipes.putIfAbsent(pid, () => []).add(r);
      }

      for (var item in itemSales) {
        final recipes = productRecipes[item.productId] ?? [];
        for (var rec in recipes) {
          final sid = rec['stock_id'] as int;
          final sname = rec['stock_name'] as String;
          final unit = rec['unit'] as String;
          final rQty = (rec['recipe_qty'] as num).toDouble();
          final consumed = rQty * item.totalSold;

          if (stockUsageMap.containsKey(sid)) {
            final old = stockUsageMap[sid]!;
            stockUsageMap[sid] = StockUsageRecord(
              stockId: sid,
              stockName: sname,
              totalQuantity: old.totalQuantity + consumed,
              unit: unit,
              usageCount: old.usageCount + item.totalSold,
            );
          } else {
            stockUsageMap[sid] = StockUsageRecord(
              stockId: sid,
              stockName: sname,
              totalQuantity: consumed,
              unit: unit,
              usageCount: item.totalSold,
            );
          }
        }
      }
    }

    final List<StockUsageRecord> stockUsage = stockUsageMap.values.toList();
    stockUsage.sort((a, b) => b.totalQuantity.compareTo(a.totalQuantity));

    return ReportCenterData(
      filterType: filterType,
      filterLabel: range.label,
      startDate: range.start,
      endDate: range.end,
      overview: overview,
      salesList: salesList,
      itemSales: itemSales,
      categorySales: categorySales,
      stockUsage: stockUsage,
      allCategories: allCategories,
    );
  }

  /// Calculates Category-specific deep report data:
  /// products sold in this category, total revenue, and ingredients/stock used.
  Future<({
    CategoryModel category,
    int totalSold,
    double totalRevenue,
    List<ItemSalesRecord> products,
    List<StockUsageRecord> ingredientsUsed,
  })> getCategoryReportDetail({
    required int categoryId,
    required ReportCenterData data,
  }) async {
    final db = await _dbHelper.database;

    final cat = data.allCategories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => CategoryModel(id: categoryId, name: 'Category #$categoryId'),
    );

    // Filter products belonging to this category
    final categoryProducts = data.itemSales.where((i) => i.categoryId == categoryId).toList();
    final int totalSold = categoryProducts.fold(0, (sum, i) => sum + i.totalSold);
    final double totalRevenue = categoryProducts.fold(0.0, (sum, i) => sum + i.totalRevenue);

    // Calculate ingredients/stock used specifically for this category's products
    final Map<int, StockUsageRecord> categoryStockMap = {};

    if (categoryProducts.isNotEmpty) {
      final productIds = categoryProducts.map((p) => p.productId).toList();
      final inClause = productIds.map((_) => '?').join(',');

      final recipeRows = await db.rawQuery('''
        SELECT ri.stock_id, ri.stock_name, ri.unit, ri.quantity as recipe_qty, ri.product_id
        FROM recipe_items ri
        WHERE ri.product_id IN ($inClause)
      ''', productIds);

      final Map<int, List<Map<String, dynamic>>> prodRecipeMap = {};
      for (var r in recipeRows) {
        final pid = r['product_id'] as int;
        prodRecipeMap.putIfAbsent(pid, () => []).add(r);
      }

      for (var prod in categoryProducts) {
        final recipes = prodRecipeMap[prod.productId] ?? [];
        for (var rec in recipes) {
          final sid = rec['stock_id'] as int;
          final sname = rec['stock_name'] as String;
          final unit = rec['unit'] as String;
          final rQty = (rec['recipe_qty'] as num).toDouble();
          final consumed = rQty * prod.totalSold;

          if (categoryStockMap.containsKey(sid)) {
            final old = categoryStockMap[sid]!;
            categoryStockMap[sid] = StockUsageRecord(
              stockId: sid,
              stockName: sname,
              totalQuantity: old.totalQuantity + consumed,
              unit: unit,
              categoryId: categoryId,
              categoryName: cat.name,
              usageCount: old.usageCount + prod.totalSold,
            );
          } else {
            categoryStockMap[sid] = StockUsageRecord(
              stockId: sid,
              stockName: sname,
              totalQuantity: consumed,
              unit: unit,
              categoryId: categoryId,
              categoryName: cat.name,
              usageCount: prod.totalSold,
            );
          }
        }
      }
    }

    final List<StockUsageRecord> ingredients = categoryStockMap.values.toList();
    ingredients.sort((a, b) => b.totalQuantity.compareTo(a.totalQuantity));

    return (
      category: cat,
      totalSold: totalSold,
      totalRevenue: totalRevenue,
      products: categoryProducts,
      ingredientsUsed: ingredients,
    );
  }
}
