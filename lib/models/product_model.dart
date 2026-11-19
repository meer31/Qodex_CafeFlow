import 'recipe_item_model.dart';

class ProductModel {
  final int? id;
  final String name;
  final int categoryId;
  final String? categoryName;
  final double sellingPrice;
  final double costPrice;
  final String status; // Active, Inactive
  final String? imageUrl;
  final List<RecipeItemModel> recipeItems;

  ProductModel({
    this.id,
    required this.name,
    required this.categoryId,
    this.categoryName,
    required this.sellingPrice,
    required this.costPrice,
    this.status = 'Active',
    this.imageUrl,
    this.recipeItems = const [],
  });

  bool get isActive => status == 'Active';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category_id': categoryId,
      'selling_price': sellingPrice,
      'cost_price': costPrice,
      'status': status,
      'image_url': imageUrl,
    };
  }

  factory ProductModel.fromMap(Map<String, dynamic> map, {List<RecipeItemModel>? recipes}) {
    return ProductModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      categoryId: map['category_id'] as int,
      categoryName: map['category_name'] as String?,
      sellingPrice: (map['selling_price'] as num).toDouble(),
      costPrice: (map['cost_price'] as num).toDouble(),
      status: map['status'] as String? ?? 'Active',
      imageUrl: map['image_url'] as String?,
      recipeItems: recipes ?? [],
    );
  }

  ProductModel copyWith({
    int? id,
    String? name,
    int? categoryId,
    String? categoryName,
    double? sellingPrice,
    double? costPrice,
    String? status,
    String? imageUrl,
    List<RecipeItemModel>? recipeItems,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      costPrice: costPrice ?? this.costPrice,
      status: status ?? this.status,
      imageUrl: imageUrl ?? this.imageUrl,
      recipeItems: recipeItems ?? this.recipeItems,
    );
  }
}
