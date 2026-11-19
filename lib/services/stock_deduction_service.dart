import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/sale_model.dart';
import '../models/recipe_item_model.dart';
import '../models/product_model.dart';
import 'milk_conversion_service.dart';
import 'unit_conversion_service.dart';

class StockDeductionResult {
  final bool success;
  final String? errorMessage;
  final List<String> warningMessages;

  StockDeductionResult({
    required this.success,
    this.errorMessage,
    this.warningMessages = const [],
  });
}

class DepletedStockItem {
  final int stockId;
  final String stockName;
  final double currentStock;
  final double requiredStock;
  final String unit;
  final String? ingredientUnit;
  final double? ingredientRequiredQty;

  DepletedStockItem({
    required this.stockId,
    required this.stockName,
    required this.currentStock,
    required this.requiredStock,
    required this.unit,
    this.ingredientUnit,
    this.ingredientRequiredQty,
  });

  double get shortage => (requiredStock - currentStock).clamp(0.0, double.infinity);
}

class ProductStockCheckResult {
  final bool isAvailable;
  final List<DepletedStockItem> depletedItems;
  final String? message;

  ProductStockCheckResult({
    required this.isAvailable,
    this.depletedItems = const [],
    this.message,
  });
}

class StockDeductionService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Helper to find a matching stock item for a product by name
  Future<Map<String, dynamic>?> findMatchingStockItem(
    DatabaseExecutor db,
    String productName,
  ) async {
    final cleanName = productName.trim().toLowerCase();
    if (cleanName.isEmpty) return null;

    // 1. Exact match by name (case-insensitive)
    final exact = await db.rawQuery(
      'SELECT * FROM stock WHERE LOWER(TRIM(name)) = ? LIMIT 1',
      [cleanName],
    );
    if (exact.isNotEmpty) {
      return exact.first;
    }

    // 2. Flexible name matching (e.g. "Cold Drinks" <-> "Cold Drinks 500ml")
    final allStock = await db.query('stock');
    for (var s in allStock) {
      final sName = (s['name'] as String).trim().toLowerCase();
      if (sName == cleanName || sName.contains(cleanName)) {
        return s;
      }
    }
    // Only allow cleanName.contains(sName) if sName is specific enough (length >= 4)
    for (var s in allStock) {
      final sName = (s['name'] as String).trim().toLowerCase();
      if (sName.length >= 4 && cleanName.contains(sName)) {
        return s;
      }
    }

    return null;
  }

  /// Helper to find the Milk stock item in inventory
  Future<Map<String, dynamic>?> findMilkStockItem(DatabaseExecutor db) async {
    final rows = await db.rawQuery(
      "SELECT * FROM stock WHERE LOWER(TRIM(name)) = 'milk' OR LOWER(TRIM(name)) LIKE '%fresh milk%' LIMIT 1",
    );
    if (rows.isNotEmpty) return rows.first;
    final fallback = await db.rawQuery(
      "SELECT * FROM stock WHERE LOWER(name) LIKE '%milk%' LIMIT 1",
    );
    return fallback.isNotEmpty ? fallback.first : null;
  }

  /// Determines if a product name or category is a tea/coffee beverage using milk
  bool isMilkBeverage(String productName, [String? categoryName]) {
    final p = productName.toLowerCase().trim();
    final c = (categoryName ?? '').toLowerCase().trim();

    // Explicit non-milk beverages
    if (p.contains('black tea') ||
        p.contains('green tea') ||
        p.contains('qahwa') ||
        p.contains('kahwa') ||
        p.contains('lemon tea') ||
        p.contains('water') ||
        p.contains('cold drink') ||
        p.contains('juice') ||
        p.contains('soda')) {
      return false;
    }

    // Tea or Chai items
    if (p.contains('chai') ||
        p.contains('tea') ||
        p.contains('doodh') ||
        p.contains('patti')) {
      return true;
    }

    // Coffee items
    if (p.contains('coffee') || p.contains('latte') || p.contains('cappuccino')) {
      return true;
    }

    // Category check
    if (c.contains('tea') || c.contains('coffee') || c.contains('chai')) {
      return true;
    }

    return false;
  }

  /// Extracts portion key for ratio multipliers (Full Tea = 1.0, Half Tea = 0.5, etc.)
  String getTeaPortionKey(String productName) {
    final p = productName.toLowerCase();
    if (p.contains('half')) return 'Half Tea';
    if (p.contains('large')) return 'Large Tea';
    if (p.contains('special') || p.contains('doodh patti')) return 'Special Tea';
    return 'Full Tea';
  }

  /// Helper to check if a recipe explicitly includes a milk stock item
  bool doesRecipeContainMilk(
    List<RecipeItemModel> recipeItems,
    int? milkStockId,
  ) {
    for (var r in recipeItems) {
      if (milkStockId != null && r.stockId == milkStockId) return true;
      final name = r.stockName.toLowerCase().trim();
      if (name == 'milk' || name.contains('milk') || name.contains('doodh')) {
        return true;
      }
    }
    return false;
  }

  /// Checks whether adding [additionalQuantity] of [product] to [currentCart]
  /// exceeds available stock in inventory.
  /// Automatically converts units (e.g. Gram to KG, ML to Litre) between recipe and stock.
  Future<ProductStockCheckResult> checkProductStockForCart({
    required ProductModel product,
    required int additionalQuantity,
    required List<SaleItemModel> currentCart,
    required double milkCupsPerKg,
  }) async {
    final db = await _dbHelper.database;
    final List<DepletedStockItem> depletedItems = [];

    // 1. Build simulated cart reflecting state after this addition
    final List<SaleItemModel> simulatedCart = [];
    bool foundInCart = false;

    for (var item in currentCart) {
      if (item.productId == product.id) {
        simulatedCart.add(item.copyWith(quantity: item.quantity + additionalQuantity));
        foundInCart = true;
      } else {
        simulatedCart.add(item);
      }
    }

    if (!foundInCart) {
      simulatedCart.add(SaleItemModel(
        productId: product.id ?? 0,
        productName: product.name,
        quantity: additionalQuantity,
        unitPrice: product.sellingPrice,
        unitCost: product.costPrice,
        totalPrice: product.sellingPrice * additionalQuantity,
      ));
    }

    // 2. Fetch milk stock once for checks
    final milkStock = await findMilkStockItem(db);
    final int? milkStockId = milkStock != null ? (milkStock['id'] as int) : null;

    // Cache stock records to avoid repeated queries
    final Map<int, Map<String, dynamic>> stockCache = {};
    if (milkStock != null && milkStockId != null) {
      stockCache[milkStockId] = milkStock;
    }

    // Maps to track total required quantities in each stock item's own native unit
    final Map<int, double> requiredInStockUnit = {};
    // For enhanced UI messaging: track recipe-level portion unit and original quantity
    final Map<int, String> ingredientUnits = {};
    final Map<int, double> ingredientOriginalQuantities = {};

    // 3. Calculate requirements across the simulated cart
    for (var cartItem in simulatedCart) {
      int effectiveProdId = cartItem.productId;
      if (effectiveProdId <= 0) {
        final prodRows = await db.rawQuery(
          'SELECT id FROM products WHERE LOWER(TRIM(name)) = LOWER(TRIM(?)) LIMIT 1',
          [cartItem.productName],
        );
        if (prodRows.isNotEmpty) {
          effectiveProdId = prodRows.first['id'] as int;
        }
      }

      // Check for configured recipe
      List<Map<String, dynamic>> recipeMaps = [];
      if (effectiveProdId > 0) {
        recipeMaps = await db.query(
          'recipe_items',
          where: 'product_id = ?',
          whereArgs: [effectiveProdId],
        );
      }

      if (recipeMaps.isNotEmpty) {
        final recipeItems = recipeMaps.map((m) => RecipeItemModel.fromMap(m)).toList();
        final bool hasMilkInRecipe = doesRecipeContainMilk(recipeItems, milkStockId);

        for (var recipeItem in recipeItems) {
          // Fetch stock info
          Map<String, dynamic>? stockRow = stockCache[recipeItem.stockId];
          if (stockRow == null) {
            final rows = await db.query('stock', where: 'id = ?', whereArgs: [recipeItem.stockId]);
            if (rows.isNotEmpty) {
              stockRow = rows.first;
              stockCache[recipeItem.stockId] = stockRow;
            }
          }

          if (stockRow != null) {
            final stockUnit = stockRow['unit'] as String;
            final double totalRecipeQty = recipeItem.quantity * cartItem.quantity;

            // Unit conversion from recipe unit (e.g. Gram, ML) to inventory stock unit (e.g. KG, Litre)
            final double convertedToStockUnit = UnitConversionService.convertQuantity(
              quantity: totalRecipeQty,
              fromUnit: recipeItem.unit,
              toUnit: stockUnit,
            );

            requiredInStockUnit[recipeItem.stockId] =
                (requiredInStockUnit[recipeItem.stockId] ?? 0.0) + convertedToStockUnit;

            ingredientUnits[recipeItem.stockId] = recipeItem.unit;
            ingredientOriginalQuantities[recipeItem.stockId] =
                (ingredientOriginalQuantities[recipeItem.stockId] ?? 0.0) + totalRecipeQty;
          }
        }

        // If it's a milk beverage but the recipe did not include milk, deduct via milk engine
        if (!hasMilkInRecipe && milkCupsPerKg > 0 && milkStock != null && milkStockId != null && isMilkBeverage(cartItem.productName)) {
          final portionKey = getTeaPortionKey(cartItem.productName);
          final milkKgNeeded = MilkConversionService.calculateMilkDeductionKg(
            milkCupsPerKg: milkCupsPerKg,
            teaTypeRatioKey: portionKey,
            quantity: cartItem.quantity,
          );
          final milkStockUnit = milkStock['unit'] as String;
          final convertedMilk = UnitConversionService.convertQuantity(
            quantity: milkKgNeeded,
            fromUnit: 'KG',
            toUnit: milkStockUnit,
          );
          requiredInStockUnit[milkStockId] =
              (requiredInStockUnit[milkStockId] ?? 0.0) + convertedMilk;
        }
      } else {
        // No custom recipe configured:
        // A. Milk Beverage Fallback via MilkConversionService
        if (milkCupsPerKg > 0 && milkStock != null && milkStockId != null && isMilkBeverage(cartItem.productName)) {
          final portionKey = getTeaPortionKey(cartItem.productName);
          final milkKgNeeded = MilkConversionService.calculateMilkDeductionKg(
            milkCupsPerKg: milkCupsPerKg,
            teaTypeRatioKey: portionKey,
            quantity: cartItem.quantity,
          );
          final milkStockUnit = milkStock['unit'] as String;
          final convertedMilk = UnitConversionService.convertQuantity(
            quantity: milkKgNeeded,
            fromUnit: 'KG',
            toUnit: milkStockUnit,
          );
          requiredInStockUnit[milkStockId] =
              (requiredInStockUnit[milkStockId] ?? 0.0) + convertedMilk;
        }

        // B. Direct Finished Product Stock Check (e.g. Mineral Water, Cold Drink, Snack)
        final directStock = await findMatchingStockItem(db, cartItem.productName);
        if (directStock != null) {
          final stockId = directStock['id'] as int;
          stockCache[stockId] = directStock;
          final isMilk = (directStock['name'] as String).toLowerCase().contains('milk');
          if (!isMilk || !isMilkBeverage(cartItem.productName)) {
            final stockUnit = directStock['unit'] as String;
            final double convertedDirect = UnitConversionService.convertQuantity(
              quantity: cartItem.quantity.toDouble(),
              fromUnit: 'Piece',
              toUnit: stockUnit,
            );
            requiredInStockUnit[stockId] =
                (requiredInStockUnit[stockId] ?? 0.0) + convertedDirect;
          }
        }
      }
    }

    // 4. Verify sufficiency against live database inventory in stock unit
    for (var entry in requiredInStockUnit.entries) {
      final stockId = entry.key;
      final requiredQty = entry.value;
      final stockRow = stockCache[stockId];
      if (stockRow == null) continue;

      final double currentStock = (stockRow['quantity'] as num).toDouble();
      final String stockName = stockRow['name'] as String;
      final String stockUnit = stockRow['unit'] as String;

      // Check if stock is depleted or insufficient
      if (currentStock <= 0.0 || currentStock < requiredQty) {
        depletedItems.add(DepletedStockItem(
          stockId: stockId,
          stockName: stockName,
          currentStock: currentStock,
          requiredStock: requiredQty,
          unit: stockUnit,
          ingredientUnit: ingredientUnits[stockId],
          ingredientRequiredQty: ingredientOriginalQuantities[stockId],
        ));
      }
    }

    if (depletedItems.isNotEmpty) {
      return ProductStockCheckResult(
        isAvailable: false,
        depletedItems: depletedItems,
        message: 'Stock khatam ho gaya hai.',
      );
    }

    return ProductStockCheckResult(isAvailable: true);
  }

  /// Validates stock sufficiency for all items in the sale before proceeding to checkout
  Future<StockDeductionResult> validateStockForSale(
    List<SaleItemModel> cartItems,
    double milkCupsPerKg,
  ) async {
    final db = await _dbHelper.database;
    final List<String> warnings = [];
    final List<String> outOfStockErrors = [];

    final milkStock = await findMilkStockItem(db);
    final int? milkStockId = milkStock != null ? (milkStock['id'] as int) : null;

    final Map<int, Map<String, dynamic>> stockCache = {};
    if (milkStock != null && milkStockId != null) {
      stockCache[milkStockId] = milkStock;
    }

    final Map<int, double> requiredInStockUnit = {};
    final Map<int, String> ingredientUnits = {};
    final Map<int, double> ingredientOriginalQuantities = {};

    for (var item in cartItems) {
      int effectiveProdId = item.productId;
      if (effectiveProdId <= 0) {
        final prodRows = await db.rawQuery(
          'SELECT id FROM products WHERE LOWER(TRIM(name)) = LOWER(TRIM(?)) LIMIT 1',
          [item.productName],
        );
        if (prodRows.isNotEmpty) {
          effectiveProdId = prodRows.first['id'] as int;
        }
      }

      List<Map<String, dynamic>> recipeMaps = [];
      if (effectiveProdId > 0) {
        recipeMaps = await db.query(
          'recipe_items',
          where: 'product_id = ?',
          whereArgs: [effectiveProdId],
        );
      }

      if (recipeMaps.isNotEmpty) {
        final recipeItems = recipeMaps.map((m) => RecipeItemModel.fromMap(m)).toList();
        final bool hasMilkInRecipe = doesRecipeContainMilk(recipeItems, milkStockId);

        for (var recipeItem in recipeItems) {
          Map<String, dynamic>? stockRow = stockCache[recipeItem.stockId];
          if (stockRow == null) {
            final rows = await db.query('stock', where: 'id = ?', whereArgs: [recipeItem.stockId]);
            if (rows.isNotEmpty) {
              stockRow = rows.first;
              stockCache[recipeItem.stockId] = stockRow;
            }
          }

          if (stockRow != null) {
            final stockUnit = stockRow['unit'] as String;
            final double totalRecipeQty = recipeItem.quantity * item.quantity;
            final double convertedToStock = UnitConversionService.convertQuantity(
              quantity: totalRecipeQty,
              fromUnit: recipeItem.unit,
              toUnit: stockUnit,
            );

            requiredInStockUnit[recipeItem.stockId] =
                (requiredInStockUnit[recipeItem.stockId] ?? 0.0) + convertedToStock;
            ingredientUnits[recipeItem.stockId] = recipeItem.unit;
            ingredientOriginalQuantities[recipeItem.stockId] =
                (ingredientOriginalQuantities[recipeItem.stockId] ?? 0.0) + totalRecipeQty;
          }
        }

        if (!hasMilkInRecipe && milkCupsPerKg > 0 && milkStock != null && milkStockId != null && isMilkBeverage(item.productName)) {
          final portionKey = getTeaPortionKey(item.productName);
          final milkKg = MilkConversionService.calculateMilkDeductionKg(
            milkCupsPerKg: milkCupsPerKg,
            teaTypeRatioKey: portionKey,
            quantity: item.quantity,
          );
          final milkStockUnit = milkStock['unit'] as String;
          final convertedMilk = UnitConversionService.convertQuantity(
            quantity: milkKg,
            fromUnit: 'KG',
            toUnit: milkStockUnit,
          );
          requiredInStockUnit[milkStockId] =
              (requiredInStockUnit[milkStockId] ?? 0.0) + convertedMilk;
        }
      } else {
        if (milkCupsPerKg > 0 && milkStock != null && milkStockId != null && isMilkBeverage(item.productName)) {
          final portionKey = getTeaPortionKey(item.productName);
          final milkKg = MilkConversionService.calculateMilkDeductionKg(
            milkCupsPerKg: milkCupsPerKg,
            teaTypeRatioKey: portionKey,
            quantity: item.quantity,
          );
          final milkStockUnit = milkStock['unit'] as String;
          final convertedMilk = UnitConversionService.convertQuantity(
            quantity: milkKg,
            fromUnit: 'KG',
            toUnit: milkStockUnit,
          );
          requiredInStockUnit[milkStockId] =
              (requiredInStockUnit[milkStockId] ?? 0.0) + convertedMilk;
        }

        final directStock = await findMatchingStockItem(db, item.productName);
        if (directStock != null) {
          final stockId = directStock['id'] as int;
          stockCache[stockId] = directStock;
          final isMilk = (directStock['name'] as String).toLowerCase().contains('milk');
          if (!isMilk || !isMilkBeverage(item.productName)) {
            final stockUnit = directStock['unit'] as String;
            final convertedDirect = UnitConversionService.convertQuantity(
              quantity: item.quantity.toDouble(),
              fromUnit: 'Piece',
              toUnit: stockUnit,
            );
            requiredInStockUnit[stockId] =
                (requiredInStockUnit[stockId] ?? 0.0) + convertedDirect;
          }
        }
      }
    }

    // Check available stock in database for all required items
    for (var entry in requiredInStockUnit.entries) {
      final stockId = entry.key;
      final reqQty = entry.value;

      final List<Map<String, dynamic>> stockRows = await db.query(
        'stock',
        columns: ['name', 'quantity', 'unit', 'min_threshold'],
        where: 'id = ?',
        whereArgs: [stockId],
      );

      if (stockRows.isNotEmpty) {
        final stockRow = stockRows.first;
        final double currentQty = (stockRow['quantity'] as num).toDouble();
        final double minThreshold = (stockRow['min_threshold'] as num?)?.toDouble() ?? 5.0;
        final String stockName = stockRow['name'] as String;
        final String stockUnit = stockRow['unit'] as String;

        if (currentQty < reqQty || currentQty <= 0.0) {
          final String ingDisplay = (ingredientUnits[stockId] != null && ingredientUnits[stockId] != stockUnit)
              ? ' (${UnitConversionService.formatQuantity(ingredientOriginalQuantities[stockId] ?? 0)} ${ingredientUnits[stockId]})'
              : '';

          outOfStockErrors.add(
            'Stock Khatam: "$stockName" has only ${UnitConversionService.formatQuantity(currentQty)} $stockUnit available (Need: ${UnitConversionService.formatQuantity(reqQty)} $stockUnit$ingDisplay). Stock minus me nahi ja sakta.',
          );
        } else if (currentQty - reqQty <= minThreshold) {
          warnings.add(
            'Warning: "$stockName" will reach low stock level (${UnitConversionService.formatQuantity(currentQty - reqQty)} $stockUnit remaining).',
          );
        }
      }
    }

    if (outOfStockErrors.isNotEmpty) {
      return StockDeductionResult(
        success: false,
        errorMessage: 'Bill generate nahi ho sakta kyunke stock khatam ho chuka hai:\n\n${outOfStockErrors.join('\n')}\n\nBarahe karam pehle stock add karein taakay stock minus me na jaye.',
        warningMessages: warnings,
      );
    }

    return StockDeductionResult(success: true, warningMessages: warnings);
  }

  /// Deducts stock items directly upon bill/invoice generation with atomic precision
  /// Automatically applies unit conversion (e.g. 200g Milk -> 0.20 KG deduction)
  Future<void> deductStockForSale({
    required Transaction txn,
    required List<SaleItemModel> cartItems,
    required String invoiceNumber,
    required double milkCupsPerKg,
  }) async {
    final nowStr = DateTime.now().toIso8601String();
    final milkStock = await findMilkStockItem(txn);
    final int? milkStockId = milkStock != null ? (milkStock['id'] as int) : null;
    final String milkStockName = milkStock != null ? (milkStock['name'] as String) : 'Milk';
    final String milkUnit = milkStock != null ? (milkStock['unit'] as String) : 'KG';

    for (var item in cartItems) {
      int effectiveProdId = item.productId;
      if (effectiveProdId <= 0) {
        final prodRows = await txn.rawQuery(
          'SELECT id FROM products WHERE LOWER(TRIM(name)) = LOWER(TRIM(?)) LIMIT 1',
          [item.productName],
        );
        if (prodRows.isNotEmpty) {
          effectiveProdId = prodRows.first['id'] as int;
        }
      }

      // Check configured recipe items
      List<Map<String, dynamic>> recipeMaps = [];
      if (effectiveProdId > 0) {
        recipeMaps = await txn.query(
          'recipe_items',
          where: 'product_id = ?',
          whereArgs: [effectiveProdId],
        );
      }

      if (recipeMaps.isNotEmpty) {
        final recipeItems = recipeMaps.map((m) => RecipeItemModel.fromMap(m)).toList();
        final bool hasMilkInRecipe = doesRecipeContainMilk(recipeItems, milkStockId);

        for (var recipeItem in recipeItems) {
          final stockRows = await txn.query('stock', where: 'id = ?', whereArgs: [recipeItem.stockId]);
          if (stockRows.isNotEmpty) {
            final stockRow = stockRows.first;
            final stockName = stockRow['name'] as String;
            final stockUnit = stockRow['unit'] as String;

            final double totalRecipeQty = recipeItem.quantity * item.quantity;
            final double deductionQtyInStockUnit = UnitConversionService.convertQuantity(
              quantity: totalRecipeQty,
              fromUnit: recipeItem.unit,
              toUnit: stockUnit,
            );

            if (deductionQtyInStockUnit > 0) {
              await txn.rawUpdate('''
                UPDATE stock
                SET quantity = CASE WHEN quantity - ? < 0 THEN 0.0 ELSE quantity - ? END,
                    last_updated = ?
                WHERE id = ?
              ''', [deductionQtyInStockUnit, deductionQtyInStockUnit, nowStr, recipeItem.stockId]);

              await txn.insert('stock_transactions', {
                'stock_id': recipeItem.stockId,
                'stock_name': stockName,
                'type': 'OUT_SALE',
                'quantity': deductionQtyInStockUnit,
                'unit': stockUnit,
                'date_time': nowStr,
                'invoice_number': invoiceNumber,
                'notes': 'Recipe deduction for ${item.productName} (x${item.quantity}): ${UnitConversionService.formatQuantity(totalRecipeQty)} ${recipeItem.unit} = ${UnitConversionService.formatQuantity(deductionQtyInStockUnit)} $stockUnit',
              });
            }
          }
        }

        // If it's a milk beverage and recipe did not explicitly specify milk, deduct via milk engine
        if (!hasMilkInRecipe && milkCupsPerKg > 0 && milkStockId != null && isMilkBeverage(item.productName)) {
          final portionKey = getTeaPortionKey(item.productName);
          final milkDeductionKg = MilkConversionService.calculateMilkDeductionKg(
            milkCupsPerKg: milkCupsPerKg,
            teaTypeRatioKey: portionKey,
            quantity: item.quantity,
          );
          final deductionInStockUnit = UnitConversionService.convertQuantity(
            quantity: milkDeductionKg,
            fromUnit: 'KG',
            toUnit: milkUnit,
          );

          if (deductionInStockUnit > 0) {
            await txn.rawUpdate('''
              UPDATE stock
              SET quantity = CASE WHEN quantity - ? < 0 THEN 0.0 ELSE quantity - ? END,
                  last_updated = ?
              WHERE id = ?
            ''', [deductionInStockUnit, deductionInStockUnit, nowStr, milkStockId]);

            await txn.insert('stock_transactions', {
              'stock_id': milkStockId,
              'stock_name': milkStockName,
              'type': 'OUT_SALE',
              'quantity': deductionInStockUnit,
              'unit': milkUnit,
              'date_time': nowStr,
              'invoice_number': invoiceNumber,
              'notes': 'Milk Engine auto-deducted for Bill #$invoiceNumber (${item.quantity}x ${item.productName} @ ${milkCupsPerKg.toStringAsFixed(1)} cups/KG)',
            });
          }
        }
      } else {
        // Fallback: No recipe defined
        // 1. Milk Engine for tea/coffee beverages
        if (milkCupsPerKg > 0 && milkStockId != null && isMilkBeverage(item.productName)) {
          final portionKey = getTeaPortionKey(item.productName);
          final milkDeductionKg = MilkConversionService.calculateMilkDeductionKg(
            milkCupsPerKg: milkCupsPerKg,
            teaTypeRatioKey: portionKey,
            quantity: item.quantity,
          );
          final deductionInStockUnit = UnitConversionService.convertQuantity(
            quantity: milkDeductionKg,
            fromUnit: 'KG',
            toUnit: milkUnit,
          );

          if (deductionInStockUnit > 0) {
            await txn.rawUpdate('''
              UPDATE stock
              SET quantity = CASE WHEN quantity - ? < 0 THEN 0.0 ELSE quantity - ? END,
                  last_updated = ?
              WHERE id = ?
            ''', [deductionInStockUnit, deductionInStockUnit, nowStr, milkStockId]);

            await txn.insert('stock_transactions', {
              'stock_id': milkStockId,
              'stock_name': milkStockName,
              'type': 'OUT_SALE',
              'quantity': deductionInStockUnit,
              'unit': milkUnit,
              'date_time': nowStr,
              'invoice_number': invoiceNumber,
              'notes': 'Milk Engine auto-deducted for Bill #$invoiceNumber (${item.quantity}x ${item.productName} @ ${milkCupsPerKg.toStringAsFixed(1)} cups/KG)',
            });
          }
        }

        // 2. Direct Stock Item deduction matching the sold product's name
        final directStock = await findMatchingStockItem(txn, item.productName);
        if (directStock != null) {
          final stockId = directStock['id'] as int;
          final isMilk = (directStock['name'] as String).toLowerCase().contains('milk');
          if (stockId != milkStockId || !isMilk || !isMilkBeverage(item.productName)) {
            final stockName = directStock['name'] as String;
            final stockUnit = directStock['unit'] as String;
            final deductionQty = UnitConversionService.convertQuantity(
              quantity: item.quantity.toDouble(),
              fromUnit: 'Piece',
              toUnit: stockUnit,
            );

            if (deductionQty > 0) {
              await txn.rawUpdate('''
                UPDATE stock
                SET quantity = CASE WHEN quantity - ? < 0 THEN 0.0 ELSE quantity - ? END,
                    last_updated = ?
                WHERE id = ?
              ''', [deductionQty, deductionQty, nowStr, stockId]);

              await txn.insert('stock_transactions', {
                'stock_id': stockId,
                'stock_name': stockName,
                'type': 'OUT_SALE',
                'quantity': deductionQty,
                'unit': stockUnit,
                'date_time': nowStr,
                'invoice_number': invoiceNumber,
                'notes': 'Auto-deducted for Bill #$invoiceNumber (${item.quantity}x $stockName)',
              });
            }
          }
        }
      }
    }
  }
}
