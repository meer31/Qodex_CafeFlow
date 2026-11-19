class MeatPurchaseItemModel {
  final int? id;
  final int? purchaseId;
  final String meatType; // Chicken, Beef, Mutton
  final double quantityKg;
  final double ratePerKg;
  final double totalAmount;

  MeatPurchaseItemModel({
    this.id,
    this.purchaseId,
    required this.meatType,
    required this.quantityKg,
    required this.ratePerKg,
    required this.totalAmount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'purchase_id': purchaseId,
      'meat_type': meatType,
      'quantity_kg': quantityKg,
      'rate_per_kg': ratePerKg,
      'total_amount': totalAmount,
    };
  }

  factory MeatPurchaseItemModel.fromMap(Map<String, dynamic> map) {
    return MeatPurchaseItemModel(
      id: map['id'] as int?,
      purchaseId: map['purchase_id'] as int?,
      meatType: map['meat_type'] as String,
      quantityKg: (map['quantity_kg'] as num).toDouble(),
      ratePerKg: (map['rate_per_kg'] as num).toDouble(),
      totalAmount: (map['total_amount'] as num).toDouble(),
    );
  }
}

class MeatPurchaseModel {
  final int? id;
  final String invoiceNumber;
  final String dateTime;
  final double grandTotal;
  final List<MeatPurchaseItemModel> items;

  MeatPurchaseModel({
    this.id,
    required this.invoiceNumber,
    required this.dateTime,
    required this.grandTotal,
    this.items = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_number': invoiceNumber,
      'date_time': dateTime,
      'grand_total': grandTotal,
    };
  }

  factory MeatPurchaseModel.fromMap(Map<String, dynamic> map, {List<MeatPurchaseItemModel>? items}) {
    return MeatPurchaseModel(
      id: map['id'] as int?,
      invoiceNumber: map['invoice_number'] as String,
      dateTime: map['date_time'] as String,
      grandTotal: (map['grand_total'] as num).toDouble(),
      items: items ?? [],
    );
  }
}
