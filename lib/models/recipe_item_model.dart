class RecipeItemModel {
  final int? id;
  final int productId;
  final int stockId;
  final String stockName;
  final double quantity; // Required quantity per unit of product
  final String unit; // ML, Gram, KG, Piece, etc.
  final bool isMilkDerived; // True if this item uses Special Milk Ratio logic
  final String? teaTypeRatioKey; // Full Tea, Half Tea, Large Tea, Special Tea

  RecipeItemModel({
    this.id,
    required this.productId,
    required this.stockId,
    required this.stockName,
    required this.quantity,
    required this.unit,
    this.isMilkDerived = false,
    this.teaTypeRatioKey,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'stock_id': stockId,
      'stock_name': stockName,
      'quantity': quantity,
      'unit': unit,
      'is_milk_derived': isMilkDerived ? 1 : 0,
      'tea_type_ratio_key': teaTypeRatioKey,
    };
  }

  factory RecipeItemModel.fromMap(Map<String, dynamic> map) {
    return RecipeItemModel(
      id: map['id'] as int?,
      productId: map['product_id'] as int,
      stockId: map['stock_id'] as int,
      stockName: map['stock_name'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      unit: map['unit'] as String,
      isMilkDerived: (map['is_milk_derived'] as int?) == 1,
      teaTypeRatioKey: map['tea_type_ratio_key'] as String?,
    );
  }
}
