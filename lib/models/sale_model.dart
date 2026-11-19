class SaleItemModel {
  final int? id;
  final int? saleId;
  final int productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double unitCost;
  final double totalPrice;
  final String? notes;

  SaleItemModel({
    this.id,
    this.saleId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.unitCost = 0.0,
    required this.totalPrice,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sale_id': saleId,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'unit_cost': unitCost,
      'total_price': totalPrice,
      'notes': notes,
    };
  }

  factory SaleItemModel.fromMap(Map<String, dynamic> map) {
    return SaleItemModel(
      id: map['id'] as int?,
      saleId: map['sale_id'] as int?,
      productId: map['product_id'] as int,
      productName: map['product_name'] as String,
      quantity: map['quantity'] as int,
      unitPrice: (map['unit_price'] as num).toDouble(),
      unitCost: (map['unit_cost'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (map['total_price'] as num).toDouble(),
      notes: map['notes'] as String?,
    );
  }

  SaleItemModel copyWith({
    int? id,
    int? saleId,
    int? productId,
    String? productName,
    int? quantity,
    double? unitPrice,
    double? unitCost,
    double? totalPrice,
    String? notes,
  }) {
    return SaleItemModel(
      id: id ?? this.id,
      saleId: saleId ?? this.saleId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      unitCost: unitCost ?? this.unitCost,
      totalPrice: totalPrice ?? this.totalPrice,
      notes: notes ?? this.notes,
    );
  }
}

class SaleModel {
  final int? id;
  final int? sessionId;
  final String invoiceNumber;
  final String dateTime;
  final String cashierName;
  final int? waiterId;
  final String? waiterName;
  final int? tableId;
  final String? tableName;
  final String? customerName;
  final String? customerPhone;
  final double subtotal;
  final double discount;
  final double tax;
  final double grandTotal;
  final double totalCost;
  final String paymentMethod;
  final String status; // COMPLETED, CANCELLED
  final List<SaleItemModel> items;

  SaleModel({
    this.id,
    this.sessionId,
    required this.invoiceNumber,
    required this.dateTime,
    required this.cashierName,
    this.waiterId,
    this.waiterName,
    this.tableId,
    this.tableName,
    this.customerName,
    this.customerPhone,
    required this.subtotal,
    this.discount = 0.0,
    this.tax = 0.0,
    required this.grandTotal,
    this.totalCost = 0.0,
    required this.paymentMethod,
    this.status = 'COMPLETED',
    this.items = const [],
  });

  double get profit => grandTotal - totalCost;

  bool get isCleared =>
      status.toUpperCase() == 'CLEARED' ||
      status.toUpperCase() == 'COMPLETED' ||
      status.toUpperCase() == 'PAID';

  bool get isRemaining =>
      status.toUpperCase() == 'REMAINING' ||
      status.toUpperCase() == 'PENDING';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'invoice_number': invoiceNumber,
      'date_time': dateTime,
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
      'status': status,
    };
  }

  factory SaleModel.fromMap(Map<String, dynamic> map, {List<SaleItemModel>? items}) {
    return SaleModel(
      id: map['id'] as int?,
      sessionId: map['session_id'] as int?,
      invoiceNumber: map['invoice_number'] as String,
      dateTime: map['date_time'] as String,
      cashierName: map['cashier_name'] as String,
      waiterId: map['waiter_id'] as int?,
      waiterName: map['waiter_name'] as String?,
      tableId: map['table_id'] as int?,
      tableName: map['table_name'] as String?,
      customerName: map['customer_name'] as String?,
      customerPhone: map['customer_phone'] as String?,
      subtotal: (map['subtotal'] as num).toDouble(),
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      tax: (map['tax'] as num?)?.toDouble() ?? 0.0,
      grandTotal: (map['grand_total'] as num).toDouble(),
      paymentMethod: map['payment_method'] as String,
      status: map['status'] as String? ?? 'COMPLETED',
      items: items ?? [],
    );
  }

  SaleModel copyWith({
    int? id,
    int? sessionId,
    String? invoiceNumber,
    String? dateTime,
    String? cashierName,
    int? waiterId,
    String? waiterName,
    int? tableId,
    String? tableName,
    String? customerName,
    String? customerPhone,
    double? subtotal,
    double? discount,
    double? tax,
    double? grandTotal,
    double? totalCost,
    String? paymentMethod,
    String? status,
    List<SaleItemModel>? items,
  }) {
    return SaleModel(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      dateTime: dateTime ?? this.dateTime,
      cashierName: cashierName ?? this.cashierName,
      waiterId: waiterId ?? this.waiterId,
      waiterName: waiterName ?? this.waiterName,
      tableId: tableId ?? this.tableId,
      tableName: tableName ?? this.tableName,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
      grandTotal: grandTotal ?? this.grandTotal,
      totalCost: totalCost ?? this.totalCost,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      items: items ?? this.items,
    );
  }
}
