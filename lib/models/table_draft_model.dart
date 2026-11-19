import 'dart:convert';
import 'sale_model.dart';

class TableDraftModel {
  final int tableId;
  final int? waiterId;
  final String? waiterName;
  final String? customerName;
  final String? customerPhone;
  final String? orderType;
  final double discountAmount;
  final String paymentMethod;
  final String? tokenNumber;
  final List<SaleItemModel> items;
  final List<SaleItemModel> kitchenPrintedItems;
  final String updatedAt;

  TableDraftModel({
    required this.tableId,
    this.waiterId,
    this.waiterName,
    this.customerName,
    this.customerPhone,
    this.orderType = 'Dine In',
    this.discountAmount = 0.0,
    this.paymentMethod = 'Cash',
    this.tokenNumber,
    required this.items,
    this.kitchenPrintedItems = const [],
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'table_id': tableId,
      'waiter_id': waiterId,
      'waiter_name': waiterName,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'order_type': orderType,
      'discount_amount': discountAmount,
      'payment_method': paymentMethod,
      'token_number': tokenNumber,
      'items_json': jsonEncode(items.map((i) => i.toMap()).toList()),
      'kitchen_printed_items_json': jsonEncode(kitchenPrintedItems.map((i) => i.toMap()).toList()),
      'updated_at': updatedAt,
    };
  }

  factory TableDraftModel.fromMap(Map<String, dynamic> map) {
    List<SaleItemModel> parsedItems = [];
    if (map['items_json'] != null && (map['items_json'] as String).isNotEmpty) {
      try {
        final decoded = jsonDecode(map['items_json'] as String) as List<dynamic>;
        parsedItems = decoded.map((m) => SaleItemModel.fromMap(Map<String, dynamic>.from(m as Map))).toList();
      } catch (_) {}
    }

    List<SaleItemModel> parsedKitchen = [];
    if (map['kitchen_printed_items_json'] != null && (map['kitchen_printed_items_json'] as String).isNotEmpty) {
      try {
        final decoded = jsonDecode(map['kitchen_printed_items_json'] as String) as List<dynamic>;
        parsedKitchen = decoded.map((m) => SaleItemModel.fromMap(Map<String, dynamic>.from(m as Map))).toList();
      } catch (_) {}
    }

    return TableDraftModel(
      tableId: map['table_id'] as int,
      waiterId: map['waiter_id'] as int?,
      waiterName: map['waiter_name'] as String?,
      customerName: map['customer_name'] as String?,
      customerPhone: map['customer_phone'] as String?,
      orderType: map['order_type'] as String? ?? 'Dine In',
      discountAmount: (map['discount_amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: map['payment_method'] as String? ?? 'Cash',
      tokenNumber: map['token_number'] as String?,
      items: parsedItems,
      kitchenPrintedItems: parsedKitchen,
      updatedAt: map['updated_at'] as String? ?? DateTime.now().toIso8601String(),
    );
  }
}
