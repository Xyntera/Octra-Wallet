import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bip39/bip39.dart' as bip39;
import 'package:crypto/crypto.dart' as crypto_hash;
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import 'address.dart';
import 'native/octra_core_bridge.dart';
import 'native/pvac_worker.dart';
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
    if (val == null)
      return await hasPin; // Default to enabled if PIN exists but no setting
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
  final PvacWorker pvacWorker = PvacWorker();

  // State
  double publicBalance = 0.0;
  int nonce = 0;

  // Encrypted State
  double encryptedBalance = 0.0;
  int encryptedRaw = 0;
  List<dynamic> pendingPrivateTransfers = [];

  // History
  List<Map<String, dynamic>> history = [];
  String? historyWalletAddress;
  List<Map<String, dynamic>> tokens = [];
  final Map<String, Map<String, String>> _tokenMetaCache = {};
  final Map<String, Map<String, dynamic>> _feeCache = {};
  final Set<String> _pvacRegistrationInFlight = {};
  DateTime? _feeCacheAt;
  int _refreshSerial = 0;
  bool isLoading = false;
  bool isPvacBusy = false;
  String? pvacStatus;

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
        wallets = await _repairWalletList(
          list
              .whereType<Map>()
              .map((e) => Wallet.fromJson(Map<String, dynamic>.from(e)))
              .toList(),
        );
        await _saveWallets();
        if (wallets.isNotEmpty) {
          // Load last selected
          final lastAddr = await _storage.read(key: 'last_selected_wallet');
          if (lastAddr != null && wallets.any((w) => w.address == lastAddr)) {
            currentWallet = wallets.firstWhere((w) => w.address == lastAddr);
          } else {
            currentWallet = wallets.first; // Default to first
          }
          refresh(); // Background update (fixes startup lag)
          registerCurrentPvacInBackground();
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
    final repaired = await _validatedWallet(w);
    _refreshSerial++;
    currentWallet = repaired;
    _clearWalletScopedState();
    final index = wallets.indexWhere((item) =>
        item.address == w.address ||
        item.privateKeyBase64 == w.privateKeyBase64);
    if (index != -1 && wallets[index].address != repaired.address) {
      wallets[index] = repaired;
      await _saveWallets();
    }
    await _storage.write(key: 'last_selected_wallet', value: repaired.address);
    notifyListeners();
    await refresh();
    registerCurrentPvacInBackground();
  }

  /// GENERATE NEW (Returns data for UI Backup first, DOES NOT SAVE YET)
  Future<Map<String, String>> generateNewWalletData() async {
    return await compute(_generateWalletWorker, null);
  }

  /// SAVE IMPORTED/GENERATED WALLET
  Future<void> addWallet(String address, String privateKeyBase64,
      [String? mnemonic]) async {
    final repairedInput = await _validatedWallet(Wallet(
      address: address,
      privateKeyBase64: privateKeyBase64,
      mnemonic: mnemonic?.isEmpty == true ? null : mnemonic,
      name: "Wallet ${wallets.length + 1}",
    ));
    address = repairedInput.address;
    privateKeyBase64 = repairedInput.privateKeyBase64;
    mnemonic = repairedInput.mnemonic;

    // Check duplicate
    if (wallets.any((w) => w.address == address)) {
      // Just switch to it
      _refreshSerial++;
      currentWallet = wallets.firstWhere((w) => w.address == address);
      _clearWalletScopedState();
    } else {
      final name = "Wallet ${wallets.length + 1}";
      final colors = [
        0xFF357AF6,
        0xFF32D74B,
        0xFFFF9F0A,
        0xFFFF375F,
        0xFFBF5AF2,
        0xFFFFD60A,
        0xFF64D2FF,
        0xFF8E8E93,
        0xFF007AFF,
        0xFF5856D6,
        0xFFFF2D55,
        0xFFAF52DE
      ];
      final color = colors[wallets.length % colors.length];

      final newWallet = Wallet(
          address: address,
          privateKeyBase64: privateKeyBase64,
          mnemonic: mnemonic,
          name: name,
          color: color);
      wallets.add(newWallet);
      _refreshSerial++;
      currentWallet = newWallet;
      _clearWalletScopedState();
      await _saveWallets();
    }
    notifyListeners();
    await refresh();
    registerCurrentPvacInBackground();
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
      _refreshSerial++;
      if (wallets.isNotEmpty) {
        currentWallet = wallets.first;
        _clearWalletScopedState();
        _storage.write(
            key: 'last_selected_wallet', value: currentWallet!.address);
        refresh();
      } else {
        currentWallet = null;
        _clearWalletScopedState();
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
      final normalizedInput = input.trim().replaceAll(RegExp(r'\s+'), ' ');
      final wordCount =
          normalizedInput.isEmpty ? 0 : normalizedInput.split(' ').length;
      if (wordCount >= 12) {
        mnemonic = normalizedInput.toLowerCase();
        if (!bip39.validateMnemonic(mnemonic)) {
          return null;
        }
        final seed = bip39.mnemonicToSeed(mnemonic);
        privateKeyBytes =
            await crypto_utils.deriveForNetwork(Uint8List.fromList(seed));
      } else {
        privateKeyBytes = _decodePrivateKey(normalizedInput);
      }

      if (privateKeyBytes.length != 32) return null;

      final algorithm = Ed25519();
      final keyPair = await algorithm.newKeyPairFromSeed(privateKeyBytes);
      final pubKey = await keyPair.extractPublicKey();
      final addr =
          await octraAddressFromPubKey(Uint8List.fromList(pubKey.bytes));

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

  Uint8List _decodePrivateKey(String input) {
    final clean = input.trim();
    if (RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(clean)) {
      final bytes = <int>[];
      for (var i = 0; i < clean.length; i += 2) {
        bytes.add(int.parse(clean.substring(i, i + 2), radix: 16));
      }
      return Uint8List.fromList(bytes);
    }
    return base64Decode(clean);
  }

  Future<List<Wallet>> _repairWalletList(List<Wallet> input) async {
    final repaired = <Wallet>[];
    final seen = <String>{};
    for (final wallet in input) {
      try {
        final checked = await _validatedWallet(wallet);
        if (seen.add(checked.address)) repaired.add(checked);
      } catch (e) {
        print("Skipping invalid wallet entry: $e");
      }
    }
    return repaired;
  }

  Future<Wallet> _validatedWallet(Wallet wallet) async {
    final derivedAddress = await _deriveAddressFromPrivateKey(wallet);
    if (derivedAddress == wallet.address) return wallet;
    print(
        "Wallet address repaired: stored ${wallet.address}, key derives $derivedAddress");
    return Wallet(
      address: derivedAddress,
      privateKeyBase64: wallet.privateKeyBase64,
      mnemonic: wallet.mnemonic,
      name: wallet.name,
      color: wallet.color,
    );
  }

  Future<String> _deriveAddressFromPrivateKey(Wallet wallet) async {
    final privKeyBytes = base64Decode(wallet.privateKeyBase64);
    if (privKeyBytes.length != 32) {
      throw StateError('Invalid private key length');
    }
    final keyPair = await Ed25519().newKeyPairFromSeed(privKeyBytes);
    final pubKey = await keyPair.extractPublicKey();
    return octraAddressFromPubKey(Uint8List.fromList(pubKey.bytes));
  }

  Future<bool> _walletMatchesPrivateKey(Wallet wallet) async {
    try {
      return await _deriveAddressFromPrivateKey(wallet) == wallet.address;
    } catch (_) {
      return false;
    }
  }

  void _clearWalletScopedState() {
    publicBalance = 0.0;
    nonce = 0;
    encryptedBalance = 0.0;
    encryptedRaw = 0;
    pendingPrivateTransfers = [];
    history = [];
    historyWalletAddress = currentWallet?.address;
    tokens = [];
  }

  bool _isActiveWallet(Wallet wallet) {
    return currentWallet?.address == wallet.address;
  }

  /// REFRESH ALL DATA
  Future<void> refresh() async {
    if (currentWallet == null) return;
    final wallet = currentWallet!; // Use local var for thread safetyish
    final refreshId = ++_refreshSerial;
    isLoading = true;
    historyWalletAddress = wallet.address;
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
      if (!_isActiveRefresh(refreshId, wallet)) return;

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
      if (!_isActiveRefresh(refreshId, wallet)) return;
      await _fetchHistory(wallet, limit: 20, offset: 0);
    } catch (e) {
      print("Refresh error: $e");
    } finally {
      if (_isActiveRefresh(refreshId, wallet)) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  bool _isActiveRefresh(int refreshId, Wallet wallet) {
    return refreshId == _refreshSerial && _isActiveWallet(wallet);
  }

  Future<void> _fetchHistory(Wallet wallet,
      {int limit = 20, int offset = 0}) async {
    try {
      final res = await rpc.getTransactionsByAddress(
        wallet.address,
        limit: limit,
        offset: offset,
      );
      final txList = res?['transactions'] ?? res?['recent_transactions'];
      if (currentWallet?.address != wallet.address) return;
      if (txList is List) {
        history = await Future.wait(
          txList.whereType<Map>().map((tx) => _normalizeHistoryTx(
              Map<String, dynamic>.from(tx), wallet.address)),
        );
        historyWalletAddress = wallet.address;
      } else {
        history = [];
        historyWalletAddress = wallet.address;
      }
    } catch (e) {
      if (currentWallet?.address == wallet.address) {
        history = [];
        historyWalletAddress = wallet.address;
      }
      print("History fetch error: $e");
    }
  }

  Future<Map<String, dynamic>> _normalizeHistoryTx(
    Map<String, dynamic> tx,
    String walletAddress,
  ) async {
    final normalized = Map<String, dynamic>.from(tx);
    final hash = (tx['hash'] ?? tx['tx_hash'] ?? '').toString();
    final from = (tx['from'] ?? '').toString();
    final to = (tx['to_'] ?? tx['to'] ?? '').toString();
    final opType = (tx['op_type'] ?? 'standard').toString();

    normalized['hash'] = hash;
    normalized['from'] = from;
    normalized['to'] = to;
    normalized['op_type'] = opType;

    var displayTo = to;
    var title = _titleForOp(opType, tx);
    var amountLabel = _formatOctAmount(tx['amount_raw'] ?? tx['amount']);
    var tokenSymbol = '';

    if (opType == 'call' && tx['encrypted_data']?.toString() == 'transfer') {
      final parsed = _parseTokenTransfer(tx);
      if (parsed != null) {
        displayTo = parsed['to'] ?? displayTo;
        final tokenMeta = await _loadTokenMeta(to);
        tokenSymbol = tokenMeta['symbol'] ?? '';
        final decimals = int.tryParse(tokenMeta['decimals'] ?? '0') ?? 0;
        amountLabel =
            _formatTokenAmount(parsed['amount'] ?? '0', decimals, tokenSymbol);
        title =
            tokenSymbol.isEmpty ? 'Token Transfer' : '$tokenSymbol Transfer';
      }
    } else if (opType == 'deploy') {
      final deployArgs = _parseJsonList(tx['message']);
      if (deployArgs != null && deployArgs.length >= 2) {
        tokenSymbol = deployArgs[1].toString();
        title = tokenSymbol.isEmpty ? 'Program Deploy' : 'Deploy $tokenSymbol';
      }
    } else if (opType == 'stealth' || opType == 'claim') {
      amountLabel = 'Private';
    }

    final isOut = from == walletAddress;
    final isIn = displayTo == walletAddress && !isOut;
    normalized['direction'] = isOut ? 'OUT' : (isIn ? 'IN' : 'SELF');
    normalized['display_to'] = displayTo;
    normalized['tx_title'] = title;
    normalized['amount_label'] = amountLabel;
    normalized['token_symbol'] = tokenSymbol;
    normalized['explorer_url'] =
        hash.isEmpty ? '' : 'https://octrascan.io/tx.html?hash=$hash';
    normalized['amount'] =
        _octAmountValue(tx['amount_raw'] ?? tx['amount']).toString();
    return normalized;
  }

  String _titleForOp(String opType, Map<String, dynamic> tx) {
    if ((opType.isEmpty || opType == 'standard')) return 'OCT Transfer';
    if (opType == 'call') {
      final method = tx['encrypted_data']?.toString();
      if (method != null && method.isNotEmpty) return '$method()';
      return 'Program Call';
    }
    const labels = {
      'stealth': 'Stealth Transfer',
      'claim': 'Stealth Claim',
      'encrypt': 'Encrypt Balance',
      'decrypt': 'Decrypt Balance',
      'private': 'Private Transfer',
      'recrypt': 'Recrypt',
      'deploy': 'Program Deploy',
      'upgrade': 'Program Upgrade',
    };
    return labels[opType] ?? opType.replaceAll('_', ' ');
  }

  Map<String, String>? _parseTokenTransfer(Map<String, dynamic> tx) {
    final parsed = _parseJsonList(tx['message']);
    if (parsed == null || parsed.length < 2) return null;
    return {
      'to': parsed[0].toString(),
      'amount': parsed[1].toString(),
    };
  }

  List<dynamic>? _parseJsonList(dynamic value) {
    if (value == null) return null;
    try {
      final decoded = jsonDecode(value.toString());
      return decoded is List ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, String>> _loadTokenMeta(String programAddress) async {
    if (programAddress.isEmpty) return const {};
    final cached = _tokenMetaCache[programAddress];
    if (cached != null) return cached;
    final symbol = await rpc.programStorageRpc(programAddress, 'symbol') ??
        await rpc.contractStorageRpc(programAddress, 'symbol');
    final decimals = await rpc.programStorageRpc(programAddress, 'decimals') ??
        await rpc.contractStorageRpc(programAddress, 'decimals');
    final meta = {
      if (symbol != null) 'symbol': symbol.toString(),
      if (decimals != null) 'decimals': decimals.toString(),
    };
    _tokenMetaCache[programAddress] = meta;
    return meta;
  }

  double _octAmountValue(dynamic rawValue) {
    final text = rawValue?.toString() ?? '0';
    final raw = double.tryParse(text) ?? 0.0;
    return raw / kMicro;
  }

  String _formatOctAmount(dynamic rawValue) {
    final value = _octAmountValue(rawValue);
    if (value == 0) return '0 OCT';
    if (value > 0 && value < 0.001) return '< 0.001 OCT';
    return '${value.toStringAsFixed(6).replaceFirst(RegExp(r'\.?0+$'), '')} OCT';
  }

  String _formatTokenAmount(String raw, int decimals, String symbol) {
    var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) digits = '0';
    if (decimals > 0) {
      while (digits.length <= decimals) {
        digits = '0$digits';
      }
      final split = digits.length - decimals;
      final whole = digits.substring(0, split);
      final fraction = digits.substring(split).replaceFirst(RegExp(r'0+$'), '');
      digits = fraction.isEmpty ? whole : '$whole.$fraction';
    }
    return symbol.isEmpty ? digits : '$digits $symbol';
  }

  Future<Map<String, dynamic>> recommendedFee(
    String operationType, {
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    final cacheFresh = _feeCacheAt != null &&
        now.difference(_feeCacheAt!) < const Duration(seconds: 30);
    if (!forceRefresh && cacheFresh && _feeCache.containsKey(operationType)) {
      return _feeCache[operationType]!;
    }

    try {
      final live = await rpc.getRecommendedFee(operationType);
      if (live != null && live.isNotEmpty) {
        final normalized = _normalizeFee(operationType, live);
        _feeCache[operationType] = normalized;
        _feeCacheAt = now;
        return normalized;
      }
    } catch (e) {
      print("Fee fetch error for $operationType: $e");
    }

    final fallback = _fallbackFee(operationType);
    _feeCache[operationType] = fallback;
    _feeCacheAt = now;
    return fallback;
  }

  Future<String> recommendedFeeRaw(String operationType) async {
    final fee = await recommendedFee(operationType);
    return (fee['recommended'] ?? fee['minimum'] ?? '1000').toString();
  }

  Map<String, dynamic> _normalizeFee(
    String operationType,
    Map<String, dynamic> fee,
  ) {
    final fallback = _fallbackFee(operationType);
    String value(String key) {
      final raw = fee[key] ?? fallback[key] ?? '1000';
      final parsed = int.tryParse(raw.toString());
      if (parsed == null || parsed <= 0) return fallback[key].toString();
      return parsed.toString();
    }

    return {
      ...fee,
      'minimum': value('minimum'),
      'base_fee': value('base_fee'),
      'recommended': value('recommended'),
      'fast': value('fast'),
      'source': 'octra_recommendedFee',
    };
  }

  Map<String, dynamic> _fallbackFee(String operationType) {
    const table = {
      'standard': {
        'minimum': '1000',
        'base_fee': '1000',
        'recommended': '10000',
        'fast': '30000',
      },
      'call': {
        'minimum': '1000',
        'base_fee': '1000',
        'recommended': '1000',
        'fast': '2000',
      },
      'deploy': {
        'minimum': '200000',
        'base_fee': '200000',
        'recommended': '200000',
        'fast': '400000',
      },
      'encrypt': {
        'minimum': '5000000',
        'base_fee': '3000',
        'recommended': '5300000',
        'fast': '10600000',
      },
      'decrypt': {
        'minimum': '5000000',
        'base_fee': '3000',
        'recommended': '5300000',
        'fast': '10600000',
      },
      'stealth': {
        'minimum': '5000000',
        'base_fee': '5000000',
        'recommended': '5500000',
        'fast': '11000000',
      },
      'claim': {
        'minimum': '3000',
        'base_fee': '3000',
        'recommended': '3000',
        'fast': '6000',
      },
    };
    return Map<String, dynamic>.from(
      table[operationType] ?? table['standard']!,
    );
  }

  String formatFeeRaw(String raw) {
    final value = (int.tryParse(raw) ?? 0) / kMicro;
    if (value == 0) return '0 OCT';
    if (value > 0 && value < 0.001) return '< 0.001 OCT';
    return '${value.toStringAsFixed(6).replaceFirst(RegExp(r'\.?0+$'), '')} OCT';
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

  Future<T> _runPvacTask<T>(
    String status,
    Future<T> Function() task, {
    bool showProgress = true,
  }) async {
    if (showProgress) {
      isPvacBusy = true;
      pvacStatus = status;
      notifyListeners();
    }
    try {
      return await task();
    } finally {
      if (showProgress) {
        isPvacBusy = false;
        pvacStatus = null;
        notifyListeners();
      }
    }
  }

  /// SEND TRANSACTION
  Future<RpcResponse> sendTransaction(
      String to, double amount, String? msg) async {
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
        final maxStagedNonce = myStaged
            .map((tx) => int.parse(tx['nonce'].toString()))
            .reduce((cur, next) => cur > next ? cur : next);
        if (maxStagedNonce >= currentNonce) {
          currentNonce = maxStagedNonce;
        }
      }
    }

    if (!await _walletMatchesPrivateKey(wallet)) {
      return RpcResponse(
          0, "Selected wallet address does not match its private key", null);
    }

    final txNonce = currentNonce + 1;
    final feeRaw = await recommendedFeeRaw('standard');
    final payload = <String, dynamic>{
      "from": wallet.address,
      "to_": to, // Note: cli.py uses 'to_' (line 502)
      "amount": (amount * 1000000).toInt().toString(),
      "nonce": txNonce,
      "ou": feeRaw,
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
    if (filtered.length > 5)
      return [RpcResponse(0, "Bulk send supports up to 5 recipients", null)];

    await refresh();
    final startNonce = await _nextNonce(wallet);
    final feeRaw = await recommendedFeeRaw('standard');
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
        "ou": feeRaw,
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

  Future<Map<String, dynamic>?> importCustomToken(
      String contractAddress) async {
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
    final feeRaw = await recommendedFeeRaw('call');
    final payload = <String, dynamic>{
      "from": wallet.address,
      "to_": tokenAddress,
      "amount": "0",
      "nonce": txNonce,
      "ou": feeRaw,
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

    final registered = await ensurePvacRegistered(wallet: wallet);
    if (!registered) {
      return RpcResponse(0, "PVAC registration failed", null);
    }

    final pvacResult = await _runPvacTask(
      'Preparing encrypt proof',
      () => pvacWorker.encryptBalance(
        privateKeyBase64: wallet.privateKeyBase64,
        amountRaw: amountRaw,
      ),
    );

    final encryptedData = jsonEncode(pvacResult['encrypted_data']);
    final tx = await _buildSelfPrivacyTx(
      wallet: wallet,
      amountRaw: amountRaw,
      opType: 'encrypt',
      encryptedData: encryptedData,
      ou: await recommendedFeeRaw('encrypt'),
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

    final registered = await ensurePvacRegistered(wallet: wallet);
    if (!registered) {
      return RpcResponse(0, "PVAC registration failed", null);
    }

    final pvacResult = await _runPvacTask(
      'Preparing decrypt proof',
      () => pvacWorker.decryptBalance(
        privateKeyBase64: wallet.privateKeyBase64,
        amountRaw: amountRaw,
        currentCipher: cipher,
        currentBalanceRaw: currentRaw,
      ),
    );

    final encryptedData = jsonEncode(pvacResult['encrypted_data']);
    final tx = await _buildSelfPrivacyTx(
      wallet: wallet,
      amountRaw: amountRaw,
      opType: 'decrypt',
      encryptedData: encryptedData,
      ou: await recommendedFeeRaw('decrypt'),
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

    final registered = await ensurePvacRegistered(wallet: wallet);
    if (!registered) {
      return RpcResponse(0, "PVAC registration failed", null);
    }

    final stealth = await _runPvacTask(
      'Preparing stealth transfer',
      () => pvacWorker.stealthPrepareSend(
        privateKeyBase64: wallet.privateKeyBase64,
        recipientAddress: toAddr,
        recipientPublicKeyBase64: toPubKey,
        amountRaw: amountRaw,
        currentCipher: cipher,
        currentBalanceRaw: encryptedRaw,
      ),
    );

    final tx = await _buildPrivacyTx(
      wallet: wallet,
      to: 'stealth',
      amountRaw: 0,
      opType: 'stealth',
      encryptedData: jsonEncode(stealth['encrypted_data']),
      ou: await recommendedFeeRaw('stealth'),
    );
    final res = await rpc.sendTransaction(tx);
    await refresh();
    return res;
  }

  /// CLAIM PRIVATE TRANSFER
  Future<bool> claimTransfer(
      String transferId, String ephPubKey, String encryptedAmount) async {
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
    final result = await _runPvacTask(
      'Scanning stealth outputs',
      () => pvacWorker.stealthScanOutputs(
        privateKeyBase64: wallet.privateKeyBase64,
        outputs: outputs,
      ),
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
    final blinding = claim['blinding_b64']?.toString() ??
        claim['blinding']?.toString() ??
        '';
    if (amountRaw <= 0 || claimSecret.isEmpty || blinding.isEmpty) {
      return RpcResponse(0, "Invalid claim payload", null);
    }

    final registered = await ensurePvacRegistered(wallet: wallet);
    if (!registered) {
      return RpcResponse(0, "PVAC registration failed", null);
    }

    final prepared = await _runPvacTask(
      'Preparing claim proof',
      () => pvacWorker.stealthPrepareClaim(
        privateKeyBase64: wallet.privateKeyBase64,
        outputId: claim['id'],
        amountRaw: amountRaw,
        claimSecret: claimSecret,
        blindingBase64: blinding,
      ),
    );

    final tx = await _buildPrivacyTx(
      wallet: wallet,
      to: wallet.address,
      amountRaw: 0,
      opType: 'claim',
      encryptedData: jsonEncode(prepared['encrypted_data']),
      ou: await recommendedFeeRaw('claim'),
    );
    final res = await rpc.sendTransaction(tx);
    await refresh();
    return res;
  }

  void registerCurrentPvacInBackground() {
    final wallet = currentWallet;
    if (wallet == null || !nativeCore.isAvailable) return;
    if (_pvacRegistrationInFlight.contains(wallet.address)) return;
    _pvacRegistrationInFlight.add(wallet.address);
    Future.delayed(const Duration(milliseconds: 350), () async {
      try {
        await ensurePvacRegistered(wallet: wallet, showProgress: false);
      } catch (e) {
        print("Background PVAC registration failed for ${wallet.address}: $e");
      } finally {
        _pvacRegistrationInFlight.remove(wallet.address);
      }
    });
  }

  Future<bool> ensurePvacRegistered({
    Wallet? wallet,
    bool showProgress = true,
  }) async {
    wallet ??= currentWallet;
    if (wallet == null || !nativeCore.isAvailable) return false;
    final activeWallet = wallet;

    final registration = await _runPvacTask(
      'Registering PVAC key',
      () => pvacWorker.registerPubkey(
        privateKeyBase64: activeWallet.privateKeyBase64,
      ),
      showProgress: showProgress,
    );
    final localPvacPubkey = registration['pubkey_b64']?.toString();
    final aesKatHex = registration['aes_kat_hex']?.toString() ?? '';
    if (localPvacPubkey == null || localPvacPubkey.isEmpty) return false;

    final remote = await rpc.getPvacPubkeyRpc(wallet.address);
    final remotePvacPubkey = remote?['pvac_pubkey']?.toString();
    if (remotePvacPubkey == localPvacPubkey) return true;
    if (remotePvacPubkey != null &&
        remotePvacPubkey.isNotEmpty &&
        remotePvacPubkey != 'null') {
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
        return decoded
            .map((item) => item.toString())
            .where((item) => item.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>?> _loadToken(
      String address, String walletAddress) async {
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
        'name': (nameValue?.toString().isNotEmpty ?? false)
            ? nameValue.toString()
            : symbol,
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
    var fraction =
        parts.length == 2 ? parts[1].replaceAll(RegExp(r'[^0-9]'), '') : '';
    if (whole.isEmpty && fraction.isEmpty) return null;
    if (fraction.length > decimals) {
      fraction = fraction.substring(0, decimals);
    }
    while (fraction.length < decimals) {
      fraction += '0';
    }

    final raw = '${whole.isEmpty ? '0' : whole}$fraction'
        .replaceFirst(RegExp(r'^0+'), '');
    return raw.isEmpty ? '0' : raw;
  }

  Future<void> _fetchEncryptedBalance(Wallet wallet) async {
    if (!_isActiveWallet(wallet)) return;
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
      if (!_isActiveWallet(wallet)) return;
      final cipher = result?['cipher']?.toString() ??
          result?['encrypted_balance']?.toString() ??
          '0';
      if (cipher.isEmpty || cipher == '0') return;

      final decrypted = await pvacWorker.fheDecrypt(
        privateKeyBase64: wallet.privateKeyBase64,
        cipher: cipher,
      );
      if (!_isActiveWallet(wallet)) return;
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
      final myStaged =
          staged.where((tx) => tx is Map && tx['from'] == wallet.address);
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
    if (!await _walletMatchesPrivateKey(wallet)) {
      throw StateError(
          'Selected wallet address does not match its private key');
    }
    final signature =
        await _signMessageBase64(wallet, _canonicalTxJson(payload));
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
    buffer.write(
        ',"op_type":${jsonEncode((tx["op_type"] ?? "standard").toString())}');
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
  final privateKeyBytes =
      await crypto_utils.deriveForNetwork(Uint8List.fromList(seed));

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
