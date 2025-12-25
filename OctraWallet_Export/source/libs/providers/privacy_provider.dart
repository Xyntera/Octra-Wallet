import 'package:flutter/material.dart';
import '../models/pending_tx_model.dart';
import '../services/api/privacy_api.dart';
import 'wallet_provider.dart';

class PrivacyProvider extends ChangeNotifier {
  double encryptedBalance = 0;
  List<PendingTxModel> pending = [];
  bool loading = false;
  String? error;

  Future<void> encrypt(WalletProvider wp, double amount) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      await PrivacyApi.encrypt(
        address: wp.wallet!.address,
        amount: amount,
      );
      await wp.refreshBalance();
    } catch (e) {
      error = e.toString();
    }

    loading = false;
    notifyListeners();
  }

  Future<void> decrypt(WalletProvider wp, double amount) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      await PrivacyApi.decrypt(
        address: wp.wallet!.address,
        amount: amount,
      );
      await wp.refreshBalance();
    } catch (e) {
      error = e.toString();
    }

    loading = false;
    notifyListeners();
  }

  Future<void> privateSend(
    WalletProvider wp,
    String to,
    double amount,
  ) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      await PrivacyApi.privateSend(
        from: wp.wallet!.address,
        to: to,
        amount: amount,
        nonce: wp.wallet!.nonce,
      );
      wp.wallet!.nonce += 1;
      await wp.refreshBalance();
      await loadPending(wp);
    } catch (e) {
      error = e.toString();
    }

    loading = false;
    notifyListeners();
  }

  Future<void> loadPending(WalletProvider wp) async {
    try {
      final res =
          await PrivacyApi.pending(address: wp.wallet!.address);
      pending = (res['pending'] as List)
          .map((e) => PendingTxModel.fromJson(e))
          .toList();
    } catch (_) {}
    notifyListeners();
  }
}
