import 'dart:convert';
import 'dart:typed_data';
import 'package:bip39/bip39.dart' as bip39;
import 'package:cryptography/cryptography.dart';

class WalletImporter {
  static Future<Uint8List> fromMnemonic(String mnemonic) async {
    final seed = bip39.mnemonicToSeed(mnemonic);
    final mac = await Hmac.sha512().calculateMac(
      seed,
      secretKey: SecretKeyData('Octra seed'.codeUnits),
    );
    return Uint8List.fromList(mac.bytes.sublist(0, 32));
  }

  static Uint8List fromPrivateKeyBase64(String b64) {
    return Uint8List.fromList(base64.decode(b64));
  }
}
