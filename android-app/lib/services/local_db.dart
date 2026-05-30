import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/order.dart';

class LocalDB {
  static Database? _db;

  static Future<Database> get db async {
    _db ??= await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'pedidos_local.db');
    return openDatabase(path, version: 1, onCreate: (db, v) async {
      await db.execute('''
        CREATE TABLE orders (
          id INTEGER PRIMARY KEY,
          product_name TEXT, product_price REAL,
          delivery_address TEXT, is_fiado INTEGER,
          status TEXT, wa_message TEXT, comment TEXT,
          requested_at TEXT, delivered_at TEXT,
          customer_name TEXT, customer_phone TEXT,
          pending_sync INTEGER DEFAULT 0
        )
      ''');
    });
  }

  static Future<void> saveOrders(List<Order> orders) async {
    final d = await db;
    final batch = d.batch();
    for (final o in orders) {
      batch.insert('orders', o.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Order>> getOrders() async {
    final d = await db;
    final maps = await d.query('orders',
      where: "status = 'pending'", orderBy: 'requested_at DESC');
    return maps.map(Order.fromJson).toList();
  }

  static Future<void> markDelivered(int id) async {
    final d = await db;
    await d.update('orders',
      {'status': 'delivered', 'pending_sync': 1}, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> updateComment(int id, String comment) async {
    final d = await db;
    await d.update('orders',
      {'comment': comment, 'pending_sync': 1}, where: 'id = ?', whereArgs: [id]);
  }

  static Future<List<Order>> getPendingSync() async {
    final d = await db;
    final maps = await d.query('orders', where: 'pending_sync = 1');
    return maps.map(Order.fromJson).toList();
  }

  static Future<void> clearSynced(int id) async {
    final d = await db;
    await d.update('orders', {'pending_sync': 0}, where: 'id = ?', whereArgs: [id]);
  }
}
