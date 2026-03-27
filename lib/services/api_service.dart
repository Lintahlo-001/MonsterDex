import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api.dart';

class ApiService {
  static final String _base = ApiConfig.baseUrl;

  static Future<dynamic> post(
      String path, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('$_base$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return jsonDecode(res.body);
  }

  static Future<dynamic> get(String path) async {
    final res = await http.get(Uri.parse('$_base$path'));
    return jsonDecode(res.body);
  }

  static Future<dynamic> put(
      String path, Map<String, dynamic> body) async {
    final res = await http.put(
      Uri.parse('$_base$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    final data = jsonDecode(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return data;
    } else {
      throw Exception(data['error'] ?? 'Request failed');
    }
  }

  static Future<dynamic> delete(String path) async {
    final res = await http.delete(Uri.parse('$_base$path'));
    return jsonDecode(res.body);
  }
}