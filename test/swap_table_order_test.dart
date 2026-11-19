import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cafe_flow/models/cafe_table_model.dart';
import 'package:cafe_flow/models/product_model.dart';
import 'package:cafe_flow/models/sale_model.dart';
import 'package:cafe_flow/providers/pos_provider.dart';
import 'package:cafe_flow/providers/table_provider.dart';
import 'package:cafe_flow/widgets/swap_table_dialog.dart';

import 'package:cafe_flow/repositories/table_repository.dart';
import 'package:cafe_flow/repositories/sale_repository.dart';

class FakeTableRepository extends TableRepository {
  List<CafeTableModel> tables = [];
  List<TableSectionModel> sections = [];

  @override
  Future<void> swapTables(CafeTableModel tableA, CafeTableModel tableB) async {
    final idxA = tables.indexWhere((t) => t.id == tableA.id);
    final idxB = tables.indexWhere((t) => t.id == tableB.id);
    if (idxA >= 0 && idxB >= 0) {
      final tA = tables[idxA];
      final tB = tables[idxB];
      tables[idxA] = tA.copyWith(
        status: tB.status,
        activeInvoiceNumber: tB.activeInvoiceNumber,
        clearActiveInvoice: tB.activeInvoiceNumber == null,
      );
      tables[idxB] = tB.copyWith(
        status: tA.status,
        activeInvoiceNumber: tA.activeInvoiceNumber,
        clearActiveInvoice: tA.activeInvoiceNumber == null,
      );
    }
  }

  @override
  Future<List<TableSectionModel>> getAllSections() async => List.from(sections);

  @override
  Future<List<CafeTableModel>> getAllTables() async => List.from(tables);
}

class FakeSaleRepository extends SaleRepository {
  @override
  Future<List<SaleModel>> getRemainingSales() async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PosProvider posProvider;
  late TableProvider tableProvider;
  late FakeTableRepository fakeTableRepo;
  late FakeSaleRepository fakeSaleRepo;

  final section1 = TableSectionModel(id: 1, name: 'Ground Floor', sortOrder: 1);
  final tableA = CafeTableModel(
    id: 10,
    sectionId: 1,
    sectionName: 'Ground Floor',
    tableName: 'Table T10',
    capacity: 4,
    status: 'Occupied',
    activeInvoiceNumber: 'INV-100',
  );
  final tableB = CafeTableModel(
    id: 20,
    sectionId: 1,
    sectionName: 'Ground Floor',
    tableName: 'Table T20',
    capacity: 4,
    status: 'Available',
  );

  final testProduct = ProductModel(
    id: 99,
    name: 'Espresso Double',
    categoryId: 1,
    sellingPrice: 250.0,
    costPrice: 80.0,
    status: 'Active',
  );

  setUp(() {
    posProvider = PosProvider();
    fakeTableRepo = FakeTableRepository();
    fakeTableRepo.sections = [section1];
    fakeTableRepo.tables = [tableA, tableB];
    fakeSaleRepo = FakeSaleRepository();
    tableProvider = TableProvider(
      repository: fakeTableRepo,
      saleRepository: fakeSaleRepo,
      autoLoad: false,
    );
    tableProvider.setTablesAndSections(
      sections: [section1],
      tables: [tableA, tableB],
    );
  });

  group('POS Provider Table Order Swapping Logic', () {
    test('Swaps active in-memory cart and tables correctly', () {
      // 1. Select Table A and add items to cart
      posProvider.selectTable(tableA);
      posProvider.addToCart(testProduct);
      posProvider.addToCart(testProduct);
      expect(posProvider.cart.length, equals(1));
      expect(posProvider.cart.first.quantity, equals(2));

      // 2. Perform table swap between Table A and Table B
      posProvider.swapTableOrders(tableA, tableB);

      // Now currently selected table should be Table B, and cart has the 2 items
      expect(posProvider.selectedTable?.id, equals(tableB.id));
      expect(posProvider.cart.length, equals(1));
      expect(posProvider.cart.first.quantity, equals(2));

      // Table A's cart in cache should now be empty/cleared
      expect(posProvider.tableCarts.containsKey(tableA.id!), isFalse);
      // Table B's cart in cache holds the order
      expect(posProvider.tableCarts[tableB.id!]?.first.quantity, equals(2));
    });

    test('Swapping between two tables both having orders exchanges their carts', () {
      final productPizza = ProductModel(
        id: 101,
        name: 'Pizza Margherita',
        categoryId: 1,
        sellingPrice: 800.0,
        costPrice: 300.0,
        status: 'Active',
      );

      // Set order for Table A
      posProvider.selectTable(tableA);
      posProvider.addToCart(testProduct); // Espresso

      // Switch to Table B and set order for Table B
      posProvider.selectTable(tableB);
      posProvider.addToCart(productPizza); // Pizza

      expect(posProvider.cart.first.productName, equals('Pizza Margherita'));

      // Perform swap
      posProvider.swapTableOrders(tableA, tableB);

      // The user who was on Table B with Pizza has their active order moved to Table A
      expect(posProvider.selectedTable?.id, equals(tableA.id));
      expect(posProvider.cart.first.productName, equals('Pizza Margherita'));

      // And Table B's stored cart in cache holds Table A's order (Espresso)
      expect(posProvider.tableCarts[tableB.id!]?.first.productName, equals('Espresso Double'));
    });
  });

  group('Table Provider Table Swapping Logic', () {
    test('swapTables swaps status and active invoice number between tables', () async {
      expect(tableProvider.tables.firstWhere((t) => t.id == 10).status, equals('Occupied'));
      expect(tableProvider.tables.firstWhere((t) => t.id == 20).status, equals('Available'));

      await tableProvider.swapTables(tableA, tableB);

      // After swap: Table 10 should be Available, Table 20 should be Occupied with INV-100
      final updatedTableA = tableProvider.tables.firstWhere((t) => t.id == 10);
      final updatedTableB = tableProvider.tables.firstWhere((t) => t.id == 20);

      expect(updatedTableA.status, equals('Available'));
      expect(updatedTableA.activeInvoiceNumber, isNull);

      expect(updatedTableB.status, equals('Occupied'));
      expect(updatedTableB.activeInvoiceNumber, equals('INV-100'));
    });
  });

  group('SwapTableDialog UI Test', () {
    Widget buildTestWidget() {
      return MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => SwapTableDialog.show(
                context,
                posProvider: posProvider,
                tableProvider: tableProvider,
                initialSourceTable: tableA,
              ),
              child: const Text('Open Swap Dialog'),
            ),
          ),
        ),
      );
    }

    testWidgets('Opens dialog, shows source and destination, and performs swap', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Prepare order on Table A
      posProvider.selectTable(tableA);
      posProvider.addToCart(testProduct);

      await tester.pumpWidget(buildTestWidget());
      await tester.tap(find.text('Open Swap Dialog'));
      await tester.pumpAndSettle();

      // Verify Dialog header
      expect(find.text('Swap Table Orders'), findsOneWidget);
      expect(find.text('FROM TABLE (SOURCE)'), findsOneWidget);
      expect(find.text('TO TABLE (DESTINATION)'), findsOneWidget);
      expect(find.text('Confirm Swap Orders'), findsOneWidget);

      // Tap Confirm Swap Orders
      await tester.tap(find.text('Confirm Swap Orders'));
      await tester.pumpAndSettle();

      // Dialog is dismissed
      expect(find.text('Swap Table Orders'), findsNothing);

      // Verify POS provider switched selected table to Table B
      expect(posProvider.selectedTable?.id, equals(tableB.id));
      expect(posProvider.cart.first.productName, equals('Espresso Double'));
    });
  });
}
