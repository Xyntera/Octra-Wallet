import 'dart:convert';
import 'package:http/http.dart' as http;

class WalletApi {
  static const String baseUrl = 'https://ouqro.tech';

  static Future<Map<String, dynamic>> generateWallet() async {
    final res = await http.post(
      Uri.parse('$baseUrl/generate'),
    );

    if (res.statusCode != 200) {
      throw Exception('wallet generation failed');
    }

    return jsonDecode(res.body);
  }
}
