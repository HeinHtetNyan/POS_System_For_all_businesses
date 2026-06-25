import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../models/cart_model.dart';
import '../../features/pos/data/pos_repository.dart';

class OfflineQueueService {
  static final OfflineQueueService _instance = OfflineQueueService._internal();
  factory OfflineQueueService() => _instance;
  OfflineQueueService._internal();

  Database? _db;
  bool _isSyncing = false;

  // Reactive count — listen with ValueListenableBuilder in the UI
  final ValueNotifier<int> pendingCount = ValueNotifier(0);

  Future<Database> get _database async {
    _db ??= await _openDb();
    return _db!;
  }

  Future<Database> _openDb() async {
    final dir = await getDatabasesPath();
    final path = join(dir, 'pos_offline_queue.db');
    final db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE offline_orders (
            id TEXT PRIMARY KEY,
            branch_id TEXT NOT NULL,
            session_id TEXT NOT NULL,
            customer_id TEXT,
            items_json TEXT NOT NULL,
            payments_json TEXT NOT NULL,
            attempts INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL
          )
        ''');
      },
    );
    await _refreshCount(db);
    return db;
  }

  Future<void> _refreshCount([Database? db]) async {
    final d = db ?? await _database;
    final result = await d.rawQuery('SELECT COUNT(*) as c FROM offline_orders');
    pendingCount.value = result.first['c'] as int? ?? 0;
  }

  Future<void> enqueue({
    required String branchId,
    required String sessionId,
    String? customerId,
    required List<LocalCartItem> items,
    required List<CheckoutPayment> payments,
  }) async {
    final db = await _database;
    await db.insert('offline_orders', {
      'id': const Uuid().v4(),
      'branch_id': branchId,
      'session_id': sessionId,
      'customer_id': customerId,
      'items_json': jsonEncode(items.map((i) => i.toJson()).toList()),
      'payments_json': jsonEncode(payments.map((p) => p.toJson()).toList()),
      'attempts': 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    await _refreshCount(db);
  }

  // Retry all queued orders against the server.
  // Call this when the device comes back online.
  Future<int> syncPending(PosRepository repo) async {
    if (_isSyncing) return 0;
    _isSyncing = true;
    int synced = 0;
    try {
      final db = await _database;
      final rows = await db.query('offline_orders', orderBy: 'created_at ASC');
      for (final row in rows) {
        final id = row['id'] as String;
        final branchId = row['branch_id'] as String;
        final sessionId = row['session_id'] as String;
        final customerId = row['customer_id'] as String?;
        final items = (jsonDecode(row['items_json'] as String) as List)
            .map((e) => LocalCartItem.fromJson(e as Map<String, dynamic>))
            .toList();
        final payments =
            (jsonDecode(row['payments_json'] as String) as List)
                .map((e) =>
                    CheckoutPayment.fromJson(e as Map<String, dynamic>))
                .toList();
        try {
          final serverCart = await repo.createCart(
            branchId: branchId,
            cashierSessionId: sessionId,
            customerId: customerId,
          );
          for (final item in items) {
            await repo.addToCart(
              cartId: serverCart.id,
              productId: item.productId,
              variantId: item.variantId,
              quantity: item.quantity,
              unitPrice: item.unitPrice,
              discountAmount: item.discountAmount,
              taxRate: item.taxRate,
            );
          }
          await repo.checkout(
            branchId: branchId,
            cashierSessionId: sessionId,
            cartId: serverCart.id,
            payments: payments,
            customerId: customerId,
          );
          await db.delete('offline_orders',
              where: 'id = ?', whereArgs: [id]);
          synced++;
        } catch (_) {
          // Still unreachable — bump attempt counter, leave in queue
          await db.rawUpdate(
              'UPDATE offline_orders SET attempts = attempts + 1 WHERE id = ?',
              [id]);
        }
      }
      await _refreshCount(db);
    } finally {
      _isSyncing = false;
    }
    return synced;
  }

  // Remove a specific entry (e.g., user manually dismisses it)
  Future<void> remove(String id) async {
    final db = await _database;
    await db.delete('offline_orders', where: 'id = ?', whereArgs: [id]);
    await _refreshCount(db);
  }

  Future<void> clearAll() async {
    final db = await _database;
    await db.delete('offline_orders');
    pendingCount.value = 0;
  }
}

final offlineQueueService = OfflineQueueService();
