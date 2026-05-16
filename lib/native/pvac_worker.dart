import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';

import 'octra_core_bridge.dart';

class PvacWorker {
  final List<_QueuedPvacTask> _queue = [];
  bool _draining = false;
  final Random _random;

  PvacWorker({Random? random}) : _random = random ?? Random.secure();

  Future<Map<String, dynamic>> registerPubkey({
    required String privateKeyBase64,
  }) {
    return _enqueue({
      'op': 'register_pubkey',
      'private_key_b64': privateKeyBase64,
    }, timeout: const Duration(seconds: 90));
  }

  Future<Map<String, dynamic>> fheDecrypt({
    required String privateKeyBase64,
    required String cipher,
  }) {
    return _enqueue({
      'op': 'fhe_decrypt',
      'private_key_b64': privateKeyBase64,
      'cipher': cipher,
    }, timeout: const Duration(seconds: 45));
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
    }, timeout: const Duration(minutes: 2));
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
    }, timeout: const Duration(minutes: 2));
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
    }, timeout: const Duration(minutes: 3));
  }

  Future<Map<String, dynamic>> stealthScanOutputs({
    required String privateKeyBase64,
    required List<dynamic> outputs,
  }) {
    return _enqueue({
      'op': 'stealth_scan_outputs',
      'private_key_b64': privateKeyBase64,
      'outputs': outputs,
    }, timeout: const Duration(minutes: 2));
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
    }, timeout: const Duration(minutes: 2));
  }

  Future<Map<String, dynamic>> _enqueue(
    Map<String, dynamic> payload, {
    required Duration timeout,
  }) {
    final completer = Completer<Map<String, dynamic>>();
    _queue.add(_QueuedPvacTask(payload: payload, timeout: timeout, completer: completer));
    _drainQueue();
    return completer.future;
  }

  void _drainQueue() {
    if (_draining || _queue.isEmpty) return;
    _draining = true;
    _processNext();
  }

  void _processNext() {
    if (_queue.isEmpty) {
      _draining = false;
      return;
    }

    final task = _queue.removeAt(0);
    var finished = false;
    Timer? timer;

    void completeQueue() {
      if (_queue.isNotEmpty) {
        _processNext();
      } else {
        _draining = false;
      }
    }

    void finishWithError(Object error, [StackTrace? stackTrace]) {
      if (finished) return;
      finished = true;
      timer?.cancel();
      if (!task.completer.isCompleted) {
        if (stackTrace != null) {
          task.completer.completeError(error, stackTrace);
        } else {
          task.completer.completeError(error);
        }
      }
      completeQueue();
    }

    timer = Timer(task.timeout, () {
      finishWithError(
        TimeoutException(
          'PVAC ${task.operation} timed out after ${task.timeout.inSeconds} seconds',
        ),
      );
    });

    compute(_executePvac, task.payload).then((result) {
      if (finished) return;
      finished = true;
      timer?.cancel();
      if (!task.completer.isCompleted) {
        task.completer.complete(result);
      }
      completeQueue();
    }).catchError((error, stackTrace) {
      finishWithError(error, stackTrace);
    });
  }

  String _randomBase64(int length) {
    final bytes = Uint8List(length);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return base64Encode(bytes);
  }
}

class _QueuedPvacTask {
  final Map<String, dynamic> payload;
  final Duration timeout;
  final Completer<Map<String, dynamic>> completer;

  _QueuedPvacTask({
    required this.payload,
    required this.timeout,
    required this.completer,
  });

  String get operation => payload['op']?.toString() ?? 'pvac_operation';
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
