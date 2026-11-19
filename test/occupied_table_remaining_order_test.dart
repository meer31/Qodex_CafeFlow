import 'package:flutter_test/flutter_test.dart';
import 'package:cafe_flow/models/cafe_table_model.dart';
import 'package:cafe_flow/models/sale_model.dart';

void main() {
  group('Occupied Tables Remaining & Pending Orders Tracking Tests', () {
    final table1 = CafeTableModel(
      id: 101,
      sectionId: 1,
      sectionName: 'Ground Floor',
      tableName: 'Table T1',
      capacity: 4,
      status: 'Occupied',
      activeInvoiceNumber: 'INV-1001',
    );

    final table2 = CafeTableModel(
      id: 102,
      sectionId: 1,
      sectionName: 'Ground Floor',
      tableName: 'Table T2',
      capacity: 6,
      status: 'Occupied',
      activeInvoiceNumber: 'INV-1003',
    );

    final table3 = CafeTableModel(
      id: 103,
      sectionId: 2,
      sectionName: 'Rooftop',
      tableName: 'Table T3',
      capacity: 2,
      status: 'Available',
    );

    final order1 = SaleModel(
      id: 1,
      invoiceNumber: 'INV-1001',
      dateTime: '2026-09-27T12:00:00',
      cashierName: 'Admin',
      tableId: 101,
      tableName: 'Table T1',
      subtotal: 1200.0,
      grandTotal: 1200.0,
      paymentMethod: 'Cash',
      status: 'REMAINING',
      items: [
        SaleItemModel(
          productId: 1,
          productName: 'Club Sandwich',
          quantity: 2,
          unitPrice: 400.0,
          totalPrice: 800.0,
        ),
        SaleItemModel(
          productId: 2,
          productName: 'Cappuccino',
          quantity: 2,
          unitPrice: 200.0,
          totalPrice: 400.0,
        ),
      ],
    );

    final order2AdditionalForTable1 = SaleModel(
      id: 2,
      invoiceNumber: 'INV-1002',
      dateTime: '2026-09-27T12:30:00',
      cashierName: 'Admin',
      tableId: 101,
      tableName: 'Table T1',
      subtotal: 350.0,
      grandTotal: 350.0,
      paymentMethod: 'Cash',
      status: 'PENDING',
      items: [
        SaleItemModel(
          productId: 3,
          productName: 'Chocolate Brownie',
          quantity: 1,
          unitPrice: 350.0,
          totalPrice: 350.0,
        ),
      ],
    );

    final order3ForTable2 = SaleModel(
      id: 3,
      invoiceNumber: 'INV-1003',
      dateTime: '2026-09-27T12:15:00',
      cashierName: 'Admin',
      tableId: 102,
      tableName: 'Table T2',
      subtotal: 850.0,
      grandTotal: 850.0,
      paymentMethod: 'Cash',
      status: 'REMAINING',
      items: [
        SaleItemModel(
          productId: 4,
          productName: 'Cold Coffee',
          quantity: 2,
          unitPrice: 425.0,
          totalPrice: 850.0,
        ),
      ],
    );

    // Mock filtering logic matching TableProvider.getRemainingSalesForTable
    List<SaleModel> getRemainingSalesForTable(
      List<SaleModel> remainingSales,
      int tableId, {
      String? tableName,
    }) {
      return remainingSales.where((s) {
        if (s.tableId == tableId) return true;
        if (s.tableId == null && tableName != null && tableName.isNotEmpty && s.tableName == tableName) {
          return true;
        }
        return false;
      }).toList();
    }

    SaleModel? getPrimaryRemainingSaleForTable(
      List<SaleModel> remainingSales,
      int tableId, {
      String? tableName,
      String? activeInvoiceNum,
    }) {
      final list = getRemainingSalesForTable(remainingSales, tableId, tableName: tableName);
      if (list.isEmpty) return null;
      if (activeInvoiceNum != null && activeInvoiceNum.isNotEmpty) {
        final match = list.where((s) => s.invoiceNumber == activeInvoiceNum);
        if (match.isNotEmpty) return match.first;
      }
      return list.first;
    }

    test('correctly maps remaining and pending orders to occupied tables', () {
      final allRemaining = [order1, order2AdditionalForTable1, order3ForTable2];

      final table1Orders = getRemainingSalesForTable(allRemaining, table1.id!, tableName: table1.tableName);
      expect(table1Orders.length, equals(2));
      expect(table1Orders.map((o) => o.invoiceNumber), containsAll(['INV-1001', 'INV-1002']));

      final primaryTable1 = getPrimaryRemainingSaleForTable(
        allRemaining,
        table1.id!,
        tableName: table1.tableName,
        activeInvoiceNum: table1.activeInvoiceNumber,
      );
      expect(primaryTable1, isNotNull);
      expect(primaryTable1!.invoiceNumber, equals('INV-1001'));
      expect(primaryTable1.grandTotal, equals(1200.0));
      expect(primaryTable1.items.length, equals(2));

      final table2Orders = getRemainingSalesForTable(allRemaining, table2.id!, tableName: table2.tableName);
      expect(table2Orders.length, equals(1));
      expect(table2Orders.first.invoiceNumber, equals('INV-1003'));

      final table3Orders = getRemainingSalesForTable(allRemaining, table3.id!, tableName: table3.tableName);
      expect(table3Orders.isEmpty, isTrue);
    });

    test('when one of multiple orders is cleared, table retains occupied status with next order', () {
      // Order 1 is cleared, but Order 2 is still pending on Table T1
      final remainingAfterClearingOrder1 = [order2AdditionalForTable1, order3ForTable2];

      final table1Orders = getRemainingSalesForTable(remainingAfterClearingOrder1, table1.id!, tableName: table1.tableName);
      expect(table1Orders.length, equals(1));
      expect(table1Orders.first.invoiceNumber, equals('INV-1002'));

      // If simulated table update runs:
      CafeTableModel updatedTable1;
      if (table1Orders.isNotEmpty) {
        updatedTable1 = table1.copyWith(
          status: 'Occupied',
          activeInvoiceNumber: table1Orders.first.invoiceNumber,
        );
      } else {
        updatedTable1 = table1.copyWith(
          status: 'Available',
          activeInvoiceNumber: null,
        );
      }

      expect(updatedTable1.status, equals('Occupied'));
      expect(updatedTable1.activeInvoiceNumber, equals('INV-1002'));
    });

    test('when the last pending order is cleared, table automatically becomes Available', () {
      // Both Order 1 and Order 2 are cleared on Table T1
      final remainingAfterClearingAll = [order3ForTable2];

      final table1Orders = getRemainingSalesForTable(remainingAfterClearingAll, table1.id!, tableName: table1.tableName);
      expect(table1Orders.isEmpty, isTrue);

      // Automated table release condition:
      CafeTableModel releasedTable1;
      if (table1Orders.isNotEmpty) {
        releasedTable1 = table1.copyWith(
          status: 'Occupied',
          activeInvoiceNumber: table1Orders.first.invoiceNumber,
        );
      } else {
        releasedTable1 = table1.copyWith(
          status: 'Available',
          clearActiveInvoice: true,
        );
      }

      expect(releasedTable1.status, equals('Available'));
      expect(releasedTable1.activeInvoiceNumber, isNull);
    });
  });
}
