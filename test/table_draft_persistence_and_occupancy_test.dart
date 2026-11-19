import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:cafe_flow/models/cafe_table_model.dart';
import 'package:cafe_flow/models/product_model.dart';
import 'package:cafe_flow/models/table_draft_model.dart';
import 'package:cafe_flow/providers/pos_provider.dart';
import 'package:cafe_flow/providers/table_provider.dart';
import 'package:cafe_flow/providers/settings_provider.dart';
import 'package:cafe_flow/providers/waiter_provider.dart';
import 'package:cafe_flow/providers/dashboard_provider.dart';
import 'package:cafe_flow/providers/sale_session_provider.dart';
import 'package:cafe_flow/providers/stock_provider.dart';
import 'package:cafe_flow/repositories/table_draft_repository.dart';
import 'package:cafe_flow/repositories/table_repository.dart';
import 'package:cafe_flow/widgets/pos_table_selection_dialog.dart';

/// In-memory mock for TableDraftRepository for unit & widget tests
class FakeTableDraftRepository extends TableDraftRepository {
  final Map<int, TableDraftModel> _drafts = {};

  @override
  Future<void> saveDraft(TableDraftModel draft) async {
    _drafts[draft.tableId] = draft;
  }

  @override
  Future<void> deleteDraft(int tableId) async {
    _drafts.remove(tableId);
  }

  @override
  Future<void> clearAllDrafts() async {
    _drafts.clear();
  }

  @override
  Future<List<TableDraftModel>> getAllDrafts() async {
    return _drafts.values.toList();
  }

  @override
  Future<TableDraftModel?> getDraft(int tableId) async {
    return _drafts[tableId];
  }

  @override
  Future<void> swapDrafts(int tableIdA, int tableIdB) async {
    final a = _drafts.remove(tableIdA);
    final b = _drafts.remove(tableIdB);
    if (a != null) {
      _drafts[tableIdB] = TableDraftModel(
        tableId: tableIdB,
        waiterId: a.waiterId,
        waiterName: a.waiterName,
        customerName: a.customerName,
        customerPhone: a.customerPhone,
        orderType: a.orderType,
        discountAmount: a.discountAmount,
        paymentMethod: a.paymentMethod,
        tokenNumber: a.tokenNumber,
        items: a.items,
        kitchenPrintedItems: a.kitchenPrintedItems,
        updatedAt: DateTime.now().toIso8601String(),
      );
    }
    if (b != null) {
      _drafts[tableIdA] = TableDraftModel(
        tableId: tableIdA,
        waiterId: b.waiterId,
        waiterName: b.waiterName,
        customerName: b.customerName,
        customerPhone: b.customerPhone,
        orderType: b.orderType,
        discountAmount: b.discountAmount,
        paymentMethod: b.paymentMethod,
        tokenNumber: b.tokenNumber,
        items: b.items,
        kitchenPrintedItems: b.kitchenPrintedItems,
        updatedAt: DateTime.now().toIso8601String(),
      );
    }
  }
}

/// Fake TableRepository for testing table status update
class FakeTableRepository extends TableRepository {
  final Map<int, String> tableStatuses = {};

  @override
  Future<void> updateTableStatus({
    required int tableId,
    required String status,
    String? invoiceNumber,
  }) async {
    tableStatuses[tableId] = status;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testProductChai = ProductModel(
    id: 101,
    name: 'Karak Chai',
    categoryId: 1,
    sellingPrice: 120.0,
    costPrice: 40.0,
  );

  final testProductParatha = ProductModel(
    id: 102,
    name: 'Aloo Paratha',
    categoryId: 1,
    sellingPrice: 200.0,
    costPrice: 80.0,
  );

  final table1 = CafeTableModel(
    id: 1,
    sectionId: 1,
    sectionName: 'Main Hall',
    tableName: 'Table 1',
    capacity: 4,
    status: 'Available',
  );

  final table2 = CafeTableModel(
    id: 2,
    sectionId: 1,
    sectionName: 'Main Hall',
    tableName: 'Table 2',
    capacity: 6,
    status: 'Available',
  );

  group('Table Draft Occupancy & Persistence Tests', () {
    test('Adding item to table cart persists draft and marks table Occupied', () async {
      final fakeDraftRepo = FakeTableDraftRepository();
      final fakeTableRepo = FakeTableRepository();

      final posProvider = PosProvider(
        draftRepository: fakeDraftRepo,
        tableRepository: fakeTableRepo,
        autoLoadDrafts: false,
      );

      // Select Table 1 and add items
      posProvider.selectTable(table1);
      posProvider.addToCart(testProductChai);
      posProvider.addToCart(testProductParatha);

      // Verify in-memory cart
      expect(posProvider.cart.length, 2);
      expect(posProvider.cart[0].productName, 'Karak Chai');
      expect(posProvider.cart[1].productName, 'Aloo Paratha');

      // Verify persisted draft in repository
      final savedDraft = await fakeDraftRepo.getDraft(1);
      expect(savedDraft, isNotNull);
      expect(savedDraft!.items.length, 2);
      expect(savedDraft.items[0].productName, 'Karak Chai');
      expect(savedDraft.items[1].productName, 'Aloo Paratha');

      // Verify table status was updated to Occupied
      expect(fakeTableRepo.tableStatuses[1], 'Occupied');
    });

    test('Closing & reopening software restores all items on the table intact', () async {
      final sharedFakeDraftRepo = FakeTableDraftRepository();
      final fakeTableRepo = FakeTableRepository();

      // Session 1: User selects Table 2, adds items, then closes app
      {
        final session1PosProvider = PosProvider(
          draftRepository: sharedFakeDraftRepo,
          tableRepository: fakeTableRepo,
          autoLoadDrafts: false,
        );

        session1PosProvider.selectTable(table2);
        session1PosProvider.addToCart(testProductChai);
        session1PosProvider.addToCart(testProductChai); // 2x Chai
        session1PosProvider.addToCart(testProductParatha); // 1x Paratha

        expect(session1PosProvider.cart.length, 2);
        expect(session1PosProvider.cart[0].quantity, 2);
        // App closes! (session1PosProvider is discarded)
      }

      // Session 2: User opens software afresh
      {
        final session2PosProvider = PosProvider(
          draftRepository: sharedFakeDraftRepo,
          tableRepository: fakeTableRepo,
          autoLoadDrafts: true,
        );

        // Wait for drafts to load
        await session2PosProvider.loadSavedTableDrafts();

        // Check that Table 2's cart is fully restored
        expect(session2PosProvider.tableCarts.containsKey(2), isTrue);
        final table2Items = session2PosProvider.tableCarts[2]!;
        expect(table2Items.length, 2);
        expect(table2Items[0].productName, 'Karak Chai');
        expect(table2Items[0].quantity, 2);
        expect(table2Items[1].productName, 'Aloo Paratha');
        expect(table2Items[1].quantity, 1);

        // Cashier selects Table 2 in POS
        session2PosProvider.selectTable(table2);
        expect(session2PosProvider.cart.length, 2);
        expect(session2PosProvider.cart[0].productName, 'Karak Chai');
        expect(session2PosProvider.cart[0].quantity, 2);
        expect(session2PosProvider.cart[1].productName, 'Aloo Paratha');
        expect(session2PosProvider.subtotal, (120.0 * 2) + 200.0);
      }
    });

    testWidgets('Table with draft items displays OCCUPIED badge, soft red color, and item count', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeDraftRepo = FakeTableDraftRepository();
      final fakeTableRepo = FakeTableRepository();

      final posProvider = PosProvider(
        draftRepository: fakeDraftRepo,
        tableRepository: fakeTableRepo,
        autoLoadDrafts: false,
      );

      final section = TableSectionModel(id: 1, name: 'Main Hall', sortOrder: 1);
      final tableProvider = TableProvider(autoLoad: false);
      tableProvider.setTablesAndSections(
        sections: [section],
        tables: [table1, table2],
      );

      // Table 1 has items added (draft), Table 2 has no items
      posProvider.selectTable(table1);
      posProvider.addToCart(testProductChai);
      posProvider.addToCart(testProductParatha);

      Widget buildWidget() {
        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => SettingsProvider()),
            ChangeNotifierProvider(create: (_) => WaiterProvider()),
            ChangeNotifierProvider(create: (_) => DashboardProvider()),
            ChangeNotifierProvider(create: (_) => SaleSessionProvider()),
            ChangeNotifierProvider(create: (_) => StockProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => PosTableSelectionDialog.show(
                    context,
                    posProvider: posProvider,
                    tableProvider: tableProvider,
                  ),
                  child: const Text('Open Tables'),
                ),
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildWidget());
      await tester.tap(find.text('Open Tables'));
      await tester.pumpAndSettle();

      // Table 1 should display 'OCCUPIED' and '2 items'
      expect(find.text('Table 1'), findsOneWidget);
      expect(find.text('OCCUPIED'), findsOneWidget);
      expect(find.textContaining('2 items'), findsOneWidget);

      // Table 2 is still available
      expect(find.text('Table 2'), findsOneWidget);
      expect(find.text('AVAILABLE'), findsOneWidget);

      // Tapping Table 1 opens the draft preview prompt showing items
      await tester.tap(find.text('Table 1'));
      await tester.pumpAndSettle();

      // Verify prompt shows Active Draft Order and items
      expect(find.textContaining('Active Draft Order'), findsOneWidget);
      expect(find.text('Karak Chai'), findsOneWidget);
      expect(find.text('Aloo Paratha'), findsOneWidget);
      expect(find.text('Switch to Table'), findsOneWidget);
      expect(find.text('Clear Table'), findsOneWidget);

      // Tapping Switch to Table closes dialog
      await tester.tap(find.text('Switch to Table'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(posProvider.selectedTable?.id, 1);
      expect(posProvider.cart.length, 2);
    });
  });
}
