import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/order.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../services/local_db.dart';

class AppProvider extends ChangeNotifier {
  bool isLoggedIn = false;
  bool isOnline = true;
  List<Order> orders = [];
  List<Product> products = [];
  bool loading = false;

  Future<bool> _checkOnline() async {
    try {
      final res = await http
          .get(Uri.parse('https://francoise-subhumid-maire.ngrok-free.dev/health'))
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<void> login(String url, String pin) async {
    final token = await ApiService.login(url, pin);
    await ApiService.saveConfig(url, token);
    isLoggedIn = true;
    isOnline = true;
    notifyListeners();
    await refreshAll();
  }

  Future<void> refreshAll() async {
    isOnline = await _checkOnline();
    await refreshOrders();
    await refreshProducts();
  }

  Future<void> refreshOrders() async {
    loading = true;
    notifyListeners();
    try {
      if (isOnline) {
        final fresh = await ApiService.getOrders();
        await LocalDB.saveOrders(fresh);
        orders = fresh;
      } else {
        orders = await LocalDB.getOrders();
      }
    } catch (_) {
      orders = await LocalDB.getOrders();
    }
    loading = false;
    notifyListeners();
  }

  Future<void> refreshProducts() async {
    try {
      if (isOnline) {
        products = await ApiService.getProducts();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> deliverOrder(int id) async {
    if (isOnline) {
      await ApiService.deliverOrder(id);
    } else {
      await LocalDB.markDelivered(id);
    }
    orders.removeWhere((o) => o.id == id);
    notifyListeners();
  }

  Future<void> addComment(int id, String comment) async {
    if (isOnline) {
      await ApiService.addComment(id, comment);
    } else {
      await LocalDB.updateComment(id, comment);
    }
    final idx = orders.indexWhere((o) => o.id == id);
    if (idx >= 0) {
      orders[idx].comment = comment;
      notifyListeners();
    }
  }

  Future<void> createProduct(Product p) async {
    final created = await ApiService.createProduct(p);
    products.add(created);
    notifyListeners();
  }

  Future<void> updateProduct(int id, Map<String, dynamic> data) async {
    final updated = await ApiService.updateProduct(id, data);
    final idx = products.indexWhere((p) => p.id == id);
    if (idx >= 0) {
      products[idx] = updated;
      notifyListeners();
    }
  }

  Future<void> deleteProduct(int id) async {
    await ApiService.deleteProduct(id);
    products.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  Future<void> syncPendingActions() async {
    if (!isOnline) return;
    final pending = await LocalDB.getPendingSync();
    for (final action in pending) {
      try {
        if (action['action'] == 'deliver') {
          await ApiService.deliverOrder(action['id']);
        } else if (action['action'] == 'comment') {
          await ApiService.addComment(action['id'], action['comment']);
        }
      } catch (_) {}
    }
    await LocalDB.clearPendingSync();
    await refreshAll();
  }
}
