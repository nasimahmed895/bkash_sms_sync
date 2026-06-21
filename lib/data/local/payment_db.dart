import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

import '../../domain/entities/payment.dart';

/// SQLite persistence layer. trxID has a UNIQUE index — duplicates are
/// rejected at the database level, which guarantees no duplicate webhooks
/// even across isolates (UI isolate, SMS background isolate, WorkManager).
class PaymentDb {
  static const _dbName = 'bkash_payments.db';
  static const _dbVersion = 2;
  static const table = 'payments';

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $table (
            localId INTEGER PRIMARY KEY AUTOINCREMENT,
            provider TEXT NOT NULL DEFAULT 'bkash',
            phone TEXT NOT NULL,
            amount REAL NOT NULL,
            balance REAL NOT NULL,
            trxID TEXT NOT NULL UNIQUE,
            paymentTime TEXT NOT NULL,
            syncStatus TEXT NOT NULL DEFAULT 'pending_sync',
            backendId INTEGER,
            retryCount INTEGER NOT NULL DEFAULT 0,
            lastAttempt INTEGER,
            createdAt INTEGER NOT NULL
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_sync_status ON $table (syncStatus)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
              "ALTER TABLE $table ADD COLUMN provider TEXT NOT NULL DEFAULT 'bkash'");
        }
      },
    );
  }

  Map<String, dynamic> _toRow(Payment pmt) => {
        'provider': pmt.provider,
        'phone': pmt.phone,
        'amount': pmt.amount,
        'balance': pmt.balance,
        'trxID': pmt.trxID,
        'paymentTime': pmt.paymentTime,
        'syncStatus': pmt.syncStatus.dbValue,
        'backendId': pmt.backendId,
        'retryCount': pmt.retryCount,
        'lastAttempt': pmt.lastAttempt?.millisecondsSinceEpoch,
        'createdAt': pmt.createdAt.millisecondsSinceEpoch,
      };

  Payment _fromRow(Map<String, dynamic> r) => Payment(
        localId: r['localId'] as int,
        provider: (r['provider'] as String?) ?? 'bkash',
        phone: r['phone'] as String,
        amount: (r['amount'] as num).toDouble(),
        balance: (r['balance'] as num).toDouble(),
        trxID: r['trxID'] as String,
        paymentTime: r['paymentTime'] as String,
        syncStatus: SyncStatusX.fromDb(r['syncStatus'] as String),
        backendId: r['backendId'] as int?,
        retryCount: r['retryCount'] as int,
        lastAttempt: r['lastAttempt'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(r['lastAttempt'] as int),
        createdAt: DateTime.fromMillisecondsSinceEpoch(r['createdAt'] as int),
      );

  /// Insert with duplicate protection. Returns inserted Payment or null
  /// when trxID already exists.
  Future<Payment?> insertIfNew(Payment pmt) async {
    final db = await database;
    final id = await db.insert(
      table,
      _toRow(pmt),
      conflictAlgorithm: ConflictAlgorithm.ignore, // duplicate => id 0
    );
    if (id == 0) return null;
    return pmt.copyWith(localId: id);
  }

  Future<List<Payment>> pending() async {
    final db = await database;
    final rows = await db.query(
      table,
      where: 'syncStatus = ?',
      whereArgs: ['pending_sync'],
      orderBy: 'createdAt ASC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<void> markSynced(int localId, int backendId) async {
    final db = await database;
    await db.update(
      table,
      {
        'syncStatus': 'synced',
        'backendId': backendId,
        'lastAttempt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'localId = ?',
      whereArgs: [localId],
    );
  }

  Future<void> markFailed(int localId) async {
    final db = await database;
    await db.update(
      table,
      {
        'syncStatus': 'failed',
        'lastAttempt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'localId = ?',
      whereArgs: [localId],
    );
  }

  Future<void> bumpRetry(int localId) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE $table SET retryCount = retryCount + 1, lastAttempt = ? '
      'WHERE localId = ?',
      [DateTime.now().millisecondsSinceEpoch, localId],
    );
  }

  /// Resets all `failed` records back to `pending_sync` so they are retried.
  Future<void> retryFailed() async {
    final db = await database;
    await db.update(
      table,
      {'syncStatus': 'pending_sync'},
      where: 'syncStatus = ?',
      whereArgs: ['failed'],
    );
  }

  Future<PaymentStats> stats() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT
        COUNT(*) AS total,
        COALESCE(SUM(amount), 0) AS totalAmount,
        SUM(CASE WHEN syncStatus = 'synced' THEN 1 ELSE 0 END) AS synced,
        SUM(CASE WHEN syncStatus = 'pending_sync' THEN 1 ELSE 0 END) AS pending,
        SUM(CASE WHEN syncStatus = 'failed' THEN 1 ELSE 0 END) AS failed
      FROM $table
    ''');
    final r = rows.first;
    return PaymentStats(
      totalPayments: (r['total'] as int?) ?? 0,
      totalAmount: ((r['totalAmount'] as num?) ?? 0).toDouble(),
      successful: (r['synced'] as int?) ?? 0,
      pendingSync: (r['pending'] as int?) ?? 0,
      failed: (r['failed'] as int?) ?? 0,
    );
  }
}
