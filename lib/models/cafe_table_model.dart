class TableSectionModel {
  final int? id;
  final String name; // Outdoor, Family Hall, Inside Hall, VIP
  final int sortOrder;

  TableSectionModel({
    this.id,
    required this.name,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'sort_order': sortOrder,
    };
  }

  factory TableSectionModel.fromMap(Map<String, dynamic> map) {
    return TableSectionModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      sortOrder: (map['sort_order'] as int?) ?? 0,
    );
  }
}

class CafeTableModel {
  final int? id;
  final int sectionId;
  final String sectionName;
  final String tableName;
  final int capacity;
  final String status; // Available, Occupied, Reserved, Cleaning
  final String? activeInvoiceNumber;

  CafeTableModel({
    this.id,
    required this.sectionId,
    required this.sectionName,
    required this.tableName,
    this.capacity = 4,
    this.status = 'Available',
    this.activeInvoiceNumber,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'section_id': sectionId,
      'table_name': tableName,
      'capacity': capacity,
      'status': status,
      'active_invoice_number': activeInvoiceNumber,
    };
  }

  factory CafeTableModel.fromMap(Map<String, dynamic> map) {
    return CafeTableModel(
      id: map['id'] as int?,
      sectionId: map['section_id'] as int,
      sectionName: map['section_name'] as String? ?? 'General',
      tableName: map['table_name'] as String,
      capacity: map['capacity'] as int? ?? 4,
      status: map['status'] as String? ?? 'Available',
      activeInvoiceNumber: map['active_invoice_number'] as String?,
    );
  }

  CafeTableModel copyWith({
    int? id,
    int? sectionId,
    String? sectionName,
    String? tableName,
    int? capacity,
    String? status,
    String? activeInvoiceNumber,
    bool clearActiveInvoice = false,
  }) {
    return CafeTableModel(
      id: id ?? this.id,
      sectionId: sectionId ?? this.sectionId,
      sectionName: sectionName ?? this.sectionName,
      tableName: tableName ?? this.tableName,
      capacity: capacity ?? this.capacity,
      status: status ?? this.status,
      activeInvoiceNumber: clearActiveInvoice ? null : (activeInvoiceNumber ?? this.activeInvoiceNumber),
    );
  }
}
