import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bip39/bip39.dart' as bip39;
import 'package:crypto/crypto.dart' as crypto_hash;
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import 'address.dart';
import 'native/octra_core_bridge.dart';
import 'native/pvac_operations.dart';
import 'rpc.dart';
import 'models.dart';
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
  final OctraCoreBridge nativeCore = createOctraCoreBridge();
  late final PvacOperations pvac = PvacOperations(nativeCore);
  
  // State
  double publicBalance = 0.0;
  int nonce = 0;
  
  // Encrypted State
  double encryptedBalance = 0.0;
  int encryptedRaw = 0;
  List<dynamic> pendingPrivateTransfers = [];
  
  // History
  List<Map<String, dynamic>> history = [];
  List<Map<String, dynamic>> tokens = [];
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
      if (nativeCore.isAvailable) {
        await nativeCore.health();
      }

      final results = await Future.wait([
        rpc.getBalanceAndNonce(wallet.address),
        rpc.getStaging(),
      ]);

      final bn = results[0];
      final staging = results[1];

      publicBalance = bn['balance'];
      nonce = bn['nonce'];

      if (staging.containsKey('staged_transactions')) {
        final staged = staging['staged_transactions'] as List;
        final myStaged = staged.where((tx) => tx['from'] == wallet.address);
        if (myStaged.isNotEmpty) {
          final maxStaged = myStaged
              .map((tx) => int.parse(tx['nonce'].toString()))
              .reduce((curr, next) => curr > next ? curr : next);
          if (maxStaged > nonce) {
            nonce = maxStaged;
          }
        }
      }

      await _fetchEncryptedBalance(wallet);
      await _fetchHistory(limit: 20, offset: 0);

    } catch (e) {
      print("Refresh error: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchHistory({int limit = 20, int offset = 0}) async {
    if (currentWallet == null) return;
    try {
      final res = await rpc.getAddressInfo("${currentWallet!.address}?limit=$limit");
      final txList = res?['recent_transactions'] ?? res?['transactions'];
      if (txList is List) {
        final List<dynamic> recents = txList;
        history = recents.map((tx) {
          final Map<String, dynamic> newTx = Map.from(tx);

          final String from = (tx['from'] ?? "").toString();
          final bool isOut = from == currentWallet!.address;
          newTx['direction'] = isOut ? 'OUT' : 'IN';

          final rawAmt = double.tryParse(
                tx['amount_raw']?.toString() ?? tx['amount']?.toString() ?? '0',
              ) ??
              0.0;
          final displayAmt = rawAmt.abs() >= 1000000 ? rawAmt / 1000000.0 : rawAmt;
          newTx['amount'] = displayAmt.toString();

          return newTx;
        }).toList();
      }
    } catch (e) {
      print("History fetch error: $e");
    }
  }

  Future<Map<String, dynamic>?> getTransactionFullDetails(String hash) async {
    final res = await rpc.getTx(hash);
    final body = rpc.rpcResult(res);
    if (body is Map<String, dynamic>) {
      return body;
    }
    if (body is Map) {
      return Map<String, dynamic>.from(body);
    }
    if (res.statusCode == 200 && res.json is Map) {
      return Map<String, dynamic>.from(res.json as Map);
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
    final payload = <String, dynamic>{
      "from": wallet.address,
      "to_": to, // Note: cli.py uses 'to_' (line 502)
      "amount": (amount * 1000000).toInt().toString(),
      "nonce": txNonce,
      "ou": amount < 1000 ? "10000" : "30000",
      "timestamp": (DateTime.now().millisecondsSinceEpoch / 1000).toDouble(),
      "op_type": "standard",
    };
    
    if (msg != null && msg.isNotEmpty) {
      payload["message"] = msg;
    }

    final signed = await _signTxPayload(wallet, payload);

    return await rpc.sendTransaction(signed);
  }

  Future<List<RpcResponse>> sendBulkPublicTransfers(
    List<Map<String, String>> recipients,
  ) async {
    if (currentWallet == null) return [RpcResponse(0, "No wallet", null)];
    final wallet = currentWallet!;
    final filtered = recipients.where((item) {
      final to = item['to']?.trim() ?? '';
      final amount = double.tryParse(item['amount']?.trim() ?? '');
      return to.isNotEmpty && amount != null && amount > 0;
    }).toList();

    if (filtered.isEmpty) return [RpcResponse(0, "No valid recipients", null)];
    if (filtered.length > 5) return [RpcResponse(0, "Bulk send supports up to 5 recipients", null)];

    await refresh();
    final startNonce = await _nextNonce(wallet);
    final responses = <RpcResponse>[];

    for (var i = 0; i < filtered.length; i++) {
      final item = filtered[i];
      final amount = double.parse(item['amount']!.trim());
      final amountRaw = (amount * 1000000).toInt();
      final message = item['message']?.trim() ?? '';
      final payload = <String, dynamic>{
        "from": wallet.address,
        "to_": item['to']!.trim(),
        "amount": amountRaw.toString(),
        "nonce": startNonce + i,
        "ou": amount < 1000 ? "10000" : "30000",
        "timestamp": (DateTime.now().millisecondsSinceEpoch / 1000).toDouble(),
        "op_type": "standard",
      };
      if (message.isNotEmpty) {
        payload["message"] = message;
      }

      final signed = await _signTxPayload(wallet, payload);
      final res = await rpc.sendTransaction(signed);
      responses.add(res);
      if (rpc.rpcError(res) != null) break;
    }

    await refresh();
    return responses;
  }

  Future<List<Map<String, dynamic>>> loadTokens() async {
    final wallet = currentWallet;
    if (wallet == null) return const [];

    final custom = await _customTokenAddresses(wallet);
    final detected = <String>{};
    final loaded = <Map<String, dynamic>>[];

    try {
      final contracts = await rpc.listContractsRpc();
      for (final item in contracts) {
        if (item is Map && item['address'] != null) {
          detected.add(item['address'].toString());
        }
      }
    } catch (e) {
      print("Token contract list error: $e");
    }

    final addresses = {...custom, ...detected}.where((addr) => addr.isNotEmpty);
    for (final address in addresses) {
      final token = await _loadToken(address, wallet.address);
      if (token == null) continue;
      final balance = token['balance']?.toString() ?? '0';
      if (custom.contains(address) || balance != '0') {
        loaded.add(token);
      }
    }

    tokens = loaded;
    notifyListeners();
    return loaded;
  }

  Future<Map<String, dynamic>?> importCustomToken(String contractAddress) async {
    final wallet = currentWallet;
    final address = contractAddress.trim();
    if (wallet == null || address.isEmpty) return null;

    final token = await _loadToken(address, wallet.address);
    if (token == null) return null;

    final custom = await _customTokenAddresses(wallet);
    if (!custom.contains(address)) {
      custom.add(address);
      await _storage.write(
        key: 'custom_tokens_${wallet.address}',
        value: jsonEncode(custom),
      );
    }

    await loadTokens();
    return token;
  }

  Future<void> removeCustomToken(String contractAddress) async {
    final wallet = currentWallet;
    if (wallet == null) return;
    final custom = await _customTokenAddresses(wallet);
    custom.remove(contractAddress);
    await _storage.write(
      key: 'custom_tokens_${wallet.address}',
      value: jsonEncode(custom),
    );
    await loadTokens();
  }

  Future<RpcResponse> transferToken(
    Map<String, dynamic> token,
    String to,
    String humanAmount,
  ) async {
    final wallet = currentWallet;
    if (wallet == null) return RpcResponse(0, "No wallet", null);

    final tokenAddress = token['address']?.toString() ?? '';
    final decimals = int.tryParse(token['decimals']?.toString() ?? '0') ?? 0;
    final rawAmount = _parseUnits(humanAmount, decimals);
    final rawAmountInt = rawAmount == null ? null : int.tryParse(rawAmount);
    if (tokenAddress.isEmpty ||
        to.trim().isEmpty ||
        rawAmountInt == null ||
        rawAmountInt <= 0) {
      return RpcResponse(0, "Invalid token transfer", null);
    }

    final txNonce = await _nextNonce(wallet);
    final payload = <String, dynamic>{
      "from": wallet.address,
      "to_": tokenAddress,
      "amount": "0",
      "nonce": txNonce,
      "ou": "1000",
      "timestamp": (DateTime.now().millisecondsSinceEpoch / 1000).toDouble(),
      "op_type": "call",
      "encrypted_data": "transfer",
      "message": jsonEncode([to.trim(), rawAmountInt]),
    };
    final signed = await _signTxPayload(wallet, payload);
    final res = await rpc.sendTransaction(signed);
    await loadTokens();
    return res;
  }

  /// ENCRYPT BALANCE
  Future<RpcResponse> encryptMoney(double amount) async {
    if (currentWallet == null) return RpcResponse(0, "No wallet", null);
    final wallet = currentWallet!;
    await refresh(); // ensure encryptedRaw is up to date

    final amountRaw = (amount * 1000000).toInt();
    if (amountRaw <= 0) return RpcResponse(0, "Invalid amount", null);
    if (!nativeCore.isAvailable) {
      return RpcResponse(0, "Native PVAC core is not available", null);
    }

    final registered = await ensurePvacRegistered();
    if (!registered) {
      return RpcResponse(0, "PVAC registration failed", null);
    }

    final pvacResult = await pvac.encryptBalance(
      privateKeyBase64: wallet.privateKeyBase64,
      amountRaw: amountRaw,
    );

    final encryptedData = jsonEncode(pvacResult['encrypted_data']);
    final tx = await _buildSelfPrivacyTx(
      wallet: wallet,
      amountRaw: amountRaw,
      opType: 'encrypt',
      encryptedData: encryptedData,
      ou: '10000',
    );

    final res = await rpc.sendTransaction(tx);
    await refresh();
    return res;
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
    if (!nativeCore.isAvailable) {
      return RpcResponse(0, "Native PVAC core is not available", null);
    }

    final cipher = await _fetchEncryptedCipher(wallet);
    if (cipher == null || cipher == '0') {
      return RpcResponse(0, "No encrypted cipher available", null);
    }

    final registered = await ensurePvacRegistered();
    if (!registered) {
      return RpcResponse(0, "PVAC registration failed", null);
    }

    final pvacResult = await pvac.decryptBalance(
      privateKeyBase64: wallet.privateKeyBase64,
      amountRaw: amountRaw,
      currentCipher: cipher,
      currentBalanceRaw: currentRaw,
    );

    final encryptedData = jsonEncode(pvacResult['encrypted_data']);
    final tx = await _buildSelfPrivacyTx(
      wallet: wallet,
      amountRaw: amountRaw,
      opType: 'decrypt',
      encryptedData: encryptedData,
      ou: '10000',
    );

    final res = await rpc.sendTransaction(tx);
    await refresh();
    return res;
  }
  
  /// CREATE PRIVATE TRANSFER
  Future<RpcResponse> makePrivateTransfer(String toAddr, double amount) async {
    if (currentWallet == null) return RpcResponse(0, "No wallet", null);
    final wallet = currentWallet!;

    await refresh();
    final amountRaw = (amount * 1000000).toInt();
    if (amountRaw <= 0) return RpcResponse(0, "Invalid amount", null);
    if (encryptedRaw < amountRaw) {
      return RpcResponse(0, "Insufficient encrypted balance", null);
    }
    if (!nativeCore.isAvailable) {
      return RpcResponse(0, "Native PVAC core is not available", null);
    }

    final toPubKey = await rpc.getPublicKey(toAddr);
    if (toPubKey == null || toPubKey.isEmpty) {
      return RpcResponse(0, "Recipient public key not found", null);
    }

    final cipher = await _fetchEncryptedCipher(wallet);
    if (cipher == null || cipher == '0') {
      return RpcResponse(0, "No encrypted cipher available", null);
    }

    final registered = await ensurePvacRegistered();
    if (!registered) {
      return RpcResponse(0, "PVAC registration failed", null);
    }

    final stealth = await pvac.stealthPrepareSend(
      privateKeyBase64: wallet.privateKeyBase64,
      recipientAddress: toAddr,
      recipientPublicKeyBase64: toPubKey,
      amountRaw: amountRaw,
      currentCipher: cipher,
      currentBalanceRaw: encryptedRaw,
    );

    final tx = await _buildPrivacyTx(
      wallet: wallet,
      to: 'stealth',
      amountRaw: 0,
      opType: 'stealth',
      encryptedData: jsonEncode(stealth['encrypted_data']),
      ou: '5000',
    );
    final res = await rpc.sendTransaction(tx);
    await refresh();
    return res;
  }
  
  /// CLAIM PRIVATE TRANSFER
  Future<bool> claimTransfer(String transferId, String ephPubKey, String encryptedAmount) async {
    final claims = await scanStealthTransfers();
    final claim = claims.firstWhere(
      (item) => item['id'].toString() == transferId,
      orElse: () => <String, dynamic>{},
    );
    if (claim.isEmpty) return false;
    final res = await claimStealthTransfer(claim);
    return rpc.rpcError(res) == null;
  }

  Future<List<Map<String, dynamic>>> scanStealthTransfers() async {
    final wallet = currentWallet;
    if (wallet == null || !nativeCore.isAvailable) return const [];

    final outputs = await rpc.getStealthOutputsRpc();
    final result = await pvac.stealthScanOutputs(
      privateKeyBase64: wallet.privateKeyBase64,
      outputs: outputs,
    );
    final claims = result['claims'];
    if (claims is! List) return const [];
    return claims
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<RpcResponse> claimStealthTransfer(Map<String, dynamic> claim) async {
    final wallet = currentWallet;
    if (wallet == null) return RpcResponse(0, "No wallet", null);
    if (!nativeCore.isAvailable) {
      return RpcResponse(0, "Native PVAC core is not available", null);
    }

    final amountRaw = int.tryParse(claim['amount_raw']?.toString() ?? '0') ?? 0;
    final claimSecret = claim['claim_secret']?.toString() ?? '';
    final blinding = claim['blinding_b64']?.toString() ?? claim['blinding']?.toString() ?? '';
    if (amountRaw <= 0 || claimSecret.isEmpty || blinding.isEmpty) {
      return RpcResponse(0, "Invalid claim payload", null);
    }

    final registered = await ensurePvacRegistered();
    if (!registered) {
      return RpcResponse(0, "PVAC registration failed", null);
    }

    final prepared = await pvac.stealthPrepareClaim(
      privateKeyBase64: wallet.privateKeyBase64,
      outputId: claim['id'],
      amountRaw: amountRaw,
      claimSecret: claimSecret,
      blindingBase64: blinding,
    );

    final tx = await _buildPrivacyTx(
      wallet: wallet,
      to: wallet.address,
      amountRaw: 0,
      opType: 'claim',
      encryptedData: jsonEncode(prepared['encrypted_data']),
      ou: '3000',
    );
    final res = await rpc.sendTransaction(tx);
    await refresh();
    return res;
  }

  Future<bool> ensurePvacRegistered() async {
    final wallet = currentWallet;
    if (wallet == null || !nativeCore.isAvailable) return false;

    final registration = await pvac.registerPubkey(
      privateKeyBase64: wallet.privateKeyBase64,
    );
    final localPvacPubkey = registration['pubkey_b64']?.toString();
    final aesKatHex = registration['aes_kat_hex']?.toString() ?? '';
    if (localPvacPubkey == null || localPvacPubkey.isEmpty) return false;

    final remote = await rpc.getPvacPubkeyRpc(wallet.address);
    final remotePvacPubkey = remote?['pvac_pubkey']?.toString();
    if (remotePvacPubkey == localPvacPubkey) return true;
    if (remotePvacPubkey != null && remotePvacPubkey.isNotEmpty && remotePvacPubkey != 'null') {
      print("PVAC key conflict for ${wallet.address}");
      return false;
    }

    final publicKeyBase64 = await _walletPublicKeyBase64(wallet);
    final rawPvacPubkey = base64Decode(localPvacPubkey);
    final pvacHash = crypto_hash.sha256.convert(rawPvacPubkey).toString();
    final signature = await _signMessageBase64(
      wallet,
      "register_pvac|${wallet.address}|$pvacHash",
    );

    final res = await rpc.registerPvacPubkeyRpc(
      wallet.address,
      localPvacPubkey,
      signature,
      publicKeyBase64,
      aesKatHex,
    );

    if (rpc.rpcError(res) == null) return true;
    final error = rpc.rpcError(res) ?? res.text;
    return error.contains('already registered');
  }

  Future<List<String>> _customTokenAddresses(Wallet wallet) async {
    final raw = await _storage.read(key: 'custom_tokens_${wallet.address}');
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((item) => item.toString()).where((item) => item.isNotEmpty).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>?> _loadToken(String address, String walletAddress) async {
    try {
      final symbolValue = await rpc.contractStorageRpc(address, 'symbol');
      final symbol = symbolValue?.toString() ?? '';
      if (symbol.isEmpty || symbol == '0' || symbol == 'null') return null;

      final nameValue = await rpc.contractStorageRpc(address, 'name');
      final decimalsValue = await rpc.contractStorageRpc(address, 'decimals');
      final supplyValue = await rpc.contractStorageRpc(address, 'total_supply');
      final balance = await rpc.contractCallViewRpc(
        address,
        'balance_of',
        [walletAddress],
        walletAddress,
      );

      return {
        'address': address,
        'symbol': symbol.length > 10 ? symbol.substring(0, 10) : symbol,
        'name': (nameValue?.toString().isNotEmpty ?? false) ? nameValue.toString() : symbol,
        'decimals': decimalsValue?.toString() ?? '0',
        'total_supply': supplyValue?.toString() ?? '0',
        'balance': balance?.toString() ?? '0',
      };
    } catch (e) {
      print("Token load error for $address: $e");
      return null;
    }
  }

  String? _parseUnits(String humanAmount, int decimals) {
    var value = humanAmount.trim();
    if (value.isEmpty || value.startsWith('-')) return null;
    final parts = value.split('.');
    if (parts.length > 2) return null;

    final whole = parts[0].replaceAll(RegExp(r'[^0-9]'), '');
    var fraction = parts.length == 2 ? parts[1].replaceAll(RegExp(r'[^0-9]'), '') : '';
    if (whole.isEmpty && fraction.isEmpty) return null;
    if (fraction.length > decimals) {
      fraction = fraction.substring(0, decimals);
    }
    while (fraction.length < decimals) {
      fraction += '0';
    }

    final raw = '${whole.isEmpty ? '0' : whole}$fraction'.replaceFirst(RegExp(r'^0+'), '');
    return raw.isEmpty ? '0' : raw;
  }

  Future<void> _fetchEncryptedBalance(Wallet wallet) async {
    encryptedBalance = 0.0;
    encryptedRaw = 0;
    pendingPrivateTransfers = [];

    if (!nativeCore.isAvailable) return;

    try {
      final publicKeyBase64 = await _walletPublicKeyBase64(wallet);
      final signature = await _signMessageBase64(
        wallet,
        "octra_encryptedBalance|${wallet.address}",
      );
      final result = await rpc.getEncryptedBalanceRpc(
        wallet.address,
        signature,
        publicKeyBase64,
      );
      final cipher = result?['cipher']?.toString() ?? result?['encrypted_balance']?.toString() ?? '0';
      if (cipher.isEmpty || cipher == '0') return;

      final decrypted = await pvac.fheDecrypt(
        privateKeyBase64: wallet.privateKeyBase64,
        cipher: cipher,
      );
      final raw = int.tryParse(decrypted['amount_raw']?.toString() ?? '0') ?? 0;
      encryptedRaw = raw < 0 ? 0 : raw;
      encryptedBalance = encryptedRaw / 1000000.0;
    } catch (e) {
      print("Encrypted balance refresh error: $e");
    }
  }

  Future<String?> _fetchEncryptedCipher(Wallet wallet) async {
    final publicKeyBase64 = await _walletPublicKeyBase64(wallet);
    final signature = await _signMessageBase64(
      wallet,
      "octra_encryptedBalance|${wallet.address}",
    );
    final balance = await rpc.getEncryptedBalanceRpc(
      wallet.address,
      signature,
      publicKeyBase64,
    );
    final cipher = balance?['cipher']?.toString();
    if (cipher != null && cipher.isNotEmpty) return cipher;

    final cipherResult = await rpc.getEncryptedCipherRpc(wallet.address);
    return cipherResult?['cipher']?.toString();
  }

  Future<Map<String, dynamic>> _buildSelfPrivacyTx({
    required Wallet wallet,
    required int amountRaw,
    required String opType,
    required String encryptedData,
    required String ou,
  }) async {
    return _buildPrivacyTx(
      wallet: wallet,
      to: wallet.address,
      amountRaw: amountRaw,
      opType: opType,
      encryptedData: encryptedData,
      ou: ou,
    );
  }

  Future<Map<String, dynamic>> _buildPrivacyTx({
    required Wallet wallet,
    required String to,
    required int amountRaw,
    required String opType,
    required String encryptedData,
    required String ou,
  }) async {
    final txNonce = await _nextNonce(wallet);
    final payload = <String, dynamic>{
      "from": wallet.address,
      "to_": to,
      "amount": amountRaw.toString(),
      "nonce": txNonce,
      "ou": ou,
      "timestamp": (DateTime.now().millisecondsSinceEpoch / 1000).toDouble(),
      "op_type": opType,
      "encrypted_data": encryptedData,
    };
    return _signTxPayload(wallet, payload);
  }

  Future<int> _nextNonce(Wallet wallet) async {
    final bn = await rpc.getBalanceAndNonce(wallet.address);
    var currentNonce = int.tryParse(bn['nonce'].toString()) ?? nonce;
    final staging = await rpc.getStaging();
    final staged = staging['staged_transactions'] ?? staging['transactions'];
    if (staged is List) {
      final myStaged = staged.where((tx) => tx is Map && tx['from'] == wallet.address);
      if (myStaged.isNotEmpty) {
        final maxStagedNonce = myStaged
            .map((tx) => int.tryParse((tx as Map)['nonce'].toString()) ?? 0)
            .reduce((cur, next) => cur > next ? cur : next);
        if (maxStagedNonce > currentNonce) currentNonce = maxStagedNonce;
      }
    }
    return currentNonce + 1;
  }

  Future<Map<String, dynamic>> _signTxPayload(
    Wallet wallet,
    Map<String, dynamic> payload,
  ) async {
    final signature = await _signMessageBase64(wallet, _canonicalTxJson(payload));
    final publicKeyBase64 = await _walletPublicKeyBase64(wallet);
    final signed = Map<String, dynamic>.from(payload);
    signed["signature"] = signature;
    signed["public_key"] = publicKeyBase64;
    return signed;
  }

  String _canonicalTxJson(Map<String, dynamic> tx) {
    final buffer = StringBuffer();
    buffer.write('{"from":${jsonEncode(tx["from"])}');
    buffer.write(',"to_":${jsonEncode(tx["to_"])}');
    buffer.write(',"amount":${jsonEncode(tx["amount"].toString())}');
    buffer.write(',"nonce":${tx["nonce"]}');
    buffer.write(',"ou":${jsonEncode(tx["ou"].toString())}');
    buffer.write(',"timestamp":${jsonEncode(tx["timestamp"])}');
    buffer.write(',"op_type":${jsonEncode((tx["op_type"] ?? "standard").toString())}');
    final encryptedData = tx["encrypted_data"]?.toString() ?? '';
    if (encryptedData.isNotEmpty) {
      buffer.write(',"encrypted_data":${jsonEncode(encryptedData)}');
    }
    final message = tx["message"]?.toString() ?? '';
    if (message.isNotEmpty) {
      buffer.write(',"message":${jsonEncode(message)}');
    }
    buffer.write('}');
    return buffer.toString();
  }

  Future<String> _walletPublicKeyBase64(Wallet wallet) async {
    final privKeyBytes = base64Decode(wallet.privateKeyBase64);
    final keyPair = await Ed25519().newKeyPairFromSeed(privKeyBytes);
    final pubKey = await keyPair.extractPublicKey();
    return base64Encode(pubKey.bytes);
  }

  Future<String> _signMessageBase64(Wallet wallet, String message) async {
    final privKeyBytes = base64Decode(wallet.privateKeyBase64);
    final keyPair = await Ed25519().newKeyPairFromSeed(privKeyBytes);
    final signature = await Ed25519().sign(
      utf8.encode(message),
      keyPair: keyPair,
    );
    return base64Encode(signature.bytes);
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
