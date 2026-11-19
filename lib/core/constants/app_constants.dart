class AppConstants {
  static const String appName = 'Cafe Flow POS';
  static const String appVersion = '1.0.0';

  // Inventory Units
  static const List<String> inventoryUnits = [
    'KG',
    'Gram',
    'Liter',
    'ML',
    'Piece',
    'Bottle',
    'Packet',
    'Box',
    'Tray',
  ];

  // User Roles
  static const String roleAdmin = 'Admin';
  static const String roleCashier = 'Cashier';
  static const String roleManager = 'Manager';

  // Table Statuses
  static const String tableAvailable = 'Available';
  static const String tableOccupied = 'Occupied';
  static const String tableReserved = 'Reserved';
  static const String tableCleaning = 'Cleaning';

  // Default Sections
  static const List<String> defaultSections = [
    'Outdoor',
    'Family Hall',
    'Inside Hall',
    'VIP',
  ];

  // Expense Categories
  static const List<String> expenseCategories = [
    'Electricity',
    'Gas',
    'Salary',
    'Maintenance',
    'Purchase',
    'Miscellaneous',
  ];

  // Payment Methods
  static const List<String> paymentMethods = [
    'Cash',
    'Card',
    'Online/UPI',
    'Other',
  ];

  // Milk Conversion Default Settings
  static const String settingMilkCupsPerKg = 'milk_cups_per_kg'; // e.g., '5'
  static const String settingCafeName = 'cafe_name';
  static const String settingCafeLogo = 'cafe_logo';
  static const String settingCafeAddress = 'cafe_address';
  static const String settingReceiptFooter = 'receipt_footer';
  static const String settingTaxPercent = 'tax_percent';
  static const String settingCurrency = 'currency';

  // Tea Type Dose Ratios (Portion of 1 Cup base dosage)
  static const Map<String, double> teaPortionRatios = {
    'Full Tea': 1.0,      // 100% of standard cup
    'Half Tea': 0.5,      // 50%
    'Large Tea': 1.25,    // 125%
    'Special Tea': 1.5,   // 150%
  };
}
