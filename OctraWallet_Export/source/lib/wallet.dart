import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bip39/bip39.dart' as bip39;
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import 'address.dart';
import 'rpc.dart';
import 'models.dart';
import 'utils/crypto.dart' as crypto_ops;
import 'utils/derivation.dart' as crypto_utils;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class WalletController extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();

  // Security
  Future<bool> get hasPin async => await _storage.containsKey(key: 'user_pin');

  Future<bool> get isSecurityEnabled async {
    final val = await _storage.read(key: 'security_enabled');
    if (val == null) return await hasPin; // Default to enabled if PIN exists but no setting
    return val == 'true'; 
  }

  Future<void> setSecurityEnabled(bool enabled) async {
    await _storage.write(key: 'security_enabled', value: enabled.toString());
    notifyListeners();
  }

  Future<void> setPin(String pin) async {
    await _storage.write(key: 'user_pin', value: pin);
    // Auto-enable security when setting PIN
    await setSecurityEnabled(true); 
    notifyListeners();
  }

  Future<bool> checkPin(String pin) async {
    final stored = await _storage.read(key: 'user_pin');
    return stored == pin;
  }
  
  List<Wallet> wallets = [];
  Wallet? currentWallet;
  
  RpcClient rpc = RpcClient();
  
  // State
  double publicBalance = 0.0;
  int nonce = 0;
  
  // Encrypted State
  double encryptedBalance = 0.0;
  int encryptedRaw = 0;
  List<dynamic> pendingPrivateTransfers = [];
  
  // History
  List<Map<String, dynamic>> history = [];
  bool isLoading = false;

  bool get hasWallet => currentWallet != null;

  /// INITIALIZATION
  Future<void> init() async {
    await loadWallets();
  }

  Future<void> loadWallets() async {
    try {
      final jsonStr = await _storage.read(key: 'wallets');
      if (jsonStr != null) {
        final List<dynamic> list = jsonDecode(jsonStr);
        wallets = list.map((e) => Wallet.fromJson(e)).toList();
        if (wallets.isNotEmpty) {
          // Load last selected
          final lastAddr = await _storage.read(key: 'last_selected_wallet');
          if (lastAddr != null && wallets.any((w) => w.address == lastAddr)) {
             currentWallet = wallets.firstWhere((w) => w.address == lastAddr);
          } else {
             currentWallet = wallets.first; // Default to first
          }
          refresh(); // Background update (fixes startup lag)
        }
      }
    } catch (e) {
      print("Error loading wallets: $e");
    }
    notifyListeners();
  }

  Future<void> _saveWallets() async {
    try {
      final jsonStr = jsonEncode(wallets.map((w) => w.toJson()).toList());
      await _storage.write(key: 'wallets', value: jsonStr);
    } catch (e) {
      print("Error saving wallets: $e");
    }
  }

  Future<void> selectWallet(Wallet w) async {
    currentWallet = w;
    await _storage.write(key: 'last_selected_wallet', value: w.address);
    notifyListeners();
    await refresh();
  }

  /// GENERATE NEW (Returns data for UI Backup first, DOES NOT SAVE YET)
  Future<Map<String, String>> generateNewWalletData() async {
    return await compute(_generateWalletWorker, null);
  }

  /// SAVE IMPORTED/GENERATED WALLET
  Future<void> addWallet(String address, String privateKeyBase64, [String? mnemonic]) async {
    // Check duplicate
    if (wallets.any((w) => w.address == address)) {
       // Just switch to it
       currentWallet = wallets.firstWhere((w) => w.address == address);
    } else {
      final name = "Wallet ${wallets.length + 1}";
      final colors = [0xFF357AF6, 0xFF32D74B, 0xFFFF9F0A, 0xFFFF375F, 0xFFBF5AF2, 0xFFFFD60A, 0xFF64D2FF, 0xFF8E8E93, 0xFF007AFF, 0xFF5856D6, 0xFFFF2D55, 0xFFAF52DE];
      final color = colors[wallets.length % colors.length];

      final newWallet = Wallet(
        address: address, 
        privateKeyBase64: privateKeyBase64, 
        mnemonic: mnemonic,
        name: name,
        color: color
      );
      wallets.add(newWallet);
      currentWallet = newWallet;
      await _saveWallets();
    }
    notifyListeners();
    await refresh();
  }

  Future<void> updateWallet(String address, {String? name, int? color}) async {
    final index = wallets.indexWhere((w) => w.address == address);
    if (index == -1) return;
    
    final old = wallets[index];
    wallets[index] = Wallet(
      address: old.address,
      privateKeyBase64: old.privateKeyBase64,
      mnemonic: old.mnemonic,
      name: name ?? old.name,
      color: color ?? old.color,
    );
    
    if (currentWallet?.address == address) {
      currentWallet = wallets[index];
    }
    
    await _saveWallets();
    notifyListeners();
  }

  Future<void> deleteWallet(String address) async {
    wallets.removeWhere((w) => w.address == address);
    
    if (currentWallet?.address == address) {
      if (wallets.isNotEmpty) {
        currentWallet = wallets.first;
        _storage.write(key: 'last_selected_wallet', value: currentWallet!.address);
        refresh();
      } else {
        currentWallet = null;
        _storage.delete(key: 'last_selected_wallet');
      }
    }
    
    await _saveWallets();
    notifyListeners();
  }

  /// IMPORT WALLET LOGIC (Returns wallet data for preview/confirm)
  Future<Map<String, String>?> processInput(String input) async {
    Uint8List privateKeyBytes;
    String? mnemonic;
    
    try {
      if (input.trim().split(RegExp(r'\s+')).length >= 12) {
        mnemonic = input.trim();
        final seed = bip39.mnemonicToSeed(mnemonic);
        privateKeyBytes = await crypto_utils.deriveForNetwork(Uint8List.fromList(seed));
      } else {
        privateKeyBytes = base64Decode(input.trim());
      }

      final algorithm = Ed25519();
      final keyPair = await algorithm.newKeyPairFromSeed(privateKeyBytes);
      final pubKey = await keyPair.extractPublicKey();
      final addr = await octraAddressFromPubKey(Uint8List.fromList(pubKey.bytes));

      return {
        'address': addr,
        'privateKeyBase64': base64Encode(privateKeyBytes),
        'mnemonic': mnemonic ?? ''
      };
    } catch (e) {
      print("Error processing input: $e");
      return null;
    }
  }

  /// REFRESH ALL DATA
  Future<void> refresh() async {
    if (currentWallet == null) return;
    final wallet = currentWallet!; // Use local var for thread safetyish
    isLoading = true;
    notifyListeners();

    try {
      // 1. Basic Info (Balance & Nonce) - matching cli.py st()
      // Parallel fetch balance and staging
      final results = await Future.wait([
        rpc.getBalanceAndNonce(wallet!.address),
        rpc.getStaging(),
      ]);
      
      final bn = results[0];
      final staging = results[1];
      
      publicBalance = bn['balance'];
      nonce = bn['nonce'];
      
      // Update nonce from staging if higher
      if (staging.containsKey('staged_transactions')) {
         final staged = staging['staged_transactions'] as List;
         final myStaged = staged.where((tx) => tx['from'] == wallet!.address);
         if (myStaged.isNotEmpty) {
            final maxStaged = myStaged.map((tx) => int.parse(tx['nonce'].toString())).reduce((curr, next) => curr > next ? curr : next);
            if (maxStaged > nonce) {
              nonce = maxStaged;
            }
         }
      }

      // 2. Encrypted Balance
      final encData = await rpc.getEncryptedBalance(wallet!.address, wallet!.privateKeyBase64);
      if (encData != null) {
        encryptedBalance = double.tryParse(encData['encrypted_balance']?.split(' ')[0] ?? "0") ?? 0.0;
        encryptedRaw = int.tryParse(encData['encrypted_balance_raw'].toString()) ?? 0;
      }

      // 3. Pending Transfers
      pendingPrivateTransfers = await rpc.getPendingPrivateTransfers(wallet!.address, wallet!.privateKeyBase64);

      // 4. History (Simplified)
      await _fetchHistory();

    } catch (e) {
      print("Refresh error: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchHistory() async {
    if (currentWallet == null) return;
    try {
      final res = await rpc.getAddressInfo("${currentWallet!.address}?limit=20");
      if (res != null && res.containsKey('recent_transactions')) {
         final List<dynamic> recents = res['recent_transactions'];
         history = recents.map((tx) {
           final Map<String, dynamic> newTx = Map.from(tx);
           
           // Direction
           final String from = (tx['from'] ?? "").toString();
           final bool isOut = from == currentWallet!.address; 
           newTx['direction'] = isOut ? 'OUT' : 'IN';
           
           // Amount (handle raw string "1000000" -> 1.0)
           final rawAmt = double.tryParse(tx['amount'].toString()) ?? 0.0;
           final displayAmt = rawAmt / 1000000.0;
           newTx['amount'] = displayAmt.toString(); // Store normalized string for UI
           
           return newTx;
         }).toList();
      }
    } catch (e) {
      print("History fetch error: $e");
    }
  }

  Future<Map<String, dynamic>?> getTransactionFullDetails(String hash) async {
     final res = await rpc.getTx(hash);
     if (res.statusCode == 200 && res.json != null) {
        return res.json;
     }
     return null;
  }
  
  /// SEND TRANSACTION
  Future<RpcResponse> sendTransaction(String to, double amount, String? msg) async {
    if (currentWallet == null) return RpcResponse(0, "", null);
    final wallet = currentWallet!;
    
    // Refresh nonce first
    await refresh(); // or just get staging
    
    // Get staging nonce
    final staging = await rpc.getStaging();
    int currentNonce = nonce;
    if (staging.containsKey('staged_transactions')) {
       final staged = staging['staged_transactions'] as List;
       final myStaged = staged.where((tx) => tx['from'] == wallet.address);
       if (myStaged.isNotEmpty) {
          final maxStagedNonce = myStaged.map((tx) => int.parse(tx['nonce'].toString())).reduce((cur, next) => cur > next ? cur : next);
          if (maxStagedNonce >= currentNonce) {
            currentNonce = maxStagedNonce;
          }
       }
    }

    final txNonce = currentNonce + 1;
    final payload = {
      "from": wallet.address,
      "to_": to, // Note: cli.py uses 'to_' (line 502)
      "amount": (amount * 1000000).toInt().toString(),
      "nonce": txNonce,
      "ou": amount < 1000 ? "10000" : "30000",
      "timestamp": (DateTime.now().millisecondsSinceEpoch / 1000).toDouble()
    };
    
    if (msg != null && msg.isNotEmpty) {
      payload["message"] = msg;
    }

    // Sign
    // Remove message for signing blob
    final signMap = Map.of(payload);
    signMap.remove("message");
    
    // Canonical JSON: no spaces
    final jsonStr = jsonEncode(signMap); // Dart jsonEncode defaults to no spaces? No, it puts keys in quotes and colons.
    // Wait, jsonEncode might add spaces if pretty print? default is compact.
    // But map key order!
    // I need to enforce key order: from, to_, amount, nonce, ou, timestamp
    // Or just rely on the map insertion order which I defined above.
    
    final signBytes = utf8.encode(jsonStr);
    final privKeyBytes = base64Decode(wallet.privateKeyBase64);
    final algorithm = Ed25519();
    final keyPair = await algorithm.newKeyPairFromSeed(privKeyBytes);
    final signature = await algorithm.sign(signBytes, keyPair: keyPair);
    final sigBase64 = base64Encode(signature.bytes);
    
    final pubKey = await keyPair.extractPublicKey();
    final pubKeyBase64 = base64Encode(pubKey.bytes);

    payload["signature"] = sigBase64;
    payload["public_key"] = pubKeyBase64; // cli.py line 512

    return await rpc.sendTransaction(payload);
  }

  /// ENCRYPT BALANCE
  Future<RpcResponse> encryptMoney(double amount) async {
    if (currentWallet == null) return RpcResponse(0, "No wallet", null);
    final wallet = currentWallet!;
    await refresh(); // ensure encryptedRaw is up to date
    
    final currentRaw = encryptedRaw;
    final amountRaw = (amount * 1000000).toInt();
    final newRaw = currentRaw + amountRaw;
    
    final encryptedData = await crypto_ops.encryptClientBalance(newRaw, wallet.privateKeyBase64);
    
    return await rpc.encryptBalance(wallet.address, amount, wallet.privateKeyBase64, encryptedData);
  }

  /// DECRYPT BALANCE
  Future<RpcResponse> decryptMoney(double amount) async {
    if (currentWallet == null) return RpcResponse(0, "No wallet", null);
    final wallet = currentWallet!;
    await refresh();
    
    final currentRaw = encryptedRaw;
    final amountRaw = (amount * 1000000).toInt();
    
    if (currentRaw < amountRaw) {
      return RpcResponse(0, "Insufficient encrypted balance", null);
    }
    
    final newRaw = currentRaw - amountRaw;
    final encryptedData = await crypto_ops.encryptClientBalance(newRaw, wallet.privateKeyBase64);
    
    return await rpc.decryptBalance(wallet.address, amount, wallet.privateKeyBase64, encryptedData);
  }
  
  /// CREATE PRIVATE TRANSFER
  Future<RpcResponse> makePrivateTransfer(String toAddr, double amount) async {
    if (currentWallet == null) return RpcResponse(0, "No wallet", null);
    final wallet = currentWallet!;
    
    // Get Recipient Public Key
    final toPubKey = await rpc.getPublicKey(toAddr);
    if (toPubKey == null) {
      return RpcResponse(0, "Recipient public key not found", null);
    }
    
    return await rpc.createPrivateTransfer(
      wallet.address, 
      toAddr, 
      amount, 
      wallet.privateKeyBase64, 
      toPubKey
    );
  }
  
  /// CLAIM PRIVATE TRANSFER
  Future<bool> claimTransfer(String transferId, String ephPubKey, String encryptedAmount) async {
    if (currentWallet == null) return false;
    final wallet = currentWallet!;
    
    // 1. Derive shared secret
    final sharedSecret = await crypto_ops.deriveSharedSecretForClaim(wallet.privateKeyBase64, ephPubKey);
    
    // 2. Decrypt amount (verify we can decrypt it)
    final amount = await crypto_ops.decryptPrivateAmount(encryptedAmount, sharedSecret);
    if (amount == null) {
       print("Failed to decrypt transfer amount");
       return false;
    }
    
    // 3. Send claim
    final res = await rpc.claimPrivateTransfer(wallet.address, wallet.privateKeyBase64, transferId);
    if (res.statusCode == 200) {
      await refresh();
      return true;
    }
    return false;
  }
}

Future<Map<String, String>> _generateWalletWorker(dynamic _) async {
  final mnemonic = bip39.generateMnemonic();
  final seed = bip39.mnemonicToSeed(mnemonic);
  final privateKeyBytes = await crypto_utils.deriveForNetwork(Uint8List.fromList(seed));
  
  final algorithm = Ed25519();
  final keyPair = await algorithm.newKeyPairFromSeed(privateKeyBytes);
  final pubKey = await keyPair.extractPublicKey();
  final addr = await octraAddressFromPubKey(Uint8List.fromList(pubKey.bytes));
  
  return {
    'mnemonic': mnemonic,
    'address': addr,
    'privateKeyBase64': base64Encode(privateKeyBytes),
  };
}
