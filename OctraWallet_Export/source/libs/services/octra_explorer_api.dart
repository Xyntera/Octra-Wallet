import 'dart:convert';
import 'package:http/http.dart' as http;

class OctraExplorerApi {
  static const String _baseUrl = 'https://octra.network';

  /// Fetch address overview:
  /// balance, nonce, tx hashes
  static Future<Map<String, dynamic>> fetchAddress(String address) async {
    final uri = Uri.parse('$_baseUrl/address/$address');
    final res = await http.get(uri);

    if (res.statusCode != 200) {
      throw Exception('failed to fetch address data');
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Fetch full transaction details
  /// used to decode from / to / amount
  static Future<Map<String, dynamic>> fetchTx(String hash) async {
    final uri = Uri.parse('$_baseUrl/tx/$hash');
    final res = await http.get(uri);

    if (res.statusCode != 200) {
      throw Exception('failed to fetch transaction');
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
