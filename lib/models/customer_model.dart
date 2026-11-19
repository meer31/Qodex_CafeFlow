class CustomerModel {
  final int? id;
  final String name;
  final String phone;
  final int loyaltyPoints;
  final double totalSpent;

  CustomerModel({
    this.id,
    required this.name,
    required this.phone,
    this.loyaltyPoints = 0,
    this.totalSpent = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'loyalty_points': loyaltyPoints,
      'total_spent': totalSpent,
    };
  }

  factory CustomerModel.fromMap(Map<String, dynamic> map) {
    return CustomerModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      phone: map['phone'] as String,
      loyaltyPoints: (map['loyalty_points'] as int?) ?? 0,
      totalSpent: (map['total_spent'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
