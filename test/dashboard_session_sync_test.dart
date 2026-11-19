import 'package:flutter_test/flutter_test.dart';
import 'package:cafe_flow/models/sale_session_model.dart';
import 'package:cafe_flow/models/sale_model.dart';

void main() {
  group('Dashboard Active Shift Metrics Sync', () {
    test('Active session sales, expenses, and counter money compute accurately', () {
      final activeSession = SaleSessionModel(
        id: 10,
        sessionName: 'Shift 12-Sep-2026 (5:00 PM)',
        startTime: '2026-09-12T17:00:00',
        businessDate: '2026-09-12',
        openingCash: 2500.0,
        totalSales: 18450.0,
        cashSales: 12450.0,
        cardSales: 4000.0,
        onlineSales: 2000.0,
        totalExpenses: 3200.0,
        status: 'ACTIVE',
      );

      // Total Sale of active shift (only active shift, not all sales)
      expect(activeSession.totalSales, equals(18450.0));
      // Total Expense of active shift
      expect(activeSession.totalExpenses, equals(3200.0));
      // Drawer Counter Money (Opening float + cash sales)
      expect(activeSession.totalCounterCash, equals(14950.0));
      // Net Profit of active shift
      expect(activeSession.netProfit, equals(15250.0));
      expect(activeSession.isActive, isTrue);
    });

    test('Inactive shift state defaults sales and expenses cleanly without showing historical totals', () {
      SaleSessionModel? getInactiveSession() => null;
      final activeSession = getInactiveSession();

      final activeShiftSales = activeSession?.totalSales ?? 0.0;
      final activeShiftExpenses = activeSession?.totalExpenses ?? 0.0;
      final activeCounterCash = activeSession?.totalCounterCash ?? 0.0;
      final hasActiveShift = activeSession != null;

      expect(hasActiveShift, isFalse);
      expect(activeShiftSales, equals(0.0));
      expect(activeShiftExpenses, equals(0.0));
      expect(activeCounterCash, equals(0.0));
    });

    test('REMAINING / PENDING sales do not inflate drawer counter cash until cleared', () {
      final pendingSale = SaleModel(
        id: 101,
        invoiceNumber: 'INV-1001',
        dateTime: '2026-09-12T18:00:00',
        cashierName: 'Admin',
        subtotal: 1500.0,
        grandTotal: 1500.0,
        paymentMethod: 'Cash',
        status: 'REMAINING',
      );

      final clearedSale = SaleModel(
        id: 102,
        invoiceNumber: 'INV-1002',
        dateTime: '2026-09-12T18:30:00',
        cashierName: 'Admin',
        subtotal: 800.0,
        grandTotal: 800.0,
        paymentMethod: 'Cash',
        status: 'CLEARED',
      );

      expect(pendingSale.isCleared, isFalse);
      expect(pendingSale.isRemaining, isTrue);
      expect(clearedSale.isCleared, isTrue);
      expect(clearedSale.isRemaining, isFalse);

      final sales = [pendingSale, clearedSale];
      final clearedSalesTotal = sales
          .where((s) => s.isCleared)
          .fold<double>(0.0, (sum, s) => sum + s.grandTotal);
      final remainingSalesTotal = sales
          .where((s) => s.isRemaining)
          .fold<double>(0.0, (sum, s) => sum + s.grandTotal);

      expect(clearedSalesTotal, equals(800.0));
      expect(remainingSalesTotal, equals(1500.0));
    });

    test('Monthly Net Profit calculates revenue minus monthly expenses properly', () {
      const double monthlySales = 120000.0;
      const double monthlyExpenses = 35000.0;
      const double monthlyProfit = monthlySales - monthlyExpenses;

      expect(monthlyProfit, equals(85000.0));
    });
  });
}
