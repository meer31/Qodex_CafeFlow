class SaleSessionModel {
  final int? id;
  final String sessionName;
  final String startTime;
  final String? endTime;
  final String businessDate; // The shift opening date (e.g. 2026-09-12)
  final double openingCash;  // Cash placed in drawer for change
  final double? closingCash; // Actual counted cash when ending sale
  final double totalSales;
  final double totalExpenses;
  final double cashSales;
  final double cardSales;
  final double onlineSales;
  final String status; // 'ACTIVE' or 'CLOSED'
  final String? notes;

  SaleSessionModel({
    this.id,
    required this.sessionName,
    required this.startTime,
    this.endTime,
    required this.businessDate,
    this.openingCash = 0.0,
    this.closingCash,
    this.totalSales = 0.0,
    this.totalExpenses = 0.0,
    this.cashSales = 0.0,
    this.cardSales = 0.0,
    this.onlineSales = 0.0,
    this.status = 'ACTIVE',
    this.notes,
  });

  /// Total money on counter = Opening Float for Change + Cash Sales
  /// (Prevents confusion during physical money counting)
  double get totalCounterCash => openingCash + cashSales;

  /// Expected drawer cash after paying out cash expenses
  double get expectedDrawerCash => (openingCash + cashSales) - totalExpenses;

  /// Net business profit of this shift = Total Sales - Total Expenses
  double get netProfit => totalSales - totalExpenses;

  bool get isActive => status == 'ACTIVE';
  bool get isClosed => status == 'CLOSED';

  String get startTimeFormatted {
    try {
      final dt = DateTime.parse(startTime);
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$hour:${dt.minute.toString().padLeft(2, '0')} $amPm';
    } catch (_) {
      return startTime.contains('T')
          ? startTime.split('T').last.substring(0, 5)
          : startTime;
    }
  }

  String get endTimeFormatted {
    if (endTime == null) return 'Active';
    try {
      final dt = DateTime.parse(endTime!);
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$hour:${dt.minute.toString().padLeft(2, '0')} $amPm';
    } catch (_) {
      return endTime!.contains('T')
          ? endTime!.split('T').last.substring(0, 5)
          : endTime!;
    }
  }

  /// Cash discrepancy between counted closing cash and expected drawer cash
  double? get cashDifference =>
      closingCash != null ? (closingCash! - expectedDrawerCash) : null;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_name': sessionName,
      'start_time': startTime,
      'end_time': endTime,
      'business_date': businessDate,
      'opening_cash': openingCash,
      'closing_cash': closingCash,
      'total_sales': totalSales,
      'total_expenses': totalExpenses,
      'cash_sales': cashSales,
      'card_sales': cardSales,
      'online_sales': onlineSales,
      'status': status,
      'notes': notes,
    };
  }

  factory SaleSessionModel.fromMap(Map<String, dynamic> map) {
    return SaleSessionModel(
      id: map['id'] as int?,
      sessionName: map['session_name'] as String? ?? 'Shift',
      startTime: map['start_time'] as String,
      endTime: map['end_time'] as String?,
      businessDate: map['business_date'] as String? ?? '',
      openingCash: (map['opening_cash'] as num?)?.toDouble() ?? 0.0,
      closingCash: (map['closing_cash'] as num?)?.toDouble(),
      totalSales: (map['total_sales'] as num?)?.toDouble() ?? 0.0,
      totalExpenses: (map['total_expenses'] as num?)?.toDouble() ?? 0.0,
      cashSales: (map['cash_sales'] as num?)?.toDouble() ?? 0.0,
      cardSales: (map['card_sales'] as num?)?.toDouble() ?? 0.0,
      onlineSales: (map['online_sales'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] as String? ?? 'ACTIVE',
      notes: map['notes'] as String?,
    );
  }

  SaleSessionModel copyWith({
    int? id,
    String? sessionName,
    String? startTime,
    String? endTime,
    String? businessDate,
    double? openingCash,
    double? closingCash,
    double? totalSales,
    double? totalExpenses,
    double? cashSales,
    double? cardSales,
    double? onlineSales,
    String? status,
    String? notes,
  }) {
    return SaleSessionModel(
      id: id ?? this.id,
      sessionName: sessionName ?? this.sessionName,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      businessDate: businessDate ?? this.businessDate,
      openingCash: openingCash ?? this.openingCash,
      closingCash: closingCash ?? this.closingCash,
      totalSales: totalSales ?? this.totalSales,
      totalExpenses: totalExpenses ?? this.totalExpenses,
      cashSales: cashSales ?? this.cashSales,
      cardSales: cardSales ?? this.cardSales,
      onlineSales: onlineSales ?? this.onlineSales,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }
}

/// Aggregated sold item metrics for a specific sale shift/day
class SessionSoldItem {
  final int productId;
  final String productName;
  final int quantity; // Total cups or items sold
  final double unitPrice; // Price per cup or unit
  final double totalRevenue; // Total revenue generated from this item
  final double totalCost;

  SessionSoldItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.totalRevenue,
    this.totalCost = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_revenue': totalRevenue,
      'total_cost': totalCost,
    };
  }

  factory SessionSoldItem.fromMap(Map<String, dynamic> map) {
    final totalQty = (map['quantity'] as num?)?.toInt() ?? 0;
    final totalRev = (map['total_revenue'] as num?)?.toDouble() ?? 0.0;
    final price = (map['unit_price'] as num?)?.toDouble() ??
        (totalQty > 0 ? (totalRev / totalQty) : 0.0);
    return SessionSoldItem(
      productId: (map['product_id'] as num?)?.toInt() ?? 0,
      productName: map['product_name'] as String? ?? 'Item',
      quantity: totalQty,
      unitPrice: price,
      totalRevenue: totalRev,
      totalCost: (map['total_cost'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Represents a product that was made/sold using a specific stock item during a shift
class SessionStockProductUsage {
  final int productId;
  final String productName;
  final int soldQuantity; // e.g. 80 cups, 40 rolls
  final double stockUsed; // e.g. 16.0 kg milk, 3.33 kg chicken
  final String unit; // e.g. kg, gram, pcs

  SessionStockProductUsage({
    required this.productId,
    required this.productName,
    required this.soldQuantity,
    required this.stockUsed,
    required this.unit,
  });
}

/// Represents the stock intake, consumption, and resulting sold items for a shift
class SessionStockReportItem {
  final int stockId;
  final String stockName;
  final String unit;
  final double stockIn; // Kitna stock in hua tha us din/shift
  final double stockOut; // Kitna us din khatam / deduct hua
  final double netBalance; // stockIn - stockOut (positive = leftover, negative = from existing stock)
  final List<SessionStockProductUsage> productsProduced; // Konsi kitni items bani

  SessionStockReportItem({
    required this.stockId,
    required this.stockName,
    required this.unit,
    required this.stockIn,
    required this.stockOut,
    required this.netBalance,
    required this.productsProduced,
  });
}

