import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'octra_core_bridge.dart';

class PvacOperations {
  final OctraCoreBridge core;
  final Random _random;

  PvacOperations(this.core, {Random? random}) : _random = random ?? Random.secure();

  Future<Map<String, dynamic>> registerPubkey({
    required String privateKeyBase64,
  }) {
    return _execute({
      'op': 'register_pubkey',
      'private_key_b64': privateKeyBase64,
    });
  }

  Future<Map<String, dynamic>> fheEncrypt({
    required String privateKeyBase64,
    required int amountRaw,
  }) {
    return _execute({
      'op': 'fhe_encrypt',
      'private_key_b64': privateKeyBase64,
      'amount_raw': amountRaw.toString(),
      'seed_b64': _randomBase64(32),
    });
  }

  Future<Map<String, dynamic>> fheDecrypt({
    required String privateKeyBase64,
    required String cipher,
  }) {
    return _execute({
      'op': 'fhe_decrypt',
      'private_key_b64': privateKeyBase64,
      'cipher': cipher,
    });
  }

  Future<Map<String, dynamic>> encryptBalance({
    required String privateKeyBase64,
    required int amountRaw,
  }) {
    return _execute({
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
    return _execute({
      'op': 'decrypt_balance',
      'private_key_b64': privateKeyBase64,
      'amount_raw': amountRaw.toString(),
      'current_cipher': currentCipher,
      'current_balance_raw': currentBalanceRaw.toString(),
      'seed_b64': _randomBase64(32),
      'blinding_b64': _randomBase64(32),
    });
  }

  Future<Map<String, dynamic>> deriveViewKeypair({
    required String privateKeyBase64,
  }) {
    return _execute({
      'op': 'derive_view_keypair',
      'private_key_b64': privateKeyBase64,
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
    return _execute({
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
    return _execute({
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
    return _execute({
      'op': 'stealth_prepare_claim',
      'private_key_b64': privateKeyBase64,
      'output_id': outputId,
      'amount_raw': amountRaw.toString(),
      'claim_secret': claimSecret,
      'blinding_b64': blindingBase64,
      'seed_b64': _randomBase64(32),
    });
  }

  Future<Map<String, dynamic>> _execute(Map<String, dynamic> payload) async {
    if (!core.isAvailable) {
      throw StateError('Octra native core is not available');
    }

    final result = await core.executePrivacyOperation(payload);
    if (result['ok'] != true) {
      throw StateError((result['error'] ?? 'PVAC operation failed').toString());
    }
    return result;
  }

  String _randomBase64(int length) {
    final bytes = Uint8List(length);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return base64Encode(bytes);
  }
}
