class UnitConversionService {
  // ── Metric Factors (Normalized to grams / milliliters) ──
  // In culinary / cafe management, 1000g = 1000ml = 1kg = 1L
  static const Map<String, double> _metricFactors = {
    // Mass / Weight
    'kg': 1000.0,
    'kilogram': 1000.0,
    'kilograms': 1000.0,
    'kgs': 1000.0,
    'g': 1.0,
    'gram': 1.0,
    'grams': 1.0,
    'gm': 1.0,
    'gms': 1.0,
    'mg': 0.001,
    'milligram': 0.001,
    'milligrams': 0.001,
    'lb': 453.592,
    'lbs': 453.592,
    'pound': 453.592,
    'pounds': 453.592,
    'oz': 28.3495,
    'ounce': 28.3495,
    'ounces': 28.3495,

    // Volume / Liquids
    'l': 1000.0,
    'liter': 1000.0,
    'litre': 1000.0,
    'liters': 1000.0,
    'litres': 1000.0,
    'ltr': 1000.0,
    'ltrs': 1000.0,
    'ml': 1.0,
    'milliliter': 1.0,
    'millilitre': 1.0,
    'milliliters': 1.0,
    'millilitres': 1.0,
    'cup': 250.0,
    'cups': 250.0,
    'tbsp': 15.0,
    'tablespoon': 15.0,
    'tablespoons': 15.0,
    'tsp': 5.0,
    'teaspoon': 5.0,
    'teaspoons': 5.0,
  };

  // ── Discrete / Count Factors (Normalized to single piece) ──
  static const Map<String, double> _countFactors = {
    'piece': 1.0,
    'pieces': 1.0,
    'pcs': 1.0,
    'pc': 1.0,
    'item': 1.0,
    'items': 1.0,
    'unit': 1.0,
    'units': 1.0,
    'slice': 1.0,
    'slices': 1.0,
    'packet': 1.0,
    'packets': 1.0,
    'pkt': 1.0,
    'pack': 1.0,
    'packs': 1.0,
    'plate': 1.0,
    'plates': 1.0,
    'portion': 1.0,
    'portions': 1.0,
    'bottle': 1.0,
    'bottles': 1.0,
    'can': 1.0,
    'cans': 1.0,
    'box': 1.0,
    'boxes': 1.0,
    'dozen': 12.0,
    'dozens': 12.0,
    'dz': 12.0,
    'half dozen': 6.0,
    'half-dozen': 6.0,
  };

  /// Normalizes a unit string for lookup
  static String normalizeUnit(String unit) {
    return unit.trim().toLowerCase();
  }

  /// Converts a [quantity] from [fromUnit] to [toUnit].
  ///
  /// Examples:
  /// - 200 Gram to KG => 0.20 KG
  /// - 83.3 Gram to KG => 0.0833 KG
  /// - 15 Gram to KG => 0.015 KG
  /// - 0.5 KG to Gram => 500.0 Gram
  /// - 250 ML to Litre => 0.25 Litre
  /// - 200 Gram to Litre (Milk/Liquid) => 0.20 Litre
  /// - 1 Dozen to Piece => 12.0 Piece
  /// - 1 Piece to Piece => 1.0 Piece
  ///
  /// If units cannot be converted directly, returns [quantity] as fallback.
  static double convertQuantity({
    required double quantity,
    required String fromUnit,
    required String toUnit,
  }) {
    if (quantity == 0.0) return 0.0;

    final from = normalizeUnit(fromUnit);
    final to = normalizeUnit(toUnit);

    if (from.isEmpty || to.isEmpty || from == to) {
      return quantity;
    }

    // 1. Metric conversion (Mass & Volume cross-compatible for cafe culinary usage)
    if (_metricFactors.containsKey(from) && _metricFactors.containsKey(to)) {
      final baseAmount = quantity * _metricFactors[from]!;
      final converted = baseAmount / _metricFactors[to]!;
      return converted;
    }

    // 2. Count / Discrete conversion
    if (_countFactors.containsKey(from) && _countFactors.containsKey(to)) {
      final basePieces = quantity * _countFactors[from]!;
      final converted = basePieces / _countFactors[to]!;
      return converted;
    }

    // Mismatched or custom user-defined unit: Fallback 1:1
    return quantity;
  }

  /// Checks if two units belong to the same convertible family
  static bool areUnitsCompatible(String unit1, String unit2) {
    final u1 = normalizeUnit(unit1);
    final u2 = normalizeUnit(unit2);

    if (u1 == u2) return true;
    if (_metricFactors.containsKey(u1) && _metricFactors.containsKey(u2)) return true;
    if (_countFactors.containsKey(u1) && _countFactors.containsKey(u2)) return true;

    return false;
  }

  /// Formats quantity cleanly:
  /// - 5.0 => "5"
  /// - 0.200 => "0.2"
  /// - 83.30 => "83.3"
  /// - 0.0833 => "0.083"
  static String formatQuantity(double qty) {
    if (qty == qty.roundToDouble()) {
      return qty.toInt().toString();
    }
    // Truncate to maximum 4 decimal places without trailing zeros
    String str = qty.toStringAsFixed(4);
    while (str.contains('.') && (str.endsWith('0') || str.endsWith('.'))) {
      str = str.substring(0, str.length - 1);
    }
    return str;
  }

  /// Formats quantity with unit string
  static String formatQuantityWithUnit(double qty, String unit) {
    return '${formatQuantity(qty)} $unit';
  }

  /// Generates a human-friendly dual representation if units differ:
  /// e.g. "83.3 Gram (= 0.083 KG)" or "1 Piece"
  static String formatDualUnit({
    required double sourceQty,
    required String sourceUnit,
    required String targetUnit,
  }) {
    if (normalizeUnit(sourceUnit) == normalizeUnit(targetUnit)) {
      return formatQuantityWithUnit(sourceQty, sourceUnit);
    }

    final converted = convertQuantity(
      quantity: sourceQty,
      fromUnit: sourceUnit,
      toUnit: targetUnit,
    );

    return '${formatQuantityWithUnit(sourceQty, sourceUnit)} (= ${formatQuantityWithUnit(converted, targetUnit)})';
  }
}
