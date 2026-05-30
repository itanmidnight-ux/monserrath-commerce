import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../models/message.dart';

class ApiService {
  static String _baseUrl = '';
  static String _token = '';

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString('server_url') ?? '';
    _token = prefs.getString('jwt_token') ?? '';
  }

  static Future<void> saveConfig(String url, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', url);
    await prefs.setString('jwt_token', token);
    _baseUrl = url;
    _token = token;
  }

  static bool get isConfigured => _baseUrl.isNotEmpty && _token.isNotEmpty;

  static Map<String, String> get _headers => {
    'Authorization': 'Bearer $_token',
    'Content-Type': 'application/json',
  };

  static Future<String> login(String url, String pin) async {
    final res = await http.post(
      Uri.parse('$url/api/auth/token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'pin': pin}),
    ).timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) return jsonDecode(res.body)['token'];
    throw Exception('PIN incorrecto');
  }

  static Future<List<Order>> getOrders() async {
    final res = await http.get(Uri.parse('$_baseUrl/api/orders'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List).map((j) => Order.fromJson(j)).toList();
    }
    throw Exception('Error pedidos: ${res.statusCode}');
  }

  static Future<void> deliverOrder(int id) async {
    final res = await http.put(
      Uri.parse('$_baseUrl/api/orders/$id/deliver'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) throw Exception('Error entregando');
  }

  static Future<void> addComment(int id, String comment) async {
    await http.put(Uri.parse('$_baseUrl/api/orders/$id/comment'),
      headers: _headers, body: jsonEncode({'comment': comment}))
        .timeout(const Duration(seconds: 10));
  }

  static Future<List<Product>> getProducts() async {
    final res = await http.get(Uri.parse('$_baseUrl/api/products'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List).map((j) => Product.fromJson(j)).toList();
    }
    throw Exception('Error productos');
  }

  static Future<Product> createProduct(Product p) async {
    final res = await http.post(Uri.parse('$_baseUrl/api/products'),
      headers: _headers, body: jsonEncode(p.toJson()))
        .timeout(const Duration(seconds: 10));
    return Product.fromJson(jsonDecode(res.body));
  }

  static Future<Product> updateProduct(int id, Map<String, dynamic> data) async {
    final res = await http.put(Uri.parse('$_baseUrl/api/products/$id'),
      headers: _headers, body: jsonEncode(data))
        .timeout(const Duration(seconds: 10));
    return Product.fromJson(jsonDecode(res.body));
  }

  static Future<void> deleteProduct(int id) async {
    await http.delete(Uri.parse('$_baseUrl/api/products/$id'), headers: _headers)
        .timeout(const Duration(seconds: 10));
  }

  static Future<List<Conversation>> getConversations() async {
    final res = await http.get(Uri.parse('$_baseUrl/api/messages'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List)
          .map((j) => Conversation.fromJson(j)).toList();
    }
    throw Exception('Error conversaciones');
  }

  static Future<List<Message>> getMessages(String phone) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/messages/${Uri.encodeComponent(phone)}'),
      headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List)
          .map((j) => Message.fromJson(j)).toList();
    }
    throw Exception('Error mensajes');
  }

  static Future<void> sendWhatsAppMessage(String phone, String content) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/messages/send'),
      headers: _headers,
      body: jsonEncode({'phone': phone, 'content': content}))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) throw Exception('Error enviando mensaje');
  }
}
