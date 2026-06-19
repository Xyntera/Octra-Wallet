import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart';

import 'eth_account.dart';
import 'eth_constants.dart';

/// Signs and sends Ethereum transactions for the in-app *derived* account
/// (EIP-1559). External (WalletConnect) signing is delegated to the user's
/// wallet and does not go through here.
///
/// Fee policy mirrors the webcli reference: maxFeePerGas = max(2×gasPrice,
/// 10 gwei), maxPriorityFeePerGas = 2 gwei.
class EthSigner {
  final Web3Client _client;

  EthSigner({String? rpcUrl, http.Client? httpClient})
      : _client = Web3Client(
          rpcUrl ?? EthConstants.defaultRpcUrl,
          httpClient ?? http.Client(),
        );

  Future<(EtherAmount, EtherAmount)> _feesFor(GasSpeed speed) async {
    final gasPrice = await _client.getGasPrice();
    final base = gasPrice.getInWei;
    final tenGwei = BigInt.from(10000000000);
    final scaled =
        (base * BigInt.from(speed.multiplierX10)) ~/ BigInt.from(10);
    final maxFeeWei = scaled > tenGwei ? scaled : tenGwei;
    final priorityWei =
        BigInt.from(speed.priorityGwei) * BigInt.from(1000000000);
    return (EtherAmount.inWei(maxFeeWei), EtherAmount.inWei(priorityWei));
  }

  /// Estimated max fee in wei for [gasLimit] at [speed].
  Future<BigInt> estimateFeeWei(int gasLimit, GasSpeed speed) async {
    final (maxFee, _) = await _feesFor(speed);
    return maxFee.getInWei * BigInt.from(gasLimit);
  }

  /// Signs and submits a contract call (`to`/`dataHex`) from a derived account.
  /// Returns the transaction hash.
  Future<String> sendCall({
    required EthAccount account,
    required String to,
    required String dataHex,
    required int gasLimit,
    GasSpeed speed = GasSpeed.standard,
  }) async {
    final creds = account.credentials;
    if (creds == null) {
      throw StateError('account mode ${account.mode} cannot sign in-app');
    }
    final (maxFee, maxPriority) = await _feesFor(speed);
    final tx = Transaction(
      to: EthereumAddress.fromHex(to),
      value: EtherAmount.zero(),
      data: _hexToBytes(dataHex),
      maxGas: gasLimit,
      maxFeePerGas: maxFee,
      maxPriorityFeePerGas: maxPriority,
    );
    return _client.sendTransaction(creds, tx, chainId: EthConstants.chainId);
  }

  /// Polls for a receipt. Returns true/false on `status`, or null on timeout.
  Future<bool?> waitForSuccess(
    String txHash, {
    Duration timeout = const Duration(minutes: 5),
    Duration interval = const Duration(seconds: 5),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final receipt = await _client.getTransactionReceipt(txHash);
      if (receipt != null) return receipt.status;
      await Future<void>.delayed(interval);
    }
    return null;
  }

  void dispose() => _client.dispose();

  static Uint8List _hexToBytes(String hex) {
    var h = hex.startsWith('0x') ? hex.substring(2) : hex;
    if (h.length.isOdd) h = '0$h';
    final out = Uint8List(h.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = int.parse(h.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }
}
