import '../core/constants/app_constants.dart';

class MilkConversionService {
  /// Calculates the exact Milk deduction in KG for a given tea cup type
  /// based on the dynamically configured `milkCupsPerKg` setting (e.g. 5.0).
  ///
  /// Example:
  /// - Base setting: 1 KG Milk = 5 Full Cups => base unit = 1 / 5 = 0.20 KG per Full Cup
  /// - Full Tea (ratio 1.0) => 0.20 KG
  /// - Half Tea (ratio 0.5) => 0.10 KG
  /// - Large Tea (ratio 1.25) => 0.25 KG
  /// - Special Tea (ratio 1.5) => 0.30 KG
  static double calculateMilkDeductionKg({
    required double milkCupsPerKg,
    required String teaTypeRatioKey,
    int quantity = 1,
  }) {
    if (milkCupsPerKg <= 0) return 0.0;
    
    // 1 Full Cup Base Deduction (in KG)
    final double baseCupKg = 1.0 / milkCupsPerKg;
    
    // Multiplier for specific tea size/portion
    final double portionMultiplier = AppConstants.teaPortionRatios[teaTypeRatioKey] ?? 1.0;
    
    return baseCupKg * portionMultiplier * quantity;
  }

  /// Expresses milk consumption in ML for display purposes
  static double convertKgToMl(double kg) {
    return kg * 1000.0;
  }

  /// Calculates estimated cups left from current Milk stock (in KG)
  static int calculateEstimatedCupsLeft(double currentMilkKg, double milkCupsPerKg) {
    if (milkCupsPerKg <= 0) return 0;
    return (currentMilkKg * milkCupsPerKg).floor();
  }
}
