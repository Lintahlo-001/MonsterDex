import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api.dart';
import 'package:flutter/foundation.dart';

class LambdaService {
  static Future<String> getInstanceState(
      String instanceId, String region) async {
    try {
      final res = await http.post(
        Uri.parse(ApiConfig.lambdaUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'status',
          'instance_id': instanceId,
          'region': region,
        }),
      ).timeout(const Duration(seconds: 10));

      debugPrint('getInstanceState raw body: ${res.body}');
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['state'] as String? ?? 'unknown';
    } catch (e) {
      debugPrint('getInstanceState error: $e');
      return 'unknown';
    }
  }

  static Future<bool> toggleInstance(
      String instanceId, String region, String action) async {
    try {
      final res = await http.post(
        Uri.parse(ApiConfig.lambdaUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': action,
          'instance_id': instanceId,
          'region': region,
        }),
      ).timeout(const Duration(seconds: 15));

      print('toggleInstance [$action] status: ${res.statusCode}, body: ${res.body}');
      return res.statusCode == 200;
    } catch (e) {
      print('toggleInstance error: $e');
      return false;
    }
  }
}