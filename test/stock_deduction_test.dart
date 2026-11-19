import 'package:flutter_test/flutter_test.dart';
import 'package:cafe_flow/services/milk_conversion_service.dart';
import 'package:cafe_flow/services/stock_deduction_service.dart';
import 'package:cafe_flow/services/unit_conversion_service.dart';

void main() {
  group('MilkConversionService Tests', () {
    test('calculateMilkDeductionKg calculates correct kg for 5 cups/kg ratio', () {
      // 1 cup of Full Tea at 5.0 cups/kg ratio = 0.200 kg
      final kg = MilkConversionService.calculateMilkDeductionKg(
        milkCupsPerKg: 5.0,
        teaTypeRatioKey: 'Full Tea',
        quantity: 1,
      );
      expect(kg, closeTo(0.200, 0.001));

      // 2 cups of Full Tea = 0.400 kg
      final kg2 = MilkConversionService.calculateMilkDeductionKg(
        milkCupsPerKg: 5.0,
        teaTypeRatioKey: 'Full Tea',
        quantity: 2,
      );
      expect(kg2, closeTo(0.400, 0.001));

      // 1 cup of Half Tea (50% dose) = 0.100 kg
      final halfKg = MilkConversionService.calculateMilkDeductionKg(
        milkCupsPerKg: 5.0,
        teaTypeRatioKey: 'Half Tea',
        quantity: 1,
      );
      expect(halfKg, closeTo(0.100, 0.001));

      // 1 cup of Special Tea (150% dose) = 0.300 kg
      final specialKg = MilkConversionService.calculateMilkDeductionKg(
        milkCupsPerKg: 5.0,
        teaTypeRatioKey: 'Special Tea',
        quantity: 1,
      );
      expect(specialKg, closeTo(0.300, 0.001));
    });

    test('calculateEstimatedCupsLeft calculates correct remaining cups', () {
      // 10 kg milk at 5 cups/kg = 50 cups
      final cups = MilkConversionService.calculateEstimatedCupsLeft(10.0, 5.0);
      expect(cups, equals(50));
    });
  });

  group('StockDeductionService Beverage Detection Tests', () {
    final service = StockDeductionService();

    test('isMilkBeverage correctly identifies milk-based drinks', () {
      expect(service.isMilkBeverage('Full Tea Chai'), isTrue);
      expect(service.isMilkBeverage('Special Doodh Patti'), isTrue);
      expect(service.isMilkBeverage('Cappuccino'), isTrue);
      expect(service.isMilkBeverage('Latte'), isTrue);

      // Non-milk drinks
      expect(service.isMilkBeverage('Black Tea'), isFalse);
      expect(service.isMilkBeverage('Green Tea'), isFalse);
      expect(service.isMilkBeverage('Lemon Tea'), isFalse);
      expect(service.isMilkBeverage('Mineral Water'), isFalse);
      expect(service.isMilkBeverage('Cold Drinks 500ml'), isFalse);
    });

    test('getTeaPortionKey correctly extracts tea types', () {
      expect(service.getTeaPortionKey('Half Tea'), equals('Half Tea'));
      expect(service.getTeaPortionKey('Large Tea'), equals('Large Tea'));
      expect(service.getTeaPortionKey('Special Doodh Patti'), equals('Special Tea'));
      expect(service.getTeaPortionKey('Full Tea Karak'), equals('Full Tea'));
    });
  });

  group('DepletedStockItem & Out of Stock Models Tests', () {
    test('DepletedStockItem correctly calculates shortage when stock is zero or depleted', () {
      final depleted = DepletedStockItem(
        stockId: 10,
        stockName: 'Cold Drink 500ml',
        currentStock: 0.0,
        requiredStock: 2.0,
        unit: 'pcs',
      );

      expect(depleted.stockId, equals(10));
      expect(depleted.stockName, equals('Cold Drink 500ml'));
      expect(depleted.currentStock, equals(0.0));
      expect(depleted.requiredStock, equals(2.0));
      expect(depleted.shortage, equals(2.0));
    });

    test('DepletedStockItem shortage does not go negative when current stock is higher', () {
      final item = DepletedStockItem(
        stockId: 11,
        stockName: 'Fresh Milk',
        currentStock: 5.0,
        requiredStock: 3.0,
        unit: 'KG',
      );

      expect(item.shortage, equals(0.0));
    });

    test('ProductStockCheckResult handles depleted items and availability correctly', () {
      final depletedItem = DepletedStockItem(
        stockId: 5,
        stockName: 'Beef Patty',
        currentStock: 0.0,
        requiredStock: 1.0,
        unit: 'Piece',
      );

      final unavailableResult = ProductStockCheckResult(
        isAvailable: false,
        depletedItems: [depletedItem],
        message: 'Stock khatam ho gaya hai.',
      );

      expect(unavailableResult.isAvailable, isFalse);
      expect(unavailableResult.depletedItems.length, equals(1));
      expect(unavailableResult.depletedItems.first.stockName, equals('Beef Patty'));

      final availableResult = ProductStockCheckResult(isAvailable: true);
      expect(availableResult.isAvailable, isTrue);
      expect(availableResult.depletedItems, isEmpty);
    });

    test('StockDeductionResult returns failure when out of stock preventing negative stock', () {
      final failure = StockDeductionResult(
        success: false,
        errorMessage: 'Bill generate nahi ho sakta kyunke stock khatam ho chuka hai.',
      );

      expect(failure.success, isFalse);
      expect(failure.errorMessage, contains('stock khatam'));
    });
  });

  group('UnitConversionService Recipe & Stock Conversion Tests', () {
    test('Converts gram to kg accurately (Chai & Roll recipes)', () {
      // Chai: 200 Gram Milk -> 0.20 KG
      final milkKg = UnitConversionService.convertQuantity(
        quantity: 200,
        fromUnit: 'Gram',
        toUnit: 'KG',
      );
      expect(milkKg, closeTo(0.20, 0.0001));

      // Chai: 15 Gram Mezban -> 0.015 KG
      final mezbanKg = UnitConversionService.convertQuantity(
        quantity: 15,
        fromUnit: 'Gram',
        toUnit: 'KG',
      );
      expect(mezbanKg, closeTo(0.015, 0.0001));

      // Chai: 13.5 Gram Danedar -> 0.0135 KG
      final danedarKg = UnitConversionService.convertQuantity(
        quantity: 13.5,
        fromUnit: 'Gram',
        toUnit: 'KG',
      );
      expect(danedarKg, closeTo(0.0135, 0.0001));

      // Chai: 40 Gram Sugar -> 0.040 KG
      final sugarKg = UnitConversionService.convertQuantity(
        quantity: 40,
        fromUnit: 'Gram',
        toUnit: 'KG',
      );
      expect(sugarKg, closeTo(0.040, 0.0001));

      // Roll: 83.3 Gram Boneless Chicken -> 0.0833 KG
      final chickenKg = UnitConversionService.convertQuantity(
        quantity: 83.3,
        fromUnit: 'Gram',
        toUnit: 'KG',
      );
      expect(chickenKg, closeTo(0.0833, 0.0001));

      // Roll: 1 Paratha (Piece) -> 1 Piece
      final parathaPcs = UnitConversionService.convertQuantity(
        quantity: 1,
        fromUnit: 'Piece',
        toUnit: 'Piece',
      );
      expect(parathaPcs, equals(1.0));
    });

    test('Converts kg to gram, ml to litre, and handles liquids', () {
      expect(UnitConversionService.convertQuantity(quantity: 0.5, fromUnit: 'kg', toUnit: 'gram'), closeTo(500.0, 0.001));
      expect(UnitConversionService.convertQuantity(quantity: 250, fromUnit: 'ml', toUnit: 'litre'), closeTo(0.25, 0.001));
      expect(UnitConversionService.convertQuantity(quantity: 200, fromUnit: 'gram', toUnit: 'litre'), closeTo(0.20, 0.001));
      expect(UnitConversionService.convertQuantity(quantity: 1, fromUnit: 'dozen', toUnit: 'piece'), equals(12.0));
    });

    test('Formats stock quantities cleanly without trailing zeroes', () {
      expect(UnitConversionService.formatQuantity(5.0), equals('5'));
      expect(UnitConversionService.formatQuantity(0.2000), equals('0.2'));
      expect(UnitConversionService.formatQuantity(83.3), equals('83.3'));
      expect(UnitConversionService.formatQuantity(0.0833), equals('0.0833'));
    });
  });
}

