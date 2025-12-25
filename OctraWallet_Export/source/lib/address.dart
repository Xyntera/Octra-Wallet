import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

const _alphabet =
    '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

String _base58(Uint8List bytes) {
  BigInt n = BigInt.parse(
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    radix: 16,
  );
  const base = 58;
  var result = '';
  while (n > BigInt.zero) {
    final mod = n % BigInt.from(base);
    result = _alphabet[mod.toInt()] + result;
    n ~/= BigInt.from(base);
  }
  return result;
}

Future<String> octraAddressFromPubKey(Uint8List pubKey) async {
  final hash = await Sha256().hash(pubKey);
  return 'oct${_base58(Uint8List.fromList(hash.bytes))}';
}
