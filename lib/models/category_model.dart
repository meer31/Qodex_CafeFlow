class CategoryModel {
  final int? id;
  final String name;
  final String? description;
  final String? iconName;
  final int sortOrder;

  CategoryModel({
    this.id,
    required this.name,
    this.description,
    this.iconName,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon_name': iconName,
      'sort_order': sortOrder,
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String?,
      iconName: map['icon_name'] as String?,
      sortOrder: (map['sort_order'] as int?) ?? 0,
    );
  }
}
