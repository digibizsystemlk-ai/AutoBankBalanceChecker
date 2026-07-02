import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'models.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'bank_balance.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_number_last_4 TEXT UNIQUE,
        bank_name TEXT,
        currency TEXT,
        initial_balance REAL,
        current_balance REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id INTEGER,
        type TEXT,
        amount REAL,
        date TEXT,
        sms_body TEXT,
        FOREIGN KEY (account_id) REFERENCES accounts (id)
      )
    ''');
  }

  // --- Account Operations ---

  Future<int> insertAccount(Account account) async {
    Database db = await database;
    return await db.insert('accounts', account.toMap());
  }

  Future<List<Account>> getAccounts() async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query('accounts');
    return List.generate(maps.length, (i) => Account.fromMap(maps[i]));
  }

  Future<Account?> getAccountByLast4(String last4) async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query(
      'accounts',
      where: 'account_number_last_4 = ?',
      whereArgs: [last4],
    );
    if (maps.isNotEmpty) {
      return Account.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateAccountBalance(int accountId, double newBalance) async {
    Database db = await database;
    return await db.update(
      'accounts',
      {'current_balance': newBalance},
      where: 'id = ?',
      whereArgs: [accountId],
    );
  }

  // --- Transaction Operations ---

  Future<int> insertTransaction(TransactionRecord tr) async {
    Database db = await database;
    return await db.insert('transactions', tr.toMap());
  }

  Future<List<TransactionRecord>> getTransactionsForAccount(int accountId) async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'account_id = ?',
      whereArgs: [accountId],
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => TransactionRecord.fromMap(maps[i]));
  }
  
  Future<List<TransactionRecord>> getFilteredTransactions({
    required int accountId,
    DateTime? startDate,
    DateTime? endDate,
    String? category,
    String? searchQuery,
  }) async {
    Database db = await database;
    
    String whereClause = 'account_id = ?';
    List<dynamic> whereArgs = [accountId];

    if (startDate != null && endDate != null) {
      whereClause += ' AND date >= ? AND date <= ?';
      whereArgs.add(startDate.toIso8601String());
      whereArgs.add(endDate.toIso8601String());
    }

    if (category != null && category.isNotEmpty && category != 'All') {
      whereClause += ' AND type = ?';
      whereArgs.add(category);
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      whereClause += ' AND sms_body LIKE ?';
      whereArgs.add('%${searchQuery.trim()}%');
    }

    List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'date DESC',
    );

    return List.generate(maps.length, (i) => TransactionRecord.fromMap(maps[i]));
  }

  Future<Map<String, double>> getTransactionSummary() async {
    Database db = await database;
    final List<Map<String, dynamic>> creditResult = await db.rawQuery("SELECT SUM(amount) as total FROM transactions WHERE type = 'Credit'");
    final List<Map<String, dynamic>> debitResult = await db.rawQuery("SELECT SUM(amount) as total FROM transactions WHERE type IN ('Debit', 'Cheque')");

    double totalCredit = (creditResult.first['total'] ?? 0.0) as double;
    double totalDebit = (debitResult.first['total'] ?? 0.0) as double;

    return {
      'Credit': totalCredit,
      'Debit': totalDebit,
    };
  }
}
