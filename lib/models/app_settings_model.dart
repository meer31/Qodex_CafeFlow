class AppSettingsModel {
  final String cafeName;
  final String logoPath;
  final String address;
  final String phone;
  final String receiptFooter;
  final double taxPercent;
  final String currencySymbol;
  final double milkCupsPerKg; // Conversion engine base ratio: 1 KG Milk = N Full Cups
  final String appTheme; // 'classic_blue', 'warm_amber', 'midnight_dark'

  AppSettingsModel({
    this.cafeName = 'Cafe Indus',
    this.logoPath = '',
    this.address = 'Main Street, City Center',
    this.phone = '+92 300 1234567',
    this.receiptFooter = 'Thank you for visiting! Have a nice day.',
    this.taxPercent = 0.0,
    this.currencySymbol = 'Rs.',
    this.milkCupsPerKg = 5.0, // Default 1 KG = 5 Full Tea Cups
    this.appTheme = 'classic_blue',
  });

  Map<String, String> toMap() {
    return {
      'cafe_name': cafeName,
      'logo_path': logoPath,
      'address': address,
      'phone': phone,
      'receipt_footer': receiptFooter,
      'tax_percent': taxPercent.toString(),
      'currency_symbol': currencySymbol,
      'milk_cups_per_kg': milkCupsPerKg.toString(),
      'app_theme': appTheme,
    };
  }

  factory AppSettingsModel.fromMap(Map<String, String> map) {
    return AppSettingsModel(
      cafeName: map['cafe_name'] ?? 'Cafe Indus',
      logoPath: map['logo_path'] ?? '',
      address: map['address'] ?? 'Main Street, City Center',
      phone: map['phone'] ?? '+92 300 1234567',
      receiptFooter: map['receipt_footer'] ?? 'Thank you for visiting! Have a nice day.',
      taxPercent: double.tryParse(map['tax_percent'] ?? '0') ?? 0.0,
      currencySymbol: map['currency_symbol'] ?? 'Rs.',
      milkCupsPerKg: double.tryParse(map['milk_cups_per_kg'] ?? '5.0') ?? 5.0,
      appTheme: map['app_theme'] ?? 'classic_blue',
    );
  }

  AppSettingsModel copyWith({
    String? cafeName,
    String? logoPath,
    String? address,
    String? phone,
    String? receiptFooter,
    double? taxPercent,
    String? currencySymbol,
    double? milkCupsPerKg,
    String? appTheme,
  }) {
    return AppSettingsModel(
      cafeName: cafeName ?? this.cafeName,
      logoPath: logoPath ?? this.logoPath,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      receiptFooter: receiptFooter ?? this.receiptFooter,
      taxPercent: taxPercent ?? this.taxPercent,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      milkCupsPerKg: milkCupsPerKg ?? this.milkCupsPerKg,
      appTheme: appTheme ?? this.appTheme,
    );
  }
}
