import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'octra_core_bridge.dart';

class PvacWorker {
  Future<void> _tail = Future.value();
  final Random _random;

  PvacWorker({Random? random}) : _random = random ?? Random.secure();

  Future<Map<String, dynamic>> registerPubkey({
    required String privateKeyBase64,
  }) {
    return _enqueue({
      'op': 'register_pubkey',
      'private_key_b64': privateKeyBase64,
    });
  }

  Future<Map<String, dynamic>> fheDecrypt({
    required String privateKeyBase64,
    required String cipher,
  }) {
    return _enqueue({
      'op': 'fhe_decrypt',
      'private_key_b64': privateKeyBase64,
      'cipher': cipher,
    });
  }

  Future<Map<String, dynamic>> encryptBalance({
    required String privateKeyBase64,
    required int amountRaw,
  }) {
    return _enqueue({
      'op': 'encrypt_balance',
      'private_key_b64': privateKeyBase64,
      'amount_raw': amountRaw.toString(),
      'seed_b64': _randomBase64(32),
      'blinding_b64': _randomBase64(32),
    });
  }

  Future<Map<String, dynamic>> decryptBalance({
    required String privateKeyBase64,
    required int amountRaw,
    required String currentCipher,
    required int currentBalanceRaw,
  }) {
    return _enqueue({
      'op': 'decrypt_balance',
      'private_key_b64': privateKeyBase64,
      'amount_raw': amountRaw.toString(),
      'current_cipher': currentCipher,
      'current_balance_raw': currentBalanceRaw.toString(),
      'seed_b64': _randomBase64(32),
      'blinding_b64': _randomBase64(32),
    });
  }

  Future<Map<String, dynamic>> stealthPrepareSend({
    required String privateKeyBase64,
    required String recipientAddress,
    required String recipientPublicKeyBase64,
    required int amountRaw,
    required String currentCipher,
    required int currentBalanceRaw,
  }) {
    return _enqueue({
      'op': 'stealth_prepare_send',
      'private_key_b64': privateKeyBase64,
      'recipient_address': recipientAddress,
      'recipient_public_key_b64': recipientPublicKeyBase64,
      'amount_raw': amountRaw.toString(),
      'current_cipher': currentCipher,
      'current_balance_raw': currentBalanceRaw.toString(),
      'seed_b64': _randomBase64(32),
      'blinding_b64': _randomBase64(32),
      'ephemeral_private_key_b64': _randomBase64(32),
    });
  }

  Future<Map<String, dynamic>> stealthScanOutputs({
    required String privateKeyBase64,
    required List<dynamic> outputs,
  }) {
    return _enqueue({
      'op': 'stealth_scan_outputs',
      'private_key_b64': privateKeyBase64,
      'outputs': outputs,
    });
  }

  Future<Map<String, dynamic>> stealthPrepareClaim({
    required String privateKeyBase64,
    required dynamic outputId,
    required int amountRaw,
    required String claimSecret,
    required String blindingBase64,
  }) {
    return _enqueue({
      'op': 'stealth_prepare_claim',
      'private_key_b64': privateKeyBase64,
      'output_id': outputId,
      'amount_raw': amountRaw.toString(),
      'claim_secret': claimSecret,
      'blinding_b64': blindingBase64,
      'seed_b64': _randomBase64(32),
    });
  }

  Future<Map<String, dynamic>> _enqueue(Map<String, dynamic> payload) {
    final completer = Completer<Map<String, dynamic>>();
    _tail = _tail.catchError((_) {}).then((_) async {
      try {
        completer.complete(await Isolate.run(() => _executePvac(payload)));
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  String _randomBase64(int length) {
    final bytes = Uint8List(length);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return base64Encode(bytes);
  }
}

Future<Map<String, dynamic>> _executePvac(Map<String, dynamic> payload) async {
  final core = createOctraCoreBridge();
  if (!core.isAvailable) {
    throw StateError(
        core.unavailableReason ?? 'Octra native core is not available');
  }

  final result = await core.executePrivacyOperation(payload);
  if (result['ok'] != true) {
    throw StateError((result['error'] ?? 'PVAC operation failed').toString());
  }
  return result;
}
