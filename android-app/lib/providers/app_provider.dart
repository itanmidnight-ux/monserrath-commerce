import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
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

  AppProvider() {
    Connectivity().onConnectivityChanged.listen((results) {
      isOnline = results.isNotEmpty &&
        results.any((r) => r != ConnectivityResult.none);
      if (isOnline && isLoggedIn) syncPendingActions();
      notifyListeners();
    });
  }

  Future<void> login(String url, String pin) async {
    final token = await ApiService.login(url, pin);
    await ApiService.saveConfig(url, token);
    isLoggedIn = true;
    notifyListeners();
    await refreshAll();
  }

  Future<void> refreshAll() async {
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
    final pending = await LocalDB.getPendingSync();
    for (final o in pending) {
      try {
        if (o.status == 'delivered') await ApiService.deliverOrder(o.id!);
        if (o.comment != null) await ApiService.addComment(o.id!, o.comment!);
        await LocalDB.clearSynced(o.id!);
      } catch (_) {}
    }
  }
}
