import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:bip39/bip39.dart' as bip39;

class GeneratedWallet {
  final String address;
  final String privateKeyB64;
  final String publicKeyB64;
  final List<String> mnemonic;

  GeneratedWallet({
    required this.address,
    required this.privateKeyB64,
    required this.publicKeyB64,
    required this.mnemonic,
  });
}

class WalletGenerator {
  static const _alphabet =
      '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

  static String _base58(Uint8List bytes) {
    BigInt intData = BigInt.parse(
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      radix: 16,
    );

    final base = BigInt.from(58);
    String result = '';
    while (intData > BigInt.zero) {
      final mod = intData % base;
      intData = intData ~/ base;
      result = _alphabet[mod.toInt()] + result;
    }
    return result;
  }

  static String createAddress(List<int> pubKeyHash) {
    return 'oct${_base58(Uint8List.fromList(pubKeyHash))}';
  }

  static Future<GeneratedWallet> generate() async {
    final mnemonic = bip39.generateMnemonic().split(' ');
    final seed = bip39.mnemonicToSeed(mnemonic.join(' '));

    final mac = await Hmac.sha512().calculateMac(
      seed,
      secretKey: SecretKeyData('Octra seed'.codeUnits),
    );

    final priv = mac.bytes.sublist(0, 32);
    final keyPair =
        await Ed25519().newKeyPairFromSeed(Uint8List.fromList(priv));
    final pub = (await keyPair.extractPublicKey()).bytes;

    final hash = await Sha256().hash(pub);

    return GeneratedWallet(
      address: createAddress(hash.bytes),
      privateKeyB64: base64.encode(priv),
      publicKeyB64: base64.encode(pub),
      mnemonic: mnemonic,
    );
  }
}
