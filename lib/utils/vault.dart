import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

const int kVaultKdfIterations = 150000;
final AesGcm _vaultAes = AesGcm.with256bits();
final Pbkdf2 _vaultKdf = Pbkdf2(
  macAlgorithm: Hmac.sha256(),
  iterations: kVaultKdfIterations,
  bits: 256,
);

class WalletVaultEnvelope {
  final int version;
  final String mode;
  final String blobB64;
  final String? saltB64;

  const WalletVaultEnvelope({
    required this.version,
    required this.mode,
    required this.blobB64,
    this.saltB64,
  });

  Map<String, dynamic> toJson() => {
        'version': version,
        'mode': mode,
        'blob': blobB64,
        if (saltB64 != null) 'salt': saltB64,
      };

  factory WalletVaultEnvelope.fromJson(Map<String, dynamic> json) {
    return WalletVaultEnvelope(
      version: int.tryParse(json['version']?.toString() ?? '1') ?? 1,
      mode: json['mode']?.toString() ?? 'device',
      blobB64: json['blob']?.toString() ?? '',
      saltB64: json['salt']?.toString(),
    );
  }
}

Uint8List randomBytes(int length) {
  final rng = Random.secure();
  return Uint8List.fromList(List<int>.generate(length, (_) => rng.nextInt(256)));
}

Future<SecretKey> deriveVaultKeyFromPin(String pin, Uint8List salt) async {
  return _vaultKdf.deriveKey(
    secretKey: SecretKey(utf8.encode(pin)),
    nonce: salt,
  );
}

Future<String> encryptTextWithKey(
  String plaintext,
  SecretKey key, {
  Uint8List? nonce,
}) async {
  final usedNonce = nonce ?? _vaultAes.newNonce();
  final box = await _vaultAes.encrypt(
    utf8.encode(plaintext),
    secretKey: key,
    nonce: usedNonce,
  );
  final packed = <int>[
    ...usedNonce,
    ...box.cipherText,
    ...box.mac.bytes,
  ];
  return base64Encode(packed);
}

Future<String> decryptTextWithKey(
  String blobB64,
  SecretKey key,
) async {
  final raw = base64Decode(blobB64);
  if (raw.length < 28) {
    throw StateError('Invalid vault payload');
  }
  final nonce = raw.sublist(0, 12);
  final cipherWithTag = raw.sublist(12);
  if (cipherWithTag.length < 16) {
    throw StateError('Invalid vault payload');
  }
  final cipher = cipherWithTag.sublist(0, cipherWithTag.length - 16);
  final tag = cipherWithTag.sublist(cipherWithTag.length - 16);
  final box = SecretBox(cipher, nonce: nonce, mac: Mac(tag));
  final clearBytes = await _vaultAes.decrypt(box, secretKey: key);
  return utf8.decode(clearBytes);
}

String encodeVaultEnvelope(WalletVaultEnvelope envelope) {
  return jsonEncode(envelope.toJson());
}

WalletVaultEnvelope? decodeVaultEnvelope(String raw) {
  if (raw.isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      return WalletVaultEnvelope.fromJson(Map<String, dynamic>.from(decoded));
    }
  } catch (_) {
    return null;
  }
  return null;
}
