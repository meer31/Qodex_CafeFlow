class WaiterModel {
  final int? id;
  final String name;
  final String phone;
  final String status; // Active, Inactive
  final double totalSales;
  final int ordersCount;

  WaiterModel({
    this.id,
    required this.name,
    required this.phone,
    this.status = 'Active',
    this.totalSales = 0.0,
    this.ordersCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'status': status,
      'total_sales': totalSales,
      'orders_count': ordersCount,
    };
  }

  factory WaiterModel.fromMap(Map<String, dynamic> map) {
    return WaiterModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      phone: map['phone'] as String,
      status: map['status'] as String? ?? 'Active',
      totalSales: (map['total_sales'] as num?)?.toDouble() ?? 0.0,
      ordersCount: (map['orders_count'] as int?) ?? 0,
    );
  }
}
