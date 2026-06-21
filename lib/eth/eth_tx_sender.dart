import 'eth_account.dart';
import 'eth_constants.dart';
import 'eth_rpc.dart';
import 'eth_signer.dart';
import 'eth_walletconnect.dart';

/// Abstraction over "how an Ethereum transaction gets signed and sent" so the
/// bridge can use an in-app key (derived/imported) or an external wallet
/// (WalletConnect) interchangeably.
abstract class EthTxSender {
  String get address;

  Future<String> sendCall({
    required String to,
    required String dataHex,
    required int gasLimit,
    GasSpeed speed = GasSpeed.standard,
  });

  Future<bool?> waitForSuccess(String txHash);

  void dispose();
}

/// Signs with an in-app account (derived or imported) via web3dart.
class LocalEthSender implements EthTxSender {
  final EthAccount account;
  final EthSigner _signer;

  LocalEthSender(this.account, {EthSigner? signer})
      : _signer = signer ?? EthSigner();

  @override
  String get address => account.address;

  /// Estimated fee in wei for all gas speed tiers at [gasLimit].
  Future<Map<GasSpeed, BigInt>> feeEstimates(int gasLimit) async {
    final result = <GasSpeed, BigInt>{};
    for (final speed in GasSpeed.values) {
      result[speed] = await _signer.estimateFeeWei(gasLimit, speed);
    }
    return result;
  }

  @override
  Future<String> sendCall({
    required String to,
    required String dataHex,
    required int gasLimit,
    GasSpeed speed = GasSpeed.standard,
  }) =>
      _signer.sendCall(
          account: account,
          to: to,
          dataHex: dataHex,
          gasLimit: gasLimit,
          speed: speed);

  @override
  Future<bool?> waitForSuccess(String txHash) =>
      _signer.waitForSuccess(txHash);

  @override
  void dispose() => _signer.dispose();
}

/// Delegates signing to an external wallet over WalletConnect; confirmation is
/// polled from the chain.
class WalletConnectSender implements EthTxSender {
  final WcService wc;
  final EthRpc _rpc;

  WalletConnectSender(this.wc, {EthRpc? rpc}) : _rpc = rpc ?? EthRpc();

  @override
  String get address => wc.address ?? '';

  @override
  Future<String> sendCall({
    required String to,
    required String dataHex,
    required int gasLimit,
    GasSpeed speed = GasSpeed.standard, // ignored; external wallet sets fees
  }) {
    final from = wc.address;
    if (from == null || from.isEmpty) {
      throw StateError('WalletConnect is not connected');
    }
    final tx = <String, dynamic>{
      'from': from,
      'to': to,
      'data': dataHex,
      'gas': '0x${gasLimit.toRadixString(16)}',
      'value': '0x0',
    };
    return wc.sendTransaction(tx);
  }

  @override
  Future<bool?> waitForSuccess(
    String txHash, {
    // External wallets let the user pick their own (possibly slow) gas, so give
    // the receipt longer to appear than the in-app signer.
    Duration timeout = const Duration(minutes: 8),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final r = await _rpc.transactionReceipt(txHash);
      if (r != null) {
        final status = r['status']?.toString();
        return status == '0x1' || status == '1';
      }
      await Future<void>.delayed(const Duration(seconds: 5));
    }
    return null;
  }

  @override
  void dispose() => _rpc.dispose();
}
