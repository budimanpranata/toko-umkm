// ignore_for_file: unnecessary_brace_in_string_interps

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'model/product_model.dart';
import 'model/transaction_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('snack_store.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 7,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
    CREATE TABLE products (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      initial TEXT NOT NULL,
      imageUrl TEXT NOT NULL,
      purchaseCount INTEGER NOT NULL,
      price REAL NOT NULL,
      stock INTEGER NOT NULL
    )
    ''');

    await db.execute('''
    CREATE TABLE transactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date TEXT NOT NULL,
      total_items INTEGER NOT NULL,
      total_price REAL NOT NULL
    )
    ''');

    await db.execute('''
    CREATE TABLE transaction_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      transaction_id INTEGER NOT NULL,
      product_id INTEGER NOT NULL,
      product_name TEXT NOT NULL,
      quantity INTEGER NOT NULL,
      price REAL NOT NULL
    )
    ''');

    await db.execute('''
    CREATE TABLE users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      username TEXT NOT NULL UNIQUE,
      password TEXT NOT NULL,
      last_password_reset TEXT NOT NULL
    )
    ''');

    await db.insert('users', {
      'username': 'admin',
      'password': 'password123',
      'last_password_reset': DateTime.now().toIso8601String(),
    });

    await db.execute('''
    CREATE TABLE financial_records (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      type TEXT NOT NULL,
      amount REAL NOT NULL,
      description TEXT NOT NULL,
      date TEXT NOT NULL
    )
    ''');

    await db.execute('''
    CREATE TABLE cash_counts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date TEXT NOT NULL,
      c100k INTEGER NOT NULL DEFAULT 0,
      c50k INTEGER NOT NULL DEFAULT 0,
      c20k INTEGER NOT NULL DEFAULT 0,
      c10k INTEGER NOT NULL DEFAULT 0,
      c5k INTEGER NOT NULL DEFAULT 0,
      c2k INTEGER NOT NULL DEFAULT 0,
      c1k INTEGER NOT NULL DEFAULT 0,
      c500 INTEGER NOT NULL DEFAULT 0,
      c200 INTEGER NOT NULL DEFAULT 0,
      c100 INTEGER NOT NULL DEFAULT 0
    )
    ''');


    // Menyisipkan data dummy awal
    await db.insert('products', {
      'name': 'Keripik Kentang Balado',
      'initial': 'KKB',
      'imageUrl': 'https://picsum.photos/200',
      'purchaseCount': 0,
      'price': 15000.0,
      'stock': 50,
    });
    await db.insert('products', {
      'name': 'Makaroni Pedas Daun Jeruk',
      'initial': 'MPDJ',
      'imageUrl': 'https://picsum.photos/201',
      'purchaseCount': 0,
      'price': 12000.0,
      'stock': 30,
    });
    await db.insert('products', {
      'name': 'Kacang Atom Oven',
      'initial': 'KAO',
      'imageUrl': 'https://picsum.photos/202',
      'purchaseCount': 0,
      'price': 18000.0,
      'stock': 100,
    });
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('DROP TABLE IF EXISTS products');
      await _createDB(db, newVersion);
      return; // Berhenti jika _createDB sudah dijalankan
    }
    if (oldVersion < 3) {
      await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        total_items INTEGER NOT NULL,
        total_price REAL NOT NULL
      )
      ''');
    }
    if (oldVersion < 4) {
      await db.execute(
        'ALTER TABLE products ADD COLUMN stock INTEGER NOT NULL DEFAULT 50',
      );
      await db.execute('''
      CREATE TABLE transaction_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        price REAL NOT NULL
      )
      ''');
    }
    if (oldVersion < 5) {
      await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        last_password_reset TEXT NOT NULL
      )
      ''');
      await db.insert('users', {
        'username': 'admin',
        'password': 'password123',
        'last_password_reset': DateTime.now().toIso8601String(),
      });
    }
    if (oldVersion < 6) {
      await db.execute('''
      CREATE TABLE financial_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        description TEXT NOT NULL,
        date TEXT NOT NULL
      )
      ''');
    }
    if (oldVersion < 7) {
      await db.execute('''
      CREATE TABLE cash_counts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        c100k INTEGER NOT NULL DEFAULT 0,
        c50k INTEGER NOT NULL DEFAULT 0,
        c20k INTEGER NOT NULL DEFAULT 0,
        c10k INTEGER NOT NULL DEFAULT 0,
        c5k INTEGER NOT NULL DEFAULT 0,
        c2k INTEGER NOT NULL DEFAULT 0,
        c1k INTEGER NOT NULL DEFAULT 0,
        c500 INTEGER NOT NULL DEFAULT 0,
        c200 INTEGER NOT NULL DEFAULT 0,
        c100 INTEGER NOT NULL DEFAULT 0
      )
      ''');
    }
  }

  Future<List<Product>> readAllProducts() async {
    final db = await instance.database;
    final result = await db.query('products');
    return result.map((json) => Product.fromMap(json)).toList();
  }

  Future<List<Product>> searchProducts(String keyword) async {
    final db = await instance.database;
    final result = await db.query(
      'products',
      where: 'name LIKE ? OR initial LIKE ?',
      whereArgs: ['%$keyword%', '%$keyword%'],
    );
    return result.map((json) => Product.fromMap(json)).toList();
  }

  /// Produk dengan sisa stok di bawah [threshold], stok paling sedikit di atas.
  Future<List<Product>> getLowStockProducts({int threshold = 5}) async {
    final db = await instance.database;
    final result = await db.query(
      'products',
      where: 'stock < ?',
      whereArgs: [threshold],
      orderBy: 'stock ASC, name ASC',
    );
    return result.map((json) => Product.fromMap(json)).toList();
  }

  Future<List<Product>> getFastMovingProducts() async {
    final db = await instance.database;
    // Mengambil tanggal 90 hari ke belakang dengan format ISO 8601
    final threeMonthsAgo =
        DateTime.now().subtract(const Duration(days: 90)).toIso8601String();
    final result = await db.rawQuery(
      '''
      SELECT p.*, SUM(ti.quantity) as recent_sales
      FROM products p
      JOIN transaction_items ti ON p.id = ti.product_id
      JOIN transactions t ON t.id = ti.transaction_id
      WHERE t.date >= ?
      GROUP BY p.id
      ORDER BY recent_sales DESC
      LIMIT 5
    ''',
      [threeMonthsAgo],
    );
    return result.map((json) => Product.fromMap(json)).toList();
  }

  Future<List<TransactionModel>> readAllTransactions({
    int? month,
    int? year,
  }) async {
    final db = await instance.database;

    String? whereClause;
    List<dynamic>? whereArgs;

    if (month != null && year != null) {
      whereClause = 'date LIKE ?';
      whereArgs = ['${year}-${month.toString().padLeft(2, '0')}-%'];
    } else if (year != null) {
      whereClause = 'date LIKE ?';
      whereArgs = ['$year-%'];
    }

    final result = await db.query(
      'transactions',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'id DESC',
    );

    List<TransactionModel> transactions = [];
    for (var json in result) {
      final trx = TransactionModel.fromMap(json);
      final itemsResult = await db.query(
        'transaction_items',
        where: 'transaction_id = ?',
        whereArgs: [trx.id],
      );
      final items =
          itemsResult.map((i) => TransactionItemModel.fromMap(i)).toList();

      transactions.add(
        TransactionModel(
          id: trx.id,
          date: trx.date,
          totalItems: trx.totalItems,
          totalPrice: trx.totalPrice,
          items: items,
        ),
      );
    }
    return transactions;
  }

  Future<int> createProduct(Product product) async {
    final db = await instance.database;
    return await db.insert('products', product.toMap());
  }

  Future<int> updateProduct(Product product) async {
    final db = await instance.database;
    return await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<int> deleteProduct(int id) async {
    final db = await instance.database;
    return await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  // Fungsi memproses transaksi dan meng-update jumlah "Terbeli" produk
  Future<void> processTransaction(
    Map<int, Product> cartProducts,
    Map<int, int> cartQuantities,
    double totalPrice,
  ) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      int totalItems = cartQuantities.values.fold(0, (sum, qty) => sum + qty);

      int transactionId = await txn.insert('transactions', {
        'date': DateTime.now().toIso8601String(),
        'total_items': totalItems,
        'total_price': totalPrice,
      });

      for (var entry in cartQuantities.entries) {
        final productId = entry.key;
        final qty = entry.value;
        final product = cartProducts[productId]!;

        await txn.insert('transaction_items', {
          'transaction_id': transactionId,
          'product_id': productId,
          'product_name': product.name,
          'quantity': qty,
          'price': product.price,
        });

        await txn.rawUpdate(
          'UPDATE products SET purchaseCount = purchaseCount + ?, stock = stock - ? WHERE id = ?',
          [qty, qty, productId],
        );
      }
    });
  }

  Future<Map<String, dynamic>?> authenticateUser(
    String username,
    String password,
  ) async {
    final db = await instance.database;
    final result = await db.query(
      'users',
      where: 'username = ? AND password = ?',
      whereArgs: [username, password],
    );
    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  Future<int> updatePassword(int id, String newPassword) async {
    final db = await instance.database;
    return await db.update(
      'users',
      {
        'password': newPassword,
        'last_password_reset': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> insertFinancialRecord(FinancialRecordModel record) async {
    final db = await instance.database;
    return await db.insert('financial_records', record.toMap());
  }

  Future<List<FinancialRecordModel>> readAllFinancialRecords() async {
    final db = await instance.database;
    final result = await db.query('financial_records', orderBy: 'date DESC');
    return result.map((json) => FinancialRecordModel.fromMap(json)).toList();
  }

  Future<int> deleteFinancialRecord(int id) async {
    final db = await instance.database;
    return await db.delete(
      'financial_records',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> saveCashCount(Map<String, dynamic> cashCountData) async {
    final db = await instance.database;
    await db.delete('cash_counts'); // Hapus yang lama agar hanya simpan 1 sesi terbaru
    return await db.insert('cash_counts', cashCountData);
  }

  Future<Map<String, dynamic>?> getLatestCashCount() async {
    final db = await instance.database;
    final result = await db.query('cash_counts', orderBy: 'id DESC', limit: 1);
    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }
}
