import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

Future<Uint8List> signTx(
  Uint8List privateKey,
  Uint8List message,
) async {
  final kp = await Ed25519().newKeyPairFromSeed(privateKey);
  final sig = await Ed25519().sign(
    message,
    keyPair: kp,
  );
  return Uint8List.fromList(sig.bytes);
}
