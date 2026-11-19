import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cafe_flow/models/product_model.dart';
import 'package:cafe_flow/models/stock_item_model.dart';
import 'package:cafe_flow/models/recipe_item_model.dart';
import 'package:cafe_flow/models/category_model.dart';
import 'package:cafe_flow/providers/product_provider.dart';
import 'package:cafe_flow/providers/stock_provider.dart';
import 'package:cafe_flow/providers/category_provider.dart';
import 'package:cafe_flow/providers/settings_provider.dart';
import 'package:cafe_flow/screens/recipe_management_screen.dart';
import 'package:cafe_flow/widgets/recipe_config_dialog.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Raw Materials & Recipe Management Tests', () {
    late ProductModel testProduct;
    late StockItemModel coffeeBeansStock;
    late StockItemModel milkStock;

    setUp(() {
      testProduct = ProductModel(
        id: 101,
        name: 'Cappuccino Special',
        categoryId: 1,
        categoryName: 'Hot Coffee',
        sellingPrice: 350.0,
        costPrice: 90.0,
        status: 'Active',
        recipeItems: [
          RecipeItemModel(
            productId: 101,
            stockId: 1,
            stockName: 'Coffee Beans',
            quantity: 18.0,
            unit: 'Gram',
          ),
          RecipeItemModel(
            productId: 101,
            stockId: 2,
            stockName: 'Fresh Milk',
            quantity: 180.0,
            unit: 'ML',
          ),
        ],
      );

      coffeeBeansStock = StockItemModel(
        id: 1,
        name: 'Coffee Beans',
        unit: 'KG',
        quantity: 5.0,
        minThreshold: 1.0,
        costPerUnit: 2500.0,
      );

      milkStock = StockItemModel(
        id: 2,
        name: 'Fresh Milk',
        unit: 'Litre',
        quantity: 20.0,
        minThreshold: 4.0,
        costPerUnit: 220.0,
      );
    });

    test('RecipeItemModel serializes and deserializes correctly', () {
      final recipe = RecipeItemModel(
        id: 1,
        productId: 101,
        stockId: 1,
        stockName: 'Coffee Beans',
        quantity: 18.0,
        unit: 'Gram',
      );

      final map = recipe.toMap();
      expect(map['product_id'], equals(101));
      expect(map['stock_id'], equals(1));
      expect(map['stock_name'], equals('Coffee Beans'));
      expect(map['quantity'], equals(18.0));
      expect(map['unit'], equals('Gram'));

      final fromMap = RecipeItemModel.fromMap(map);
      expect(fromMap.productId, equals(101));
      expect(fromMap.stockName, equals('Coffee Beans'));
      expect(fromMap.quantity, equals(18.0));
    });

    test('Product with recipe items retains configured raw materials', () {
      expect(testProduct.recipeItems.length, equals(2));
      expect(testProduct.recipeItems[0].stockName, equals('Coffee Beans'));
      expect(testProduct.recipeItems[0].quantity, equals(18.0));
      expect(testProduct.recipeItems[1].stockName, equals('Fresh Milk'));
      expect(testProduct.recipeItems[1].quantity, equals(180.0));
    });

    testWidgets('RecipeConfigDialog displays product details and recipe rows', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final stockProvider = StockProvider();
      final productProvider = ProductProvider();
      final settingsProvider = SettingsProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: stockProvider),
            ChangeNotifierProvider.value(value: productProvider),
            ChangeNotifierProvider.value(value: settingsProvider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => RecipeConfigDialog.show(context, testProduct),
                  child: const Text('Open Recipe Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Recipe Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Cappuccino Special'), findsOneWidget);
      expect(find.text('Configure Raw Materials for automatic stock deduction upon sale'), findsOneWidget);
      expect(find.text('Save Recipe'), findsOneWidget);
    });

    testWidgets('RecipeManagementScreen renders 4 tabs and product list', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final stockProvider = StockProvider();
      final productProvider = ProductProvider();
      final categoryProvider = CategoryProvider();
      final settingsProvider = SettingsProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: stockProvider),
            ChangeNotifierProvider.value(value: productProvider),
            ChangeNotifierProvider.value(value: categoryProvider),
            ChangeNotifierProvider.value(value: settingsProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: RecipeManagementScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Screen Header
      expect(find.text('Raw Materials & Recipe Management'), findsOneWidget);

      // Verify Tab Labels
      expect(find.textContaining('Product Recipes'), findsOneWidget);
      expect(find.textContaining('Raw Materials Stock'), findsOneWidget);
      expect(find.text('Special Milk Engine'), findsOneWidget);
      expect(find.text('Auto-Deduction Audit Trail'), findsOneWidget);

      // Verify Action Button
      expect(find.text('+ Add Raw Material'), findsOneWidget);
    });
  });
}
