import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cryptography/cryptography.dart';

import '../models/wallet_model.dart';
import '../models/transaction_model.dart';
import '../models/recipient_model.dart';

import '../services/wallet_generator.dart';
import '../services/wallet_importer.dart';
import '../services/octra_explorer_api.dart';
import '../services/storage/secure_storage.dart';

class WalletProvider extends ChangeNotifier {
  WalletModel? wallet;

  // ===== UI EXPECTED FIELDS =====
  double publicBalance = 0.0;
  double encryptedBalance = 0.0;
  int nonce = 0;

  bool generating = false;
  bool historyLoading = false;
  bool sending = false;

  String? sendError;

  List<String> logs = [];
  List<TransactionModel> history = [];

  // ===== LOAD =====
  Future<void> loadSavedWallet() async {
    wallet = await SecureWalletStorage.load();
    if (wallet != null) {
      await refreshBalance();
      await refreshHistory();
    }
    notifyListeners();
  }

  // ===== GENERATE =====
  Future<void> generateWallet() async {
    generating = true;
    logs.clear();
    logs.add('generating wallet...');
    notifyListeners();

    final g = await WalletGenerator.generate();

    wallet = WalletModel(
      address: g.address,
      privateKeyB64: g.privateKeyB64,
      publicKeyB64: g.publicKeyB64,
      mnemonic: g.mnemonic,
      nonce: 0,
    );

    await SecureWalletStorage.save(wallet!);
    logs.add('wallet generated');
    generating = false;
    notifyListeners();
  }

  // ===== IMPORT =====
  Future<void> importFromMnemonic(String mnemonic) async {
    final seedKey = await WalletImporter.fromMnemonic(mnemonic);
    await _importFromPrivateKey(seedKey, mnemonic.split(' '));
  }

  Future<void> importFromPrivateKey(String b64) async {
    final key = WalletImporter.fromPrivateKeyBase64(b64);
    await _importFromPrivateKey(key, []);
  }

  Future<void> _importFromPrivateKey(
    Uint8List privateKey,
    List<String> mnemonic,
  ) async {
    final kp = await Ed25519().newKeyPairFromSeed(privateKey);
    final pub = (await kp.extractPublicKey()).bytes;

    final hash = await Sha256().hash(pub);
    final address = WalletGenerator.createAddress(hash.bytes);

    wallet = WalletModel(
      address: address,
      privateKeyB64: base64.encode(privateKey),
      publicKeyB64: base64.encode(pub),
      mnemonic: mnemonic,
      nonce: 0,
    );

    await SecureWalletStorage.save(wallet!);
    await refreshBalance();
    await refreshHistory();
    notifyListeners();
  }

  // ===== BALANCE =====
  Future<void> refreshBalance() async {
    if (wallet == null) return;

    final data = await OctraExplorerApi.fetchAddress(wallet!.address);
    publicBalance = double.parse(data['balance']);
    nonce = data['nonce'];
    encryptedBalance = 0.0; // placeholder
    notifyListeners();
  }

  // ===== HISTORY (DECODED) =====
  Future<void> refreshHistory() async {
    if (wallet == null) return;

    historyLoading = true;
    notifyListeners();

    final overview =
        await OctraExplorerApi.fetchAddress(wallet!.address);

    final List<TransactionModel> decoded = [];

    for (final tx in overview['recent_transactions']) {
      final hash = tx['hash'];
      final txData = await OctraExplorerApi.fetchTx(hash);

      decoded.add(
        TransactionModel(
          hash: hash,
          epoch: txData['epoch'],
          from: txData['from'],
          to: txData['to'],
          amount: double.parse(txData['amount']) / 1e6,
        ),
      );
    }

    history = decoded;
    historyLoading = false;
    notifyListeners();
  }

  // ===== SEND (STUB, UI SAFE) =====
  Future<void> send({
    required String to,
    required double amount,
    String? message,
  }) async {
    sending = true;
    sendError = null;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 400));

    sending = false;
    notifyListeners();
  }

  // ===== LOGOUT =====
  Future<void> logout() async {
    await SecureWalletStorage.clear();
    wallet = null;
    history.clear();
    publicBalance = 0;
    encryptedBalance = 0;
    logs.clear();
    notifyListeners();
  }
}
