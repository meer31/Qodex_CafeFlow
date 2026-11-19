class StockItemModel {
  final int? id;
  final String name;
  final String unit; // KG, Gram, Liter, ML, Piece, Bottle, Packet, Box, Tray
  final double quantity;
  final double minThreshold;
  final double costPerUnit;
  final String? lastUpdated;

  StockItemModel({
    this.id,
    required this.name,
    required this.unit,
    required this.quantity,
    this.minThreshold = 5.0,
    this.costPerUnit = 0.0,
    this.lastUpdated,
  });

  bool get isLowStock => quantity <= minThreshold;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'unit': unit,
      'quantity': quantity,
      'min_threshold': minThreshold,
      'cost_per_unit': costPerUnit,
      'last_updated': lastUpdated ?? DateTime.now().toIso8601String(),
    };
  }

  factory StockItemModel.fromMap(Map<String, dynamic> map) {
    return StockItemModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      unit: map['unit'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      minThreshold: (map['min_threshold'] as num?)?.toDouble() ?? 5.0,
      costPerUnit: (map['cost_per_unit'] as num?)?.toDouble() ?? 0.0,
      lastUpdated: map['last_updated'] as String?,
    );
  }

  StockItemModel copyWith({
    int? id,
    String? name,
    String? unit,
    double? quantity,
    double? minThreshold,
    double? costPerUnit,
    String? lastUpdated,
  }) {
    return StockItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      minThreshold: minThreshold ?? this.minThreshold,
      costPerUnit: costPerUnit ?? this.costPerUnit,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
