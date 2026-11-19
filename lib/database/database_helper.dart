import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  static bool _ffiInitialized = false;

  /// Safely initializes SQLite FFI once for Desktop platforms without warnings or StateErrors
  static void ensureFfiInitialized() {
    if (!_ffiInitialized && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      _ffiInitialized = true;
    }
  }

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('cafe_flow.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (kIsWeb) {
      throw UnsupportedError('Web platform is not supported for local SQLite storage.');
    }

    // Initialize FFI for Desktop Windows, macOS, Linux
    ensureFfiInitialized();

    final dbPath = await getApplicationDocumentsDirectory();
    final path = join(dbPath.path, 'CafeFlow', filePath);
    
    // Ensure directory exists
    final dir = Directory(dirname(path));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return await openDatabase(
      path,
      version: 5,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
      onOpen: (db) async {
        try {
          // Safeguard: Ensure no stock quantity is ever negative in database
          await db.execute('UPDATE stock SET quantity = 0.0 WHERE quantity < 0.0;');
        } catch (_) {}
        try {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS table_draft_orders (
              table_id INTEGER PRIMARY KEY,
              waiter_id INTEGER,
              waiter_name TEXT,
              customer_name TEXT,
              customer_phone TEXT,
              order_type TEXT,
              discount_amount REAL DEFAULT 0.0,
              payment_method TEXT,
              token_number TEXT,
              items_json TEXT NOT NULL,
              kitchen_printed_items_json TEXT,
              updated_at TEXT NOT NULL
            )
          ''');
        } catch (_) {}
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Users Table
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        role TEXT NOT NULL,
        pin TEXT NOT NULL
      )
    ''');

    // 2. Categories Table
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        icon_name TEXT,
        sort_order INTEGER DEFAULT 0
      )
    ''');

    // 3. Products Table
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category_id INTEGER NOT NULL,
        selling_price REAL NOT NULL,
        cost_price REAL NOT NULL,
        status TEXT NOT NULL DEFAULT 'Active',
        image_url TEXT,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE
      )
    ''');

    // 4. Stock Table
    await db.execute('''
      CREATE TABLE stock (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        unit TEXT NOT NULL,
        quantity REAL NOT NULL DEFAULT 0.0,
        min_threshold REAL NOT NULL DEFAULT 5.0,
        cost_per_unit REAL NOT NULL DEFAULT 0.0,
        last_updated TEXT
      )
    ''');

    // 5. Recipe Items Table
    await db.execute('''
      CREATE TABLE recipe_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        stock_id INTEGER NOT NULL,
        stock_name TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit TEXT NOT NULL,
        is_milk_derived INTEGER DEFAULT 0,
        tea_type_ratio_key TEXT,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE,
        FOREIGN KEY (stock_id) REFERENCES stock (id) ON DELETE RESTRICT
      )
    ''');

    // 6. Stock Transactions Table
    await db.execute('''
      CREATE TABLE stock_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        stock_id INTEGER NOT NULL,
        stock_name TEXT NOT NULL,
        type TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit TEXT NOT NULL,
        date_time TEXT NOT NULL,
        invoice_number TEXT,
        notes TEXT,
        FOREIGN KEY (stock_id) REFERENCES stock (id)
      )
    ''');

    // 7. Table Sections Table
    await db.execute('''
      CREATE TABLE table_sections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        sort_order INTEGER DEFAULT 0
      )
    ''');

    // 8. Tables Table
    await db.execute('''
      CREATE TABLE tables (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        section_id INTEGER NOT NULL,
        table_name TEXT NOT NULL,
        capacity INTEGER NOT NULL DEFAULT 4,
        status TEXT NOT NULL DEFAULT 'Available',
        active_invoice_number TEXT,
        FOREIGN KEY (section_id) REFERENCES table_sections (id) ON DELETE CASCADE
      )
    ''');

    // 9. Waiters Table
    await db.execute('''
      CREATE TABLE waiters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'Active',
        total_sales REAL DEFAULT 0.0,
        orders_count INTEGER DEFAULT 0
      )
    ''');

    // 10. Expenses Table
    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        date_time TEXT NOT NULL,
        notes TEXT
      )
    ''');

    // 11. Customers Table
    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL UNIQUE,
        loyalty_points INTEGER DEFAULT 0,
        total_spent REAL DEFAULT 0.0
      )
    ''');

    // 12. Sales Table
    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER,
        invoice_number TEXT NOT NULL,
        date_time TEXT NOT NULL,
        cashier_name TEXT NOT NULL,
        waiter_id INTEGER,
        waiter_name TEXT,
        table_id INTEGER,
        table_name TEXT,
        customer_name TEXT,
        customer_phone TEXT,
        subtotal REAL NOT NULL,
        discount REAL DEFAULT 0.0,
        tax REAL DEFAULT 0.0,
        grand_total REAL NOT NULL,
        total_cost REAL DEFAULT 0.0,
        payment_method TEXT NOT NULL,
        status TEXT DEFAULT 'COMPLETED'
      )
    ''');

    // 13. Sale Items Table
    await db.execute('''
      CREATE TABLE sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        unit_cost REAL DEFAULT 0.0,
        total_price REAL NOT NULL,
        notes TEXT,
        FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE
      )
    ''');

    // 14. Settings Table
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // 15. Invoice Sequence Table
    await db.execute('''
      CREATE TABLE invoice_sequence (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        last_seq INTEGER NOT NULL DEFAULT 1000
      )
    ''');
    await db.insert('invoice_sequence', {'last_seq': 1000});

    // 16. Meat Purchases Table
    await _createMeatTables(db);

    // 17. Sale Sessions Table
    await _createSessionTables(db);

    // 18. Table Draft Orders Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS table_draft_orders (
        table_id INTEGER PRIMARY KEY,
        waiter_id INTEGER,
        waiter_name TEXT,
        customer_name TEXT,
        customer_phone TEXT,
        order_type TEXT,
        discount_amount REAL DEFAULT 0.0,
        payment_method TEXT,
        token_number TEXT,
        items_json TEXT NOT NULL,
        kitchen_printed_items_json TEXT,
        updated_at TEXT NOT NULL
      )
    ''');

    // Seed Default Data
    await _seedDatabase(db);
  }

  Future<void> _createMeatTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS meat_purchases (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_number TEXT NOT NULL UNIQUE,
        date_time TEXT NOT NULL,
        grand_total REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS meat_purchase_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        purchase_id INTEGER NOT NULL,
        meat_type TEXT NOT NULL,
        quantity_kg REAL NOT NULL,
        rate_per_kg REAL NOT NULL,
        total_amount REAL NOT NULL,
        FOREIGN KEY (purchase_id) REFERENCES meat_purchases (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS meat_invoice_sequence (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        last_seq INTEGER NOT NULL DEFAULT 1000
      )
    ''');

    // Check if meat sequence already seeded
    final seqCheck = await db.query('meat_invoice_sequence');
    if (seqCheck.isEmpty) {
      await db.insert('meat_invoice_sequence', {'last_seq': 1000});
    }
  }

  Future<void> _createSessionTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sale_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_name TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT,
        business_date TEXT NOT NULL,
        opening_cash REAL NOT NULL DEFAULT 0.0,
        closing_cash REAL,
        total_sales REAL DEFAULT 0.0,
        total_expenses REAL DEFAULT 0.0,
        cash_sales REAL DEFAULT 0.0,
        card_sales REAL DEFAULT 0.0,
        online_sales REAL DEFAULT 0.0,
        status TEXT NOT NULL DEFAULT 'ACTIVE',
        notes TEXT
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createMeatTables(db);
    }
    if (oldVersion < 3) {
      await _createSessionTables(db);
      try {
        await db.execute('ALTER TABLE sales ADD COLUMN session_id INTEGER');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE expenses ADD COLUMN session_id INTEGER');
      } catch (_) {}
    }
    if (oldVersion < 4) {
      // Remove UNIQUE constraint from invoice_number so each shift can start from invoice 1
      try {
        await db.execute('PRAGMA foreign_keys=OFF');
        await db.execute('''
          CREATE TABLE sales_v4_tmp (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id INTEGER,
            invoice_number TEXT NOT NULL,
            date_time TEXT NOT NULL,
            cashier_name TEXT NOT NULL,
            waiter_id INTEGER,
            waiter_name TEXT,
            table_id INTEGER,
            table_name TEXT,
            customer_name TEXT,
            customer_phone TEXT,
            subtotal REAL NOT NULL,
            discount REAL DEFAULT 0.0,
            tax REAL DEFAULT 0.0,
            grand_total REAL NOT NULL,
            total_cost REAL DEFAULT 0.0,
            payment_method TEXT NOT NULL,
            status TEXT DEFAULT 'COMPLETED'
          )
        ''');
        await db.execute('''
          INSERT INTO sales_v4_tmp (id, session_id, invoice_number, date_time, cashier_name, waiter_id, waiter_name, table_id, table_name, customer_name, customer_phone, subtotal, discount, tax, grand_total, total_cost, payment_method, status)
          SELECT id, session_id, invoice_number, date_time, cashier_name, waiter_id, waiter_name, table_id, table_name, customer_name, customer_phone, subtotal, discount, tax, grand_total, total_cost, payment_method, status FROM sales
        ''');
        await db.execute('DROP TABLE sales');
        await db.execute('ALTER TABLE sales_v4_tmp RENAME TO sales');
        await db.execute('PRAGMA foreign_keys=ON');
      } catch (_) {}
    }
    if (oldVersion < 5) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS table_draft_orders (
            table_id INTEGER PRIMARY KEY,
            waiter_id INTEGER,
            waiter_name TEXT,
            customer_name TEXT,
            customer_phone TEXT,
            order_type TEXT,
            discount_amount REAL DEFAULT 0.0,
            payment_method TEXT,
            token_number TEXT,
            items_json TEXT NOT NULL,
            kitchen_printed_items_json TEXT,
            updated_at TEXT NOT NULL
          )
        ''');
      } catch (_) {}
    }
  }

  Future<void> _seedDatabase(Database db) async {
    // Seed Default User
    await db.insert('users', {
      'username': 'admin',
      'name': 'Cafe Owner',
      'role': 'Admin',
      'pin': '1234',
    });

    // Seed Settings
    final defaultSettings = {
      'cafe_name': 'Cafe Indus',
      'logo_path': '',
      'address': 'Main Market, City Center',
      'phone': '+92 300 1234567',
      'receipt_footer': 'Thank you for dining with us! Come back soon.',
      'tax_percent': '5.0',
      'currency_symbol': 'Rs.',
      'milk_cups_per_kg': '5.0', // 1 KG Milk = 5 Full Cups
    };

    for (var entry in defaultSettings.entries) {
      await db.insert('settings', {'key': entry.key, 'value': entry.value});
    }

    // Seed Categories
    final categories = ['Tea', 'Coffee', 'Cold Drinks', 'Fast Food', 'Chinese', 'Desserts', 'Juices'];
    final catIds = <String, int>{};
    for (int i = 0; i < categories.length; i++) {
      int id = await db.insert('categories', {
        'name': categories[i],
        'description': '${categories[i]} menu items',
        'sort_order': i + 1,
      });
      catIds[categories[i]] = id;
    }

    // Seed Stock Items
    final stockItems = [
      {'name': 'Milk', 'unit': 'KG', 'quantity': 50.0, 'min_threshold': 10.0, 'cost_per_unit': 220.0},
      {'name': 'Tea Powder', 'unit': 'KG', 'quantity': 15.0, 'min_threshold': 2.0, 'cost_per_unit': 1400.0},
      {'name': 'Sugar', 'unit': 'KG', 'quantity': 40.0, 'min_threshold': 5.0, 'cost_per_unit': 150.0},
      {'name': 'Coffee Beans', 'unit': 'KG', 'quantity': 10.0, 'min_threshold': 2.0, 'cost_per_unit': 3500.0},
      {'name': 'Cold Drinks 500ml', 'unit': 'Bottle', 'quantity': 120.0, 'min_threshold': 24.0, 'cost_per_unit': 80.0},
      {'name': 'Chicken', 'unit': 'KG', 'quantity': 25.0, 'min_threshold': 5.0, 'cost_per_unit': 650.0},
      {'name': 'Bread', 'unit': 'Packet', 'quantity': 20.0, 'min_threshold': 5.0, 'cost_per_unit': 120.0},
      {'name': 'Eggs', 'unit': 'Piece', 'quantity': 100.0, 'min_threshold': 30.0, 'cost_per_unit': 25.0},
      {'name': 'Oil', 'unit': 'Liter', 'quantity': 30.0, 'min_threshold': 5.0, 'cost_per_unit': 480.0},
    ];

    final stockIds = <String, int>{};
    for (var item in stockItems) {
      int id = await db.insert('stock', {
        'name': item['name'],
        'unit': item['unit'],
        'quantity': item['quantity'],
        'min_threshold': item['min_threshold'],
        'cost_per_unit': item['cost_per_unit'],
        'last_updated': DateTime.now().toIso8601String(),
      });
      stockIds[item['name'] as String] = id;
    }

    // Seed Products with Recipes
    // 1. Full Tea
    int fullTeaId = await db.insert('products', {
      'name': 'Full Tea',
      'category_id': catIds['Tea'],
      'selling_price': 100.0,
      'cost_price': 55.0,
      'status': 'Active',
    });
    // Recipe for Full Tea: Milk (is_milk_derived, full cup ratio), Tea Powder (8g = 0.008 KG), Sugar (15g = 0.015 KG)
    await db.insert('recipe_items', {
      'product_id': fullTeaId,
      'stock_id': stockIds['Milk'],
      'stock_name': 'Milk',
      'quantity': 1.0, // 1 cup ratio unit
      'unit': 'KG',
      'is_milk_derived': 1,
      'tea_type_ratio_key': 'Full Tea',
    });
    await db.insert('recipe_items', {
      'product_id': fullTeaId,
      'stock_id': stockIds['Tea Powder'],
      'stock_name': 'Tea Powder',
      'quantity': 0.008,
      'unit': 'KG',
      'is_milk_derived': 0,
    });
    await db.insert('recipe_items', {
      'product_id': fullTeaId,
      'stock_id': stockIds['Sugar'],
      'stock_name': 'Sugar',
      'quantity': 0.015,
      'unit': 'KG',
      'is_milk_derived': 0,
    });

    // 2. Half Tea
    int halfTeaId = await db.insert('products', {
      'name': 'Half Tea',
      'category_id': catIds['Tea'],
      'selling_price': 60.0,
      'cost_price': 30.0,
      'status': 'Active',
    });
    await db.insert('recipe_items', {
      'product_id': halfTeaId,
      'stock_id': stockIds['Milk'],
      'stock_name': 'Milk',
      'quantity': 0.5, // Half cup ratio unit
      'unit': 'KG',
      'is_milk_derived': 1,
      'tea_type_ratio_key': 'Half Tea',
    });
    await db.insert('recipe_items', {
      'product_id': halfTeaId,
      'stock_id': stockIds['Tea Powder'],
      'stock_name': 'Tea Powder',
      'quantity': 0.004,
      'unit': 'KG',
      'is_milk_derived': 0,
    });
    await db.insert('recipe_items', {
      'product_id': halfTeaId,
      'stock_id': stockIds['Sugar'],
      'stock_name': 'Sugar',
      'quantity': 0.008,
      'unit': 'KG',
      'is_milk_derived': 0,
    });

    // 3. Special Tea
    int specialTeaId = await db.insert('products', {
      'name': 'Special Doodh Patti',
      'category_id': catIds['Tea'],
      'selling_price': 160.0,
      'cost_price': 85.0,
      'status': 'Active',
    });
    await db.insert('recipe_items', {
      'product_id': specialTeaId,
      'stock_id': stockIds['Milk'],
      'stock_name': 'Milk',
      'quantity': 1.5,
      'unit': 'KG',
      'is_milk_derived': 1,
      'tea_type_ratio_key': 'Special Tea',
    });
    await db.insert('recipe_items', {
      'product_id': specialTeaId,
      'stock_id': stockIds['Tea Powder'],
      'stock_name': 'Tea Powder',
      'quantity': 0.012,
      'unit': 'KG',
      'is_milk_derived': 0,
    });

    // 4. Cappuccino
    int capId = await db.insert('products', {
      'name': 'Cappuccino',
      'category_id': catIds['Coffee'],
      'selling_price': 350.0,
      'cost_price': 140.0,
      'status': 'Active',
    });
    await db.insert('recipe_items', {
      'product_id': capId,
      'stock_id': stockIds['Coffee Beans'],
      'stock_name': 'Coffee Beans',
      'quantity': 0.018,
      'unit': 'KG',
      'is_milk_derived': 0,
    });
    await db.insert('recipe_items', {
      'product_id': capId,
      'stock_id': stockIds['Milk'],
      'stock_name': 'Milk',
      'quantity': 0.15, // 150ml milk
      'unit': 'KG',
      'is_milk_derived': 0,
    });

    // 5. Club Sandwich
    int clubId = await db.insert('products', {
      'name': 'Club Sandwich',
      'category_id': catIds['Fast Food'],
      'selling_price': 450.0,
      'cost_price': 210.0,
      'status': 'Active',
    });
    await db.insert('recipe_items', {
      'product_id': clubId,
      'stock_id': stockIds['Bread'],
      'stock_name': 'Bread',
      'quantity': 0.25, // 1/4 packet
      'unit': 'Packet',
      'is_milk_derived': 0,
    });
    await db.insert('recipe_items', {
      'product_id': clubId,
      'stock_id': stockIds['Chicken'],
      'stock_name': 'Chicken',
      'quantity': 0.15,
      'unit': 'KG',
      'is_milk_derived': 0,
    });
    await db.insert('recipe_items', {
      'product_id': clubId,
      'stock_id': stockIds['Eggs'],
      'stock_name': 'Eggs',
      'quantity': 1.0,
      'unit': 'Piece',
      'is_milk_derived': 0,
    });

    // Seed Sections & Tables
    final sections = ['Outdoor', 'Family Hall', 'Inside Hall', 'VIP'];
    for (int i = 0; i < sections.length; i++) {
      int secId = await db.insert('table_sections', {
        'name': sections[i],
        'sort_order': i + 1,
      });

      if (sections[i] == 'Outdoor') {
        for (int t = 1; t <= 4; t++) {
          await db.insert('tables', {
            'section_id': secId,
            'table_name': 'Table O-$t',
            'capacity': 4,
            'status': 'Available',
          });
        }
      } else if (sections[i] == 'Family Hall') {
        for (int t = 1; t <= 4; t++) {
          await db.insert('tables', {
            'section_id': secId,
            'table_name': 'Table F-$t',
            'capacity': 6,
            'status': 'Available',
          });
        }
      } else if (sections[i] == 'Inside Hall') {
        for (int t = 1; t <= 4; t++) {
          await db.insert('tables', {
            'section_id': secId,
            'table_name': 'Table I-$t',
            'capacity': 4,
            'status': 'Available',
          });
        }
      } else {
        for (int t = 1; t <= 2; t++) {
          await db.insert('tables', {
            'section_id': secId,
            'table_name': 'VIP Hall $t',
            'capacity': 8,
            'status': 'Available',
          });
        }
      }
    }

    // Seed Waiters
    final waiters = [
      {'name': 'Ali Raza', 'phone': '+92 301 1111111'},
      {'name': 'Hamza Khan', 'phone': '+92 302 2222222'},
      {'name': 'Sara Ahmed', 'phone': '+92 303 3333333'},
    ];

    for (var w in waiters) {
      await db.insert('waiters', {
        'name': w['name'],
        'phone': w['phone'],
        'status': 'Active',
        'total_sales': 0.0,
        'orders_count': 0,
      });
    }

    // Seed Sample Expenses
    await db.insert('expenses', {
      'title': 'Milk & Grocery Purchase',
      'category': 'Purchase',
      'amount': 3500.0,
      'date_time': DateTime.now().subtract(const Duration(hours: 4)).toIso8601String(),
      'notes': 'Daily fresh stock',
    });
    await db.insert('expenses', {
      'title': 'Electricity Bill',
      'category': 'Electricity',
      'amount': 14500.0,
      'date_time': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      'notes': 'Monthly bill payment',
    });
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
    _database = null;
  }

  /// Returns the absolute path of the database file for backup/restore
  Future<String> getDatabasePath() async {
    final dbPath = await getApplicationDocumentsDirectory();
    return join(dbPath.path, 'CafeFlow', 'cafe_flow.db');
  }

  /// Closes DB and reopens it — used after restoring a backup
  Future<void> restartDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    _database = await _initDB('cafe_flow.db');
  }
}
