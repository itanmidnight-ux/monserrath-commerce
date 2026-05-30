import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/order.dart';

class LocalDB {
  static const _ordersKey = 'cached_orders';
  static const _pendingSyncKey = 'pending_sync';

  static Future<void> saveOrders(List<Order> orders) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = orders.map((o) => jsonEncode(o.toMap())).toList();
    await prefs.setStringList(_ordersKey, jsonList);
  }

  static Future<List<Order>> getOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_ordersKey) ?? [];
    return jsonList
        .map((s) => Order.fromJson(jsonDecode(s)))
        .where((o) => o.status == 'pending')
        .toList();
  }

  static Future<void> markDelivered(int id) async {
    final orders = await _getAllOrders();
    final idx = orders.indexWhere((o) => o.id == id);
    if (idx >= 0) {
      orders[idx].status = 'delivered';
      orders[idx].pendingSync = true;
      await saveOrders(orders);
      await _addPendingSync({'action': 'deliver', 'id': id});
    }
  }

  static Future<void> updateComment(int id, String comment) async {
    final orders = await _getAllOrders();
    final idx = orders.indexWhere((o) => o.id == id);
    if (idx >= 0) {
      orders[idx].comment = comment;
      orders[idx].pendingSync = true;
      await saveOrders(orders);
      await _addPendingSync({'action': 'comment', 'id': id, 'comment': comment});
    }
  }

  static Future<List<Order>> _getAllOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_ordersKey) ?? [];
    return jsonList.map((s) => Order.fromJson(jsonDecode(s))).toList();
  }

  static Future<void> _addPendingSync(Map<String, dynamic> action) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_pendingSyncKey) ?? [];
    existing.add(jsonEncode(action));
    await prefs.setStringList(_pendingSyncKey, existing);
  }

  static Future<List<Map<String, dynamic>>> getPendingSync() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_pendingSyncKey) ?? [];
    return list.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
  }

  static Future<void> clearPendingSync() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingSyncKey);
  }
}
