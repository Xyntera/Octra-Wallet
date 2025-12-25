import 'dart:convert';
import 'package:http/http.dart' as http;

class OctraExplorerApi {
  static const _base = 'https://octra.network';

  static Future<Map<String, dynamic>> fetchAddress(String address) async {
    final res = await http.get(Uri.parse('$_base/address/$address'));
    if (res.statusCode != 200) {
      throw Exception('failed to load address');
    }
    return jsonDecode(res.body);
  }
}
