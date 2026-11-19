import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../models/recipe_item_model.dart';
import '../repositories/product_repository.dart';

class ProductProvider with ChangeNotifier {
  final ProductRepository _repository = ProductRepository();
  List<ProductModel> _products = [];
  bool _isLoading = false;

  List<ProductModel> get products => _products;
  bool get isLoading => _isLoading;

  ProductProvider() {
    loadProducts();
  }

  Future<void> loadProducts() async {
    _isLoading = true;
    notifyListeners();

    _products = await _repository.getAllProducts();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addProduct(
    ProductModel product, {
    List<RecipeItemModel> recipeItems = const [],
    double? initialStockQty,
    String? stockUnit,
  }) async {
    await _repository.insertProduct(product, recipeItems, initialStockQty, stockUnit);
    await loadProducts();
  }

  Future<void> updateProduct(
    ProductModel product, {
    List<RecipeItemModel> recipeItems = const [],
    double? initialStockQty,
    String? stockUnit,
  }) async {
    await _repository.updateProduct(product, recipeItems, initialStockQty, stockUnit);
    await loadProducts();
  }

  Future<void> updateProductRecipe(int productId, List<RecipeItemModel> recipeItems) async {
    await _repository.updateProductRecipe(productId, recipeItems);
    await loadProducts();
  }

  Future<void> deleteProduct(int id) async {
    await _repository.deleteProduct(id);
    await loadProducts();
  }
}
