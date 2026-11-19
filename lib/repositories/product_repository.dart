import '../database/database_helper.dart';
import '../models/product_model.dart';
import '../models/recipe_item_model.dart';

class ProductRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<ProductModel>> getAllProducts() async {
    final db = await _dbHelper.database;
    final String query = '''
      SELECT p.*, c.name as category_name
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      ORDER BY p.name ASC
    ''';

    final List<Map<String, dynamic>> maps = await db.rawQuery(query);
    final List<ProductModel> products = [];

    for (var map in maps) {
      final productId = map['id'] as int;
      final recipeMaps = await db.query(
        'recipe_items',
        where: 'product_id = ?',
        whereArgs: [productId],
      );
      final recipes = recipeMaps.map((r) => RecipeItemModel.fromMap(r)).toList();
      products.add(ProductModel.fromMap(map, recipes: recipes));
    }

    return products;
  }

  Future<int> insertProduct(
    ProductModel product, [
    List<RecipeItemModel> recipeItems = const [],
    double? initialStockQty,
    String? stockUnit,
  ]) async {
    final db = await _dbHelper.database;
    int productId = 0;

    await db.transaction((txn) async {
      productId = await txn.insert('products', product.toMap());

      for (var item in recipeItems) {
        await txn.insert('recipe_items', {
          'product_id': productId,
          'stock_id': item.stockId,
          'stock_name': item.stockName,
          'quantity': item.quantity,
          'unit': item.unit,
          'is_milk_derived': item.isMilkDerived ? 1 : 0,
          'tea_type_ratio_key': item.teaTypeRatioKey,
        });
      }

      // Automatically sync/create matching stock item if initial stock provided
      if (initialStockQty != null && initialStockQty >= 0) {
        final cleanName = product.name.trim();
        final existingStock = await txn.rawQuery(
          'SELECT id FROM stock WHERE LOWER(TRIM(name)) = LOWER(TRIM(?))',
          [cleanName],
        );
        if (existingStock.isEmpty) {
          final sUnit = (stockUnit != null && stockUnit.trim().isNotEmpty) ? stockUnit.trim() : 'Piece';
          final stockId = await txn.insert('stock', {
            'name': cleanName,
            'unit': sUnit,
            'quantity': initialStockQty,
            'min_threshold': 5.0,
            'cost_per_unit': product.costPrice,
            'last_updated': DateTime.now().toIso8601String(),
          });
          if (initialStockQty > 0) {
            await txn.insert('stock_transactions', {
              'stock_id': stockId,
              'stock_name': cleanName,
              'type': 'IN',
              'quantity': initialStockQty,
              'unit': sUnit,
              'date_time': DateTime.now().toIso8601String(),
              'notes': 'Initial Stock for Product $cleanName',
            });
          }
        }
      }
    });

    return productId;
  }

  Future<void> updateProduct(
    ProductModel product, [
    List<RecipeItemModel> recipeItems = const [],
    double? stockQty,
    String? stockUnit,
  ]) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      await txn.update(
        'products',
        product.toMap(),
        where: 'id = ?',
        whereArgs: [product.id],
      );

      // Delete existing recipe items & re-insert if any
      await txn.delete(
        'recipe_items',
        where: 'product_id = ?',
        whereArgs: [product.id],
      );

      for (var item in recipeItems) {
        await txn.insert('recipe_items', {
          'product_id': product.id,
          'stock_id': item.stockId,
          'stock_name': item.stockName,
          'quantity': item.quantity,
          'unit': item.unit,
          'is_milk_derived': item.isMilkDerived ? 1 : 0,
          'tea_type_ratio_key': item.teaTypeRatioKey,
        });
      }

      // Update or create matching stock item if stockQty provided
      if (stockQty != null) {
        final cleanName = product.name.trim();
        final existingStock = await txn.rawQuery(
          'SELECT id FROM stock WHERE LOWER(TRIM(name)) = LOWER(TRIM(?))',
          [cleanName],
        );
        final nowStr = DateTime.now().toIso8601String();
        if (existingStock.isNotEmpty) {
          final stockId = existingStock.first['id'] as int;
          await txn.rawUpdate(
            'UPDATE stock SET quantity = ?, cost_per_unit = ?, last_updated = ? WHERE id = ?',
            [stockQty, product.costPrice, nowStr, stockId],
          );
        } else {
          final sUnit = (stockUnit != null && stockUnit.trim().isNotEmpty) ? stockUnit.trim() : 'Piece';
          await txn.insert('stock', {
            'name': cleanName,
            'unit': sUnit,
            'quantity': stockQty,
            'min_threshold': 5.0,
            'cost_per_unit': product.costPrice,
            'last_updated': nowStr,
          });
        }
      }
    });
  }

  Future<void> updateProductRecipe(int productId, List<RecipeItemModel> recipeItems) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete(
        'recipe_items',
        where: 'product_id = ?',
        whereArgs: [productId],
      );

      for (var item in recipeItems) {
        await txn.insert('recipe_items', {
          'product_id': productId,
          'stock_id': item.stockId,
          'stock_name': item.stockName,
          'quantity': item.quantity,
          'unit': item.unit,
          'is_milk_derived': item.isMilkDerived ? 1 : 0,
          'tea_type_ratio_key': item.teaTypeRatioKey,
        });
      }
    });
  }

  Future<int> deleteProduct(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
