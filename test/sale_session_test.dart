import 'package:flutter_test/flutter_test.dart';
import 'package:cafe_flow/models/sale_session_model.dart';
import 'package:cafe_flow/models/sale_model.dart';
import 'package:cafe_flow/models/expense_model.dart';

void main() {
  group('SaleSessionModel Financial Calculations', () {
    test('totalCounterCash correctly sums opening cash float and cash sales', () {
      // User scenario: Opening counter cash added for change = Rs. 5,000
      // Sales made in cash during the night = Rs. 25,400
      final session = SaleSessionModel(
        id: 1,
        sessionName: 'Shift 12-Sep-2026',
        startTime: '2026-09-12T17:00:00',
        businessDate: '2026-09-12',
        openingCash: 5000.0,
        cashSales: 25400.0,
        cardSales: 4000.0,
        onlineSales: 2000.0,
        totalSales: 31400.0,
        totalExpenses: 1400.0,
      );

      // Cashier counting counter money must have: 5,000 + 25,400 = 30,400
      expect(session.totalCounterCash, equals(30400.0));
      expect(session.totalSales, equals(31400.0));
      // Net profit = 31,400 - 1,400 = 30,000
      expect(session.netProfit, equals(30000.0));
      // Expected drawer cash after paying out Rs. 1,400 expenses = 30,400 - 1,400 = 29,000
      expect(session.expectedDrawerCash, equals(29000.0));
      expect(session.isActive, isTrue);
    });

    test('reconciliation detects zero cash difference on balanced drawer', () {
      final session = SaleSessionModel(
        id: 1,
        sessionName: 'Shift 12-Sep-2026',
        startTime: '2026-09-12T17:00:00',
        endTime: '2026-09-13T02:30:00',
        businessDate: '2026-09-12',
        openingCash: 5000.0,
        cashSales: 20000.0,
        totalSales: 20000.0,
        totalExpenses: 2000.0,
        status: 'CLOSED',
        // Expected drawer: (5,000 + 20,000) - 2,000 = 23,000
        closingCash: 23000.0,
      );

      expect(session.expectedDrawerCash, equals(23000.0));
      expect(session.cashDifference, equals(0.0));
      expect(session.isClosed, isTrue);
    });

    test('reconciliation detects cash discrepancy when money is short or excess', () {
      final shortSession = SaleSessionModel(
        sessionName: 'Shift',
        startTime: '2026-09-12T17:00:00',
        businessDate: '2026-09-12',
        openingCash: 1000.0,
        cashSales: 5000.0,
        totalExpenses: 500.0,
        // Expected: 5,500. Counted: 5,200 (Rs. 300 short)
        closingCash: 5200.0,
      );

      expect(shortSession.expectedDrawerCash, equals(5500.0));
      expect(shortSession.cashDifference, equals(-300.0));
    });

    test('cross-midnight time formatting renders proper 12-hour AM/PM labels', () {
      final session = SaleSessionModel(
        sessionName: 'Night Shift',
        startTime: '2026-09-12T17:00:00', // 5:00 PM
        endTime: '2026-09-13T02:30:00',   // 2:30 AM next calendar day
        businessDate: '2026-09-12',
      );

      expect(session.startTimeFormatted, equals('5:00 PM'));
      expect(session.endTimeFormatted, equals('2:30 AM'));
      // Business date stays anchored to starting date (12-Sep-2026)
      expect(session.businessDate, equals('2026-09-12'));
    });

    test('toMap and fromMap preserves all session fields and types', () {
      final session = SaleSessionModel(
        id: 42,
        sessionName: 'Friday Night',
        startTime: '2026-09-12T17:00:00',
        endTime: '2026-09-13T03:00:00',
        businessDate: '2026-09-12',
        openingCash: 8000.0,
        closingCash: 35000.0,
        totalSales: 45000.0,
        totalExpenses: 6000.0,
        cashSales: 33000.0,
        cardSales: 7000.0,
        onlineSales: 5000.0,
        status: 'CLOSED',
        notes: 'Smooth cross-midnight shift',
      );

      final map = session.toMap();
      final restored = SaleSessionModel.fromMap(map);

      expect(restored.id, equals(42));
      expect(restored.sessionName, equals('Friday Night'));
      expect(restored.startTime, equals('2026-09-12T17:00:00'));
      expect(restored.endTime, equals('2026-09-13T03:00:00'));
      expect(restored.businessDate, equals('2026-09-12'));
      expect(restored.openingCash, equals(8000.0));
      expect(restored.closingCash, equals(35000.0));
      expect(restored.totalSales, equals(45000.0));
      expect(restored.totalExpenses, equals(6000.0));
      expect(restored.cashSales, equals(33000.0));
      expect(restored.cardSales, equals(7000.0));
      expect(restored.onlineSales, equals(5000.0));
      expect(restored.status, equals('CLOSED'));
      expect(restored.notes, equals('Smooth cross-midnight shift'));
      expect(restored.totalCounterCash, equals(41000.0)); // 8,000 + 33,000
    });
  });

  group('Session Integration with Sales and Expenses', () {
    test('SaleModel correctly stores and associates sessionId', () {
      final sale = SaleModel(
        id: 10,
        invoiceNumber: '101',
        dateTime: '2026-09-13T01:45:00', // 1:45 AM during night shift
        subtotal: 1200.0,
        grandTotal: 1200.0,
        paymentMethod: 'Cash',
        cashierName: 'Admin',
        sessionId: 5,
        items: [],
      );

      final map = sale.toMap();
      expect(map['session_id'], equals(5));

      final restored = SaleModel.fromMap(map);
      expect(restored.sessionId, equals(5));
      expect(restored.invoiceNumber, equals('101'));
    });

    test('ExpenseModel correctly stores and associates sessionId', () {
      final expense = ExpenseModel(
        id: 7,
        title: 'Fresh Milk Supplier Night Delivery',
        amount: 3500.0,
        category: 'Supplies',
        dateTime: '2026-09-12T23:30:00',
        sessionId: 5,
      );

      final map = expense.toMap();
      expect(map['session_id'], equals(5));

      final restored = ExpenseModel.fromMap(map);
      expect(restored.sessionId, equals(5));
      expect(restored.amount, equals(3500.0));
    });
  });
}
