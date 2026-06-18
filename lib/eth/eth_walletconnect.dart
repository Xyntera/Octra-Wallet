import 'package:walletconnect_flutter_v2/walletconnect_flutter_v2.dart';

/// WalletConnect project id. Provide at build time:
///   flutter build ... --dart-define=WC_PROJECT_ID=<id from cloud.reown.com>
const String kWalletConnectProjectId =
    String.fromEnvironment('WC_PROJECT_ID', defaultValue: '');

/// Thin WalletConnect v2 dApp client used for the "connect external wallet"
/// (MetaMask, etc.) bridge mode: the app builds transactions; the user signs in
/// their own wallet.
class WcService {
  Web3App? _app;
  SessionData? _session;

  bool get isConfigured => kWalletConnectProjectId.isNotEmpty;
  bool get isConnected => _session != null;

  /// Connected EIP-155 address (checksummed as returned by the wallet).
  String? get address {
    final accounts = _session?.namespaces['eip155']?.accounts;
    if (accounts == null || accounts.isEmpty) return null;
    return accounts.first.split(':').last; // 'eip155:1:0x...' -> '0x...'
  }

  Future<void> _ensureInit() async {
    _app ??= await Web3App.createInstance(
      projectId: kWalletConnectProjectId,
      relayUrl: 'wss://relay.walletconnect.com',
      metadata: PairingMetadata(
        name: 'Octra Wallet',
        description: 'OCT to wOCT bridge',
        url: 'https://octrawallet.com',
        icons: const ['https://octrawallet.com/icon.png'],
      ),
    );
  }

  /// Starts a pairing and returns the WC URI to show as a QR / deep link.
  /// [onConnected] fires once the wallet approves the session.
  Future<String> beginConnect({
    required void Function(String address) onConnected,
    void Function(Object error)? onError,
  }) async {
    if (!isConfigured) {
      throw StateError(
          'WalletConnect is not configured (build with --dart-define=WC_PROJECT_ID=...).');
    }
    await _ensureInit();
    final resp = await _app!.connect(
      requiredNamespaces: {
        'eip155': const RequiredNamespace(
          chains: ['eip155:1'],
          methods: ['eth_sendTransaction', 'personal_sign'],
          events: ['accountsChanged', 'chainChanged'],
        ),
      },
    );
    resp.session.future.then((session) {
      _session = session;
      final a = address;
      if (a != null) onConnected(a);
    }).catchError((Object e) => onError?.call(e));
    return resp.uri?.toString() ?? '';
  }

  /// Asks the connected wallet to sign+send an `eth_sendTransaction`. Returns
  /// the transaction hash.
  Future<String> sendTransaction(Map<String, dynamic> tx) async {
    final app = _app;
    final session = _session;
    if (app == null || session == null) {
      throw StateError('WalletConnect is not connected');
    }
    final result = await app.request(
      topic: session.topic,
      chainId: 'eip155:1',
      request: SessionRequestParams(
        method: 'eth_sendTransaction',
        params: [tx],
      ),
    );
    return result.toString();
  }

  Future<void> disconnect() async {
    final app = _app;
    final session = _session;
    _session = null;
    if (app != null && session != null) {
      try {
        await app.disconnectSession(
          topic: session.topic,
          reason: WalletConnectError(code: 6000, message: 'User disconnected'),
        );
      } catch (_) {/* best effort */}
    }
  }
}
