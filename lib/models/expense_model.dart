class ExpenseModel {
  final int? id;
  final int? sessionId;
  final String title;
  final String category;
  final double amount;
  final String dateTime;
  final String? notes;

  ExpenseModel({
    this.id,
    this.sessionId,
    required this.title,
    required this.category,
    required this.amount,
    required this.dateTime,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'title': title,
      'category': category,
      'amount': amount,
      'date_time': dateTime,
      'notes': notes,
    };
  }

  factory ExpenseModel.fromMap(Map<String, dynamic> map) {
    return ExpenseModel(
      id: map['id'] as int?,
      sessionId: map['session_id'] as int?,
      title: map['title'] as String,
      category: map['category'] as String,
      amount: (map['amount'] as num).toDouble(),
      dateTime: map['date_time'] as String,
      notes: map['notes'] as String?,
    );
  }

  ExpenseModel copyWith({
    int? id,
    int? sessionId,
    String? title,
    String? category,
    double? amount,
    String? dateTime,
    String? notes,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      title: title ?? this.title,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      dateTime: dateTime ?? this.dateTime,
      notes: notes ?? this.notes,
    );
  }
}

