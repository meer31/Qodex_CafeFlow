import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:cafe_flow/models/cafe_table_model.dart';
import 'package:cafe_flow/models/sale_model.dart';
import 'package:cafe_flow/providers/pos_provider.dart';
import 'package:cafe_flow/providers/table_provider.dart';
import 'package:cafe_flow/providers/settings_provider.dart';
import 'package:cafe_flow/providers/waiter_provider.dart';
import 'package:cafe_flow/providers/dashboard_provider.dart';
import 'package:cafe_flow/providers/sale_session_provider.dart';
import 'package:cafe_flow/providers/stock_provider.dart';
import 'package:cafe_flow/widgets/pos_table_selection_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PosProvider posProvider;
  late TableProvider tableProvider;

  final sectionIndoor = TableSectionModel(id: 1, name: 'Indoor Hall', sortOrder: 1);
  final sectionOutdoor = TableSectionModel(id: 2, name: 'Outdoor Garden', sortOrder: 2);

  final table1Available = CafeTableModel(
    id: 1,
    sectionId: 1,
    sectionName: 'Indoor Hall',
    tableName: 'Table T1',
    capacity: 4,
    status: 'Available',
  );

  final table2Reserved = CafeTableModel(
    id: 2,
    sectionId: 2,
    sectionName: 'Outdoor Garden',
    tableName: 'Table T2',
    capacity: 6,
    status: 'Reserved',
  );

  final table3Occupied = CafeTableModel(
    id: 3,
    sectionId: 1,
    sectionName: 'Indoor Hall',
    tableName: 'Table T3',
    capacity: 2,
    status: 'Occupied',
    activeInvoiceNumber: 'INV-101',
  );

  setUp(() {
    posProvider = PosProvider();
    tableProvider = TableProvider(autoLoad: false);
    tableProvider.setTablesAndSections(
      sections: [sectionIndoor, sectionOutdoor],
      tables: [table1Available, table2Reserved, table3Occupied],
    );
  });

  Widget buildTestWidget() {
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
              child: const Text('Open Table Selector'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('Dialog displays sections in sidebar and square tables for active section', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestWidget());
    await tester.tap(find.text('Open Table Selector'));
    await tester.pumpAndSettle();

    // Verify Title & Sections
    expect(find.text('Select Dining Table'), findsOneWidget);
    expect(find.text('Takeaway / Counter'), findsOneWidget);
    expect(find.text('Indoor Hall'), findsWidgets);
    expect(find.text('Outdoor Garden'), findsWidgets);

    // Initial section is Indoor Hall -> Table T1 & Table T3 visible
    expect(find.text('Table T1'), findsOneWidget);
    expect(find.text('Table T3'), findsOneWidget);

    // Status labels
    expect(find.text('AVAILABLE'), findsWidgets);
    expect(find.text('OCCUPIED'), findsWidgets);
  });

  testWidgets('Tapping available table selects it and closes dialog', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestWidget());
    await tester.tap(find.text('Open Table Selector'));
    await tester.pumpAndSettle();

    // Tap on Table T1 (Available)
    await tester.tap(find.text('Table T1'));
    await tester.pumpAndSettle();

    // Dialog should be dismissed
    expect(find.text('Select Dining Table'), findsNothing);
    expect(posProvider.selectedTable?.id, equals(1));
    expect(posProvider.selectedTable?.tableName, equals('Table T1'));
  });

  testWidgets('Tapping Takeaway resets table selection to null and closes dialog', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    posProvider.selectTable(table1Available);
    expect(posProvider.selectedTable, isNotNull);

    await tester.pumpWidget(buildTestWidget());
    await tester.tap(find.text('Open Table Selector'));
    await tester.pumpAndSettle();

    // Tap Takeaway / Counter
    await tester.tap(find.text('Takeaway / Counter'));
    await tester.pumpAndSettle();

    expect(find.text('Select Dining Table'), findsNothing);
    expect(posProvider.selectedTable, isNull);
  });

  testWidgets('Filtering by section updates visible tables', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestWidget());
    await tester.tap(find.text('Open Table Selector'));
    await tester.pumpAndSettle();

    // Initially Indoor Hall tables are visible
    expect(find.text('Table T1'), findsOneWidget);
    expect(find.text('Table T3'), findsOneWidget);
    expect(find.text('Table T2'), findsNothing);

    // Tap Outdoor Garden section in sidebar
    final outdoorSectionInSidebar = find.descendant(
      of: find.byType(ListView),
      matching: find.text('Outdoor Garden'),
    );
    await tester.tap(outdoorSectionInSidebar);
    await tester.pumpAndSettle();

    // Only Table T2 (Outdoor Garden) should now be shown
    expect(find.text('Table T2'), findsOneWidget);
    expect(find.text('Table T1'), findsNothing);
    expect(find.text('Table T3'), findsNothing);
  });

  testWidgets('Tapping table with Delayed Bill displays dialog with total amount, See Invoice, Clear Bill, and Resume', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    // Configure a remaining sale for Table T3
    final testSale = SaleModel(
      id: 99,
      invoiceNumber: 'INV-101',
      dateTime: '2026-10-16T12:00:00',
      cashierName: 'Cashier 1',
      tableId: 3,
      tableName: 'Table T3',
      subtotal: 500.0,
      discount: 0.0,
      tax: 0.0,
      grandTotal: 500.0,
      totalCost: 200.0,
      paymentMethod: 'Cash',
      status: 'REMAINING',
      items: [
        SaleItemModel(productId: 1, productName: 'Karak Chai', quantity: 2, unitPrice: 150.0, unitCost: 50.0, totalPrice: 300.0),
        SaleItemModel(productId: 2, productName: 'Chicken Roll', quantity: 1, unitPrice: 200.0, unitCost: 100.0, totalPrice: 200.0),
      ],
    );

    tableProvider.setRemainingSales([testSale]);

    await tester.pumpWidget(buildTestWidget());
    await tester.tap(find.text('Open Table Selector'));
    await tester.pumpAndSettle();

    // T3 should have a DELAYED BILL badge and amount
    expect(find.text('DELAYED BILL'), findsWidgets);
    expect(find.textContaining('500'), findsWidgets);

    // Tap Table T3
    await tester.tap(find.text('Table T3'));
    await tester.pumpAndSettle();

    // Dialog should show invoice # and total bill amount
    expect(find.text('Invoice #INV-101'), findsWidgets);
    expect(find.textContaining('500.00'), findsWidgets);
    expect(find.text('Total Due Amount: Rs. 500.00'), findsOneWidget);

    // Dialog should have "See Invoice" and "Clear Bill" and "Switch to Table" buttons
    expect(find.text('See Invoice'), findsOneWidget);
    expect(find.text('Clear Bill'), findsOneWidget);
    expect(find.text('Switch to Table'), findsOneWidget);
    expect(find.text('Swap Order'), findsOneWidget);

    // Tap "Switch to Table" to resume order
    await tester.tap(find.text('Switch to Table'));
    await tester.pumpAndSettle();

    // Dialog should be dismissed, and posProvider should have loaded items without loss!
    expect(find.text('Select Dining Table'), findsNothing);
    expect(posProvider.isEditingInvoice, isTrue);
    expect(posProvider.selectedTable?.tableName, equals('Table T3'));
    expect(posProvider.cart.length, equals(2));
    expect(posProvider.cart[0].productName, equals('Karak Chai'));
    expect(posProvider.cart[1].productName, equals('Chicken Roll'));
  });
}
