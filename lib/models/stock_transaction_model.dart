class StockTransactionModel {
  final int? id;
  final int stockId;
  final String stockName;
  final String type; // IN, OUT_SALE, ADJUSTMENT
  final double quantity;
  final String unit;
  final String dateTime;
  final String? invoiceNumber;
  final String? notes;

  StockTransactionModel({
    this.id,
    required this.stockId,
    required this.stockName,
    required this.type,
    required this.quantity,
    required this.unit,
    required this.dateTime,
    this.invoiceNumber,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'stock_id': stockId,
      'stock_name': stockName,
      'type': type,
      'quantity': quantity,
      'unit': unit,
      'date_time': dateTime,
      'invoice_number': invoiceNumber,
      'notes': notes,
    };
  }

  factory StockTransactionModel.fromMap(Map<String, dynamic> map) {
    return StockTransactionModel(
      id: map['id'] as int?,
      stockId: map['stock_id'] as int,
      stockName: map['stock_name'] as String,
      type: map['type'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      unit: map['unit'] as String,
      dateTime: map['date_time'] as String,
      invoiceNumber: map['invoice_number'] as String?,
      notes: map['notes'] as String?,
    );
  }
}
