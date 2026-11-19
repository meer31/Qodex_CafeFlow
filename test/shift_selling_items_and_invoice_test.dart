import 'package:flutter_test/flutter_test.dart';
import 'package:cafe_flow/models/sale_session_model.dart';
import 'package:cafe_flow/models/sale_model.dart';

void main() {
  group('Shift Selling Items Breakdown Tests', () {
    test('SessionSoldItem correctly computes unitPrice and totalRevenue for cups sold', () {
      final chaiItem = SessionSoldItem(
        productId: 1,
        productName: 'Chai',
        quantity: 25, // 25 cups
        unitPrice: 60.0, // Rs. 60 per cup
        totalRevenue: 1500.0, // Rs. 1500 total
        totalCost: 750.0,
      );

      expect(chaiItem.productName, equals('Chai'));
      expect(chaiItem.quantity, equals(25));
      expect(chaiItem.unitPrice, equals(60.0));
      expect(chaiItem.totalRevenue, equals(1500.0));

      final map = chaiItem.toMap();
      expect(map['product_name'], equals('Chai'));
      expect(map['quantity'], equals(25));
      expect(map['unit_price'], equals(60.0));
      expect(map['total_revenue'], equals(1500.0));

      final fromMapItem = SessionSoldItem.fromMap(map);
      expect(fromMapItem.productName, equals('Chai'));
      expect(fromMapItem.quantity, equals(25));
      expect(fromMapItem.unitPrice, equals(60.0));
      expect(fromMapItem.totalRevenue, equals(1500.0));
    });

    test('Aggregates multiple items sold in a shift with total quantities and revenues', () {
      final items = [
        SessionSoldItem(
          productId: 1,
          productName: 'Chai',
          quantity: 40,
          unitPrice: 50.0,
          totalRevenue: 2000.0,
        ),
        SessionSoldItem(
          productId: 2,
          productName: 'Special Coffee',
          quantity: 15,
          unitPrice: 120.0,
          totalRevenue: 1800.0,
        ),
        SessionSoldItem(
          productId: 3,
          productName: 'Chicken Samosa',
          quantity: 30,
          unitPrice: 40.0,
          totalRevenue: 1200.0,
        ),
      ];

      final totalCupsSold = items.fold<int>(0, (sum, i) => sum + i.quantity);
      final totalRevenue = items.fold<double>(0.0, (sum, i) => sum + i.totalRevenue);

      expect(totalCupsSold, equals(85));
      expect(totalRevenue, equals(5000.0));

      // Sorted by quantity descending
      items.sort((a, b) => b.quantity.compareTo(a.quantity));
      expect(items.first.productName, equals('Chai'));
      expect(items.first.quantity, equals(40));
    });
  });

  group('Shift Invoice Numbering Tests', () {
    test('New shift starts invoice sequence from 1', () {
      // Simulating invoices in a newly started shift
      final List<String> existingInvoicesInShift = [];

      int calculateNextInvoice(List<String> invoices) {
        int maxSeq = 0;
        for (var inv in invoices) {
          final p = int.tryParse(inv);
          if (p != null && p > maxSeq) {
            maxSeq = p;
          }
        }
        return maxSeq + 1;
      }

      // 1. Shift just started -> first invoice must be 1
      expect(calculateNextInvoice(existingInvoicesInShift).toString(), equals('1'));

      // 2. After invoice 1 created -> next is 2
      existingInvoicesInShift.add('1');
      expect(calculateNextInvoice(existingInvoicesInShift).toString(), equals('2'));

      // 3. After invoice 2 created -> next is 3
      existingInvoicesInShift.add('2');
      expect(calculateNextInvoice(existingInvoicesInShift).toString(), equals('3'));

      // 4. In a separate new shift later on -> starts again from 1
      final List<String> nextShiftInvoices = [];
      expect(calculateNextInvoice(nextShiftInvoices).toString(), equals('1'));
    });
  });

  group('Dashboard Active Shift Top Selling Items Tests', () {
    test('Top selling items mapping correctly formats name, qty sold, rate, and revenue', () {
      final shiftSold = [
        SessionSoldItem(
          productId: 10,
          productName: 'Karak Chai',
          quantity: 65,
          unitPrice: 50.0,
          totalRevenue: 3250.0,
        ),
        SessionSoldItem(
          productId: 11,
          productName: 'Cappuccino',
          quantity: 20,
          unitPrice: 180.0,
          totalRevenue: 3600.0,
        ),
      ];

      final topSellingItems = shiftSold.map((e) => {
        'name': e.productName,
        'qty': e.quantity,
        'unit_price': e.unitPrice,
        'total_revenue': e.totalRevenue,
      }).toList();

      expect(topSellingItems.length, equals(2));
      expect(topSellingItems[0]['name'], equals('Karak Chai'));
      expect(topSellingItems[0]['qty'], equals(65));
      expect(topSellingItems[0]['unit_price'], equals(50.0));
      expect(topSellingItems[0]['total_revenue'], equals(3250.0));

      expect(topSellingItems[1]['name'], equals('Cappuccino'));
      expect(topSellingItems[1]['qty'], equals(20));
      expect(topSellingItems[1]['unit_price'], equals(180.0));
      expect(topSellingItems[1]['total_revenue'], equals(3600.0));
    });
  });
}
