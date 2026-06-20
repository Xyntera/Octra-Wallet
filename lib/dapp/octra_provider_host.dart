import 'dart:convert';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../rpc.dart';
import '../wallet.dart';
import 'dapp_permissions.dart';

/// RFC-O-1 provider error codes.
class DappErr {
  static const int userRejected = 4001;
  static const int unauthorized = 4100; // not connected / missing permission
  static const int unsupported = 4200;
  static const int disconnected = 4900;
  static const int badNetwork = 4901;
}

class _ProviderError implements Exception {
  final int code;
  final String message;
  _ProviderError(this.code, this.message);
}

/// What an approval sheet should display. The browser UI renders this and
/// returns whether the user approved.
enum DappPromptKind { signMessage, sendTransaction, privacy, switchNetwork }

class DappPrompt {
  final DappPromptKind kind;
  final String origin;
  final String title;

  /// Ordered label→value rows to show (e.g. To, Amount, Fee, Network).
  final List<MapEntry<String, String>> rows;

  /// Free-form body (e.g. the message text for signMessage).
  final String? body;

  DappPrompt({
    required this.kind,
    required this.origin,
    required this.title,
    this.rows = const [],
    this.body,
  });
}

/// Shows the connection-consent sheet; returns the granted permission set, or
/// null if the user rejects.
typedef ConnectPrompt = Future<Set<DappPermission>?> Function(
    String origin, List<DappPermission> requested);

/// Shows an approval sheet; returns true if approved.
typedef ApprovePrompt = Future<bool> Function(DappPrompt prompt);

/// Hosts the RFC-O-1 `window.octra` provider for one dApp origin: registers the
/// JS handler, routes requests to [WalletController]/[RpcClient] behind
/// permission + explicit-approval gates, and dispatches provider events.
class OctraProviderHost {
  final WalletController wallet;
  final DappPermissionStore perms;
  final ConnectPrompt onConnect;
  final ApprovePrompt onApprove;

  /// `scheme://host[:port]` of the current page. Updated on navigation.
  String origin;

  InAppWebViewController? _controller;

  OctraProviderHost({
    required this.wallet,
    required this.perms,
    required this.origin,
    required this.onConnect,
    required this.onApprove,
  });

  /// Read-only native RPC methods a dApp may pass through without approval.
  static const _readPassThrough = <String>{
    'octra_balance',
    'octra_account',
    'octra_transaction',
    'octra_transactionsByAddress',
    'octra_publicKey',
    'octra_recommendedFee',
    'octra_listContracts',
    'octra_tokensByAddress',
    'octra_contractStorage',
    'octra_programStorage',
    'contract_call',
    'contract_receipt',
    'staging_view',
  };

  void attach(InAppWebViewController controller) {
    _controller = controller;
    controller.addJavaScriptHandler(
      handlerName: 'octra',
      callback: (args) => _handle(args),
    );
  }

  // ── event dispatch ─────────────────────────────────────────────────────────

  void _emit(String event, Object? payload) {
    final c = _controller;
    if (c == null) return;
    final js = jsonEncode(payload);
    c.evaluateJavascript(
        source: "window.octra && window.octra._emit(${jsonEncode(event)}, $js);");
  }

  void emitAccountsChanged() =>
      _emit('accountsChanged', _connected ? [_address] : const []);

  void emitNetworkChanged() => _emit('networkChanged', wallet.dappNetworkInfo());

  void emitDisconnect() {
    _emit('disconnect', {'code': DappErr.disconnected, 'message': 'Disconnected'});
  }

  // ── request handling ─────────────────────────────────────────────────────────

  String get _address => wallet.currentWallet?.address ?? '';
  bool get _connected => perms.isConnected(origin) && wallet.currentWallet != null;

  Future<Map<String, dynamic>> _handle(List<dynamic> args) async {
    try {
      final payload = (args.isNotEmpty && args[0] is Map)
          ? (args[0] as Map).cast<String, dynamic>()
          : <String, dynamic>{};
      final method = payload['method']?.toString() ?? '';
      final rawParams = payload['params'];
      final params = rawParams is List ? rawParams : const [];
      final result = await _route(method, params);
      return {'result': result};
    } on _ProviderError catch (e) {
      return {
        'error': {'code': e.code, 'message': e.message}
      };
    } catch (e) {
      return {
        'error': {'code': DappErr.unsupported, 'message': _clean(e)}
      };
    }
  }

  Future<dynamic> _route(String method, List params) async {
    switch (method) {
      // ── accounts / network ───────────────────────────────────────────────
      case 'octra_requestAccounts':
        return _requestAccounts(params);
      case 'octra_accounts':
        return _connected ? [_address] : const [];
      case 'octra_networkId':
        return wallet.networkProfileSync;
      case 'octra_networkInfo':
        return wallet.dappNetworkInfo();
      case 'octra_permissions':
        return perms.granted(origin).map((p) => p.id).toList();
      case 'octra_switchNetwork':
        return _switchNetwork(params);

      // ── signing / sending ────────────────────────────────────────────────
      case 'octra_signMessage':
        return _signMessage(params);
      case 'octra_sendTransaction':
        return _sendTransaction(params);
      case 'octra_signTransaction':
        return _signTransaction(params);
      case 'octra_submitTransaction':
        return _submitTransaction(params);

      // ── contracts ────────────────────────────────────────────────────────
      case 'octra_callContract':
        return _callContract(params);
      case 'octra_getContractReceipt':
        _require(DappPermission.contractCalls);
        final hash = _str(params, 0, 'hash');
        return wallet.rpc.contractReceipt(hash);
      case 'octra_sendContractTransaction':
        return _sendContractTransaction(params);

      // ── privacy ──────────────────────────────────────────────────────────
      case 'octra_getEncryptedBalance':
        _require(DappPermission.viewEncryptedBalance);
        return {
          'address': _address,
          'decryptedAmount': wallet.encryptedRaw.toString(),
          'hasPvacPubkey': wallet.nativeCore.isAvailable,
        };
      case 'octra_encryptBalance':
        return _privacyAmountOp(params, DappPermission.encryptBalance,
            'Encrypt balance', (a) => wallet.encryptMoney(a));
      case 'octra_decryptBalance':
        return _privacyAmountOp(params, DappPermission.decryptBalance,
            'Decrypt balance', (a) => wallet.decryptMoney(a));
      case 'octra_sendPrivateTransfer':
        return _sendPrivateTransfer(params);
      case 'octra_scanStealth':
        _require(DappPermission.stealthScan);
        return wallet.scanStealthTransfers();
      case 'octra_claimStealth':
        return _claimStealth(params);

      default:
        if (_readPassThrough.contains(method)) {
          final res = await wallet.rpc.rpcCall(method, List.from(params));
          final err = wallet.rpc.rpcError(res);
          if (err != null) throw _ProviderError(DappErr.unsupported, err);
          return wallet.rpc.rpcResult(res);
        }
        throw _ProviderError(DappErr.unsupported, 'Unsupported method: $method');
    }
  }

  // ── method impls ─────────────────────────────────────────────────────────────

  Future<List<String>> _requestAccounts(List params) async {
    if (wallet.currentWallet == null) {
      throw _ProviderError(DappErr.disconnected, 'No wallet available');
    }
    // Optional requested permissions: params[0] = { permissions: [...] }.
    var requested = <DappPermission>[DappPermission.readAddress];
    if (params.isNotEmpty && params[0] is Map) {
      final list = (params[0] as Map)['permissions'];
      if (list is List) {
        final parsed = list
            .map((e) => DappPermission.fromId(e.toString()))
            .whereType<DappPermission>()
            .toList();
        if (parsed.isNotEmpty) requested = parsed;
      }
    }
    // Already connected with everything requested → no re-prompt.
    await perms.load(origin);
    final already = perms.granted(origin);
    if (already.isNotEmpty && requested.every(already.contains)) {
      return [_address];
    }
    final granted = await onConnect(origin, requested);
    if (granted == null || granted.isEmpty) {
      throw _ProviderError(DappErr.userRejected, 'User rejected connection');
    }
    await perms.grant(origin, granted);
    _emit('connect', {
      'networkId': wallet.networkProfileSync,
      'networkInfo': wallet.dappNetworkInfo(),
    });
    emitAccountsChanged();
    _emit('permissionsChanged', granted.map((p) => p.id).toList());
    return [_address];
  }

  Future<Map<String, dynamic>> _switchNetwork(List params) async {
    final target = _str(params, 0, 'networkId').toLowerCase();
    if (target != 'mainnet' && target != 'devnet') {
      throw _ProviderError(DappErr.badNetwork, 'Unknown network: $target');
    }
    if (target == wallet.networkProfileSync) return wallet.dappNetworkInfo();
    final ok = await onApprove(DappPrompt(
      kind: DappPromptKind.switchNetwork,
      origin: origin,
      title: 'Switch network',
      rows: [MapEntry('To', target == 'devnet' ? 'Devnet' : 'Mainnet')],
    ));
    if (!ok) throw _ProviderError(DappErr.userRejected, 'User rejected');
    await wallet.setNetworkProfile(target);
    emitNetworkChanged();
    return wallet.dappNetworkInfo();
  }

  Future<Map<String, String>> _signMessage(List params) async {
    _require(DappPermission.signMessages);
    final message = _messageParam(params);
    final ok = await onApprove(DappPrompt(
      kind: DappPromptKind.signMessage,
      origin: origin,
      title: 'Sign message',
      body: message,
    ));
    if (!ok) throw _ProviderError(DappErr.userRejected, 'User rejected signing');
    return wallet.signMessageForDapp(message);
  }

  Future<Map<String, dynamic>> _sendTransaction(List params) async {
    _require(DappPermission.sendTransactions);
    final p = _mapParam(params);
    final to = (p['to'] ?? p['to_'])?.toString() ?? '';
    final micro = _microFrom(p['amount']);
    final message = p['message']?.toString();
    if (to.isEmpty) throw _ProviderError(DappErr.unsupported, 'Missing "to"');
    final ok = await onApprove(_txPrompt('Approve transaction', to, micro, message));
    if (!ok) throw _ProviderError(DappErr.userRejected, 'User rejected transaction');
    final signed = await wallet.buildSignedTransaction(
        to: to, microAmount: micro, message: message);
    return _submitSigned(signed);
  }

  Future<Map<String, dynamic>> _signTransaction(List params) async {
    _require(DappPermission.sendTransactions);
    final p = _mapParam(params);
    final to = (p['to'] ?? p['to_'])?.toString() ?? '';
    final micro = _microFrom(p['amount']);
    final message = p['message']?.toString();
    if (to.isEmpty) throw _ProviderError(DappErr.unsupported, 'Missing "to"');
    final ok = await onApprove(_txPrompt('Sign transaction', to, micro, message));
    if (!ok) throw _ProviderError(DappErr.userRejected, 'User rejected signing');
    return wallet.buildSignedTransaction(
        to: to, microAmount: micro, message: message);
  }

  Future<Map<String, dynamic>> _submitTransaction(List params) async {
    _require(DappPermission.sendTransactions);
    final signed = _mapParam(params);
    final ok = await onApprove(DappPrompt(
      kind: DappPromptKind.sendTransaction,
      origin: origin,
      title: 'Submit transaction',
      rows: [
        MapEntry('To', (signed['to_'] ?? signed['to'] ?? '').toString()),
        MapEntry('Amount', _fmtMicro(_microFrom(signed['amount']))),
        MapEntry('Network', wallet.activeNetworkLabelSync),
      ],
    ));
    if (!ok) throw _ProviderError(DappErr.userRejected, 'User rejected');
    return _submitSigned(signed);
  }

  Future<dynamic> _callContract(List params) async {
    _require(DappPermission.contractCalls);
    final p = _mapParam(params);
    final address = p['address']?.toString() ?? '';
    final method = p['method']?.toString() ?? '';
    final args = p['params'] is List ? p['params'] as List : const [];
    final caller = p['caller']?.toString() ?? _address;
    if (address.isEmpty || method.isEmpty) {
      throw _ProviderError(DappErr.unsupported, 'Missing contract address/method');
    }
    return wallet.rpc.contractCallViewRpc(address, method, List.from(args), caller);
  }

  Future<Map<String, dynamic>> _sendContractTransaction(List params) async {
    _require(DappPermission.contractCalls);
    final p = _mapParam(params);
    final address = p['address']?.toString() ?? '';
    final method = p['method']?.toString() ?? '';
    final args = p['params'] is List ? p['params'] as List : const [];
    final micro = _microFrom(p['amount']);
    if (address.isEmpty) {
      throw _ProviderError(DappErr.unsupported, 'Missing contract address');
    }
    final ok = await onApprove(DappPrompt(
      kind: DappPromptKind.sendTransaction,
      origin: origin,
      title: 'Approve contract call',
      rows: [
        MapEntry('Contract', address),
        if (method.isNotEmpty) MapEntry('Method', method),
        MapEntry('Amount', _fmtMicro(micro)),
        MapEntry('Network', wallet.activeNetworkLabelSync),
      ],
    ));
    if (!ok) throw _ProviderError(DappErr.userRejected, 'User rejected');
    final signed = await wallet.buildSignedTransaction(
      to: address,
      microAmount: micro,
      opType: 'call',
      encryptedData: method.isEmpty ? null : method,
      message: args.isEmpty ? null : jsonEncode(args),
    );
    return _submitSigned(signed);
  }

  Future<Map<String, dynamic>> _privacyAmountOp(
    List params,
    DappPermission perm,
    String title,
    Future<RpcResponse> Function(double amount) op,
  ) async {
    _require(perm);
    final micro = _microFrom(_mapOrFirst(params, 'amount'));
    final ok = await onApprove(DappPrompt(
      kind: DappPromptKind.privacy,
      origin: origin,
      title: title,
      rows: [MapEntry('Amount', _fmtMicro(micro))],
    ));
    if (!ok) throw _ProviderError(DappErr.userRejected, 'User rejected');
    final res = await op(micro / 1000000.0);
    return _responseToResult(res);
  }

  Future<Map<String, dynamic>> _sendPrivateTransfer(List params) async {
    _require(DappPermission.privateTransfers);
    final p = _mapParam(params);
    final to = (p['to'] ?? p['to_'])?.toString() ?? '';
    final micro = _microFrom(p['amount']);
    if (to.isEmpty) throw _ProviderError(DappErr.unsupported, 'Missing "to"');
    final ok = await onApprove(_txPrompt('Approve private transfer', to, micro, null));
    if (!ok) throw _ProviderError(DappErr.userRejected, 'User rejected');
    final res = await wallet.makePrivateTransfer(to, micro / 1000000.0);
    return _responseToResult(res);
  }

  Future<Map<String, dynamic>> _claimStealth(List params) async {
    _require(DappPermission.stealthClaim);
    final claim = _mapParam(params);
    final ok = await onApprove(DappPrompt(
      kind: DappPromptKind.privacy,
      origin: origin,
      title: 'Claim stealth payment',
      rows: [
        if (claim['amount_raw'] != null)
          MapEntry('Amount', _fmtMicro(_microFrom(claim['amount_raw']))),
      ],
    ));
    if (!ok) throw _ProviderError(DappErr.userRejected, 'User rejected');
    final res = await wallet.claimStealthTransfer(claim);
    return _responseToResult(res);
  }

  // ── helpers ──────────────────────────────────────────────────────────────────

  void _require(DappPermission p) {
    if (!_connected) {
      throw _ProviderError(DappErr.unauthorized, 'Not connected — call octra_requestAccounts');
    }
    if (!perms.has(origin, p)) {
      throw _ProviderError(DappErr.unauthorized, 'Permission "${p.id}" not granted');
    }
  }

  DappPrompt _txPrompt(String title, String to, int micro, String? message) {
    return DappPrompt(
      kind: DappPromptKind.sendTransaction,
      origin: origin,
      title: title,
      rows: [
        MapEntry('To', to),
        MapEntry('Amount', _fmtMicro(micro)),
        if (message != null && message.isNotEmpty) MapEntry('Message', message),
        MapEntry('Network', wallet.activeNetworkLabelSync),
      ],
    );
  }

  Future<Map<String, dynamic>> _submitSigned(Map<String, dynamic> signed) async {
    final res = await wallet.rpc.sendTransaction(signed);
    return _responseToResult(res);
  }

  Map<String, dynamic> _responseToResult(RpcResponse res) {
    final err = wallet.rpc.rpcError(res);
    if (err != null) throw _ProviderError(DappErr.unsupported, err);
    final result = wallet.rpc.rpcResult(res);
    String? hash;
    if (result is Map) {
      hash = (result['tx_hash'] ?? result['hash'] ?? result['tx'])?.toString();
    } else if (result is String) {
      hash = result;
    }
    return {
      'hash': hash ?? '',
      'accepted': hash != null && hash.isNotEmpty,
      'status': hash != null && hash.isNotEmpty ? 'pending' : 'rejected',
    };
  }

  // param parsing -------------------------------------------------------------

  Map<String, dynamic> _mapParam(List params) {
    if (params.isNotEmpty && params[0] is Map) {
      return (params[0] as Map).cast<String, dynamic>();
    }
    throw _ProviderError(DappErr.unsupported, 'Expected an object parameter');
  }

  String _messageParam(List params) {
    if (params.isEmpty) {
      throw _ProviderError(DappErr.unsupported, 'Missing message');
    }
    final first = params[0];
    if (first is String) return first;
    if (first is Map && first['message'] != null) return first['message'].toString();
    throw _ProviderError(DappErr.unsupported, 'Invalid message');
  }

  dynamic _mapOrFirst(List params, String key) {
    if (params.isEmpty) return null;
    final first = params[0];
    if (first is Map) return first[key];
    return first;
  }

  String _str(List params, int i, String name) {
    if (params.length <= i || params[i] == null) {
      throw _ProviderError(DappErr.unsupported, 'Missing "$name"');
    }
    final v = params[i];
    if (v is String) return v;
    if (v is Map && v[name] != null) return v[name].toString();
    return v.toString();
  }

  /// Parses an amount that may arrive as a micro-OCT string/number.
  int _microFrom(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    final s = v.toString().trim();
    return int.tryParse(s) ?? 0;
  }

  String _fmtMicro(int micro) => '${(micro / 1000000.0).toStringAsFixed(6)} OCT';

  static String _clean(Object e) =>
      e.toString().replaceFirst('StateError: ', '').replaceFirst('Exception: ', '');
}
