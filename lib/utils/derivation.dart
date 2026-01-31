import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto_pkg;
import 'package:cryptography/cryptography.dart';

// Constants
const int _h = 0x80000000;
const String _seedKey = "Octra seed";

class Keys {
  final Uint8List privateKey; // 32 bytes
  final Uint8List chainCode; // 32 bytes

  Keys(this.privateKey, this.chainCode);
}

/// Matches walletgen.js deriveMasterKey
Keys deriveMasterKey(Uint8List seed) {
  final hmac = crypto_pkg.Hmac(crypto_pkg.sha512, utf8.encode(_seedKey));
  final digest = hmac.convert(seed);
  final bytes = digest.bytes;
  
  return Keys(
    Uint8List.fromList(bytes.sublist(0, 32)),
    Uint8List.fromList(bytes.sublist(32, 64)),
  );
}

/// Matches walletgen.js deriveChildKeyEd25519
Future<Keys> deriveChildKeyEd25519(Keys parent, int index) async {
  final indexBytes = Uint8List(4);
  final bd = ByteData.view(indexBytes.buffer);
  bd.setUint32(0, index, Endian.big);

  Uint8List data;

  if ((index & _h) != 0) {
    // Hardened
    // data = 0x00 || priv || index
    data = Uint8List.fromList([
      0x00,
      ...parent.privateKey,
      ...indexBytes,
    ]);
  } else {
    // Non-hardened
    // data = pub || index
    // Need public key from private key
    final algorithm = Ed25519();
    final keyPair = await algorithm.newKeyPairFromSeed(parent.privateKey);
    final pubKey = await keyPair.extractPublicKey();
    
    data = Uint8List.fromList([
      ...pubKey.bytes,
      ...indexBytes,
    ]);
  }

  final hmac = crypto_pkg.Hmac(crypto_pkg.sha512, parent.chainCode);
  final digest = hmac.convert(data);
  final bytes = digest.bytes;

  return Keys(
    Uint8List.fromList(bytes.sublist(0, 32)),
    Uint8List.fromList(bytes.sublist(32, 64)),
  );
}

/// Matches walletgen.js derivePath
Future<Keys> derivePath(Uint8List seed, List<int> path) async {
  var keys = deriveMasterKey(seed);
  
  for (final index in path) {
    keys = await deriveChildKeyEd25519(keys, index);
  }
  
  return keys;
}

/// Matches walletgen.js deriveForNetwork
/// Returns the private key and public key for the wallet
Future<Uint8List> deriveForNetwork(Uint8List seed, {
  int networkType = 0,
  int network = 0,
  int contract = 0,
  int account = 0,
  int index = 0,
  int token = 0,
  int subnet = 0,
}) async {
  final coinType = networkType == 0 ? 0 : networkType;
  
  final fullPath = [
    _h + 345,        // Purpose
    _h + coinType,   // Coin Type
    _h + network,    // Network
    _h + contract,   // Contract
    _h + account,    // Account
    _h + token,      // Token (Optional in js but in path construction)
    _h + subnet,     // Subnet (Optional in js but in path construction)
    index            // Index
  ];
  
  final keys = await derivePath(seed, fullPath);
  return keys.privateKey;
}
