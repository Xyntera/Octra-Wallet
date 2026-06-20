import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:walletconnect_flutter_v2/walletconnect_flutter_v2.dart';

/// WalletConnect / Reown project id. A public client identifier (safe to
/// embed); override at build time with
///   flutter build … --dart-define=WC_PROJECT_ID=(id from cloud.reown.com)
const String kWalletConnectProjectId = String.fromEnvironment(
  'WC_PROJECT_ID',
  defaultValue: '47448c64c8b30f433cb48b5859579a7c',
);

const String _eip155Mainnet = 'eip155:1';

/// WalletConnect v2 dApp client for the "connect external wallet" bridge mode
/// (MetaMask, Trust, Rainbow, …): the app builds transactions; the user signs
/// in their own wallet.
///
/// Implemented as a process-wide singleton ([instance]) so the live session
/// survives screen navigation and is restored after an app restart. This is
/// essential — a per-screen instance loses the session the moment you leave the
/// bridge screen, which makes signing silently impossible.
class WcService extends ChangeNotifier {
  WcService._();

  /// Shared instance. Always use this; never construct a second one.
  static final WcService instance = WcService._();

  Web3App? _app;
  SessionData? _session;

  /// Deep links to bring the connected wallet to the foreground so the user can
  /// see and approve a signing request. Captured from the session peer metadata
  /// (and seeded from the picker selection as a fallback for wallets that omit
  /// a redirect in their metadata).
  String? _redirectNative;
  String? _redirectUniversal;

  bool _initializing = false;

  bool get isConfigured => kWalletConnectProjectId.isNotEmpty;

  /// True only when there is a live, non-expired session.
  bool get isConnected {
    final s = _session;
    if (s == null) return false;
    return s.expiry * 1000 > DateTime.now().millisecondsSinceEpoch;
  }

  /// Connected EIP-155 address (checksummed as returned by the wallet), or null.
  String? get address {
    final accounts = _session?.namespaces['eip155']?.accounts;
    if (accounts == null || accounts.isEmpty) return null;
    return accounts.first.split(':').last; // 'eip155:1:0x...' -> '0x...'
  }

  /// Human label for the connected wallet (from its metadata), if any.
  String? get peerName => _session?.peer.metadata.name;

  // ---- lifecycle -----------------------------------------------------------

  /// Ensures the client exists and any previously approved session is restored.
  /// Safe to call repeatedly and concurrently.
  Future<void> ensureReady() async {
    if (_app != null) return;
    if (_initializing) {
      // Wait for the in-flight init to settle.
      while (_initializing) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      return;
    }
    _initializing = true;
    try {
      _app = await Web3App.createInstance(
        projectId: kWalletConnectProjectId,
        relayUrl: 'wss://relay.walletconnect.com',
        metadata: const PairingMetadata(
          name: 'Octra Wallet',
          description: 'OCT ⇄ wOCT bridge',
          url: 'https://octrawallet.com',
          icons: ['https://octrawallet.com/icon.png'],
          redirect: Redirect(
            native: 'octrawallet://',
            universal: 'https://octrawallet.com',
          ),
        ),
      );
      _app!.onSessionConnect.subscribe(_onSessionConnect);
      _app!.onSessionDelete.subscribe(_onSessionDelete);
      _app!.onSessionExpire.subscribe(_onSessionExpire);
      _restoreSession();
    } catch (_) {
      // Leave _app null; callers surface a friendly "not connected" error.
    } finally {
      _initializing = false;
    }
  }

  void _restoreSession() {
    final app = _app;
    if (app == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    SessionData? latest;
    for (final s in app.sessions.getAll()) {
      if (s.expiry * 1000 <= now) continue;
      if (latest == null || s.expiry > latest.expiry) latest = s;
    }
    if (latest != null) {
      _session = latest;
      _captureRedirect(latest);
      notifyListeners();
    }
  }

  void _captureRedirect(SessionData s) {
    final r = s.peer.metadata.redirect;
    if (r?.native != null && r!.native!.isNotEmpty) _redirectNative = r.native;
    if (r?.universal != null && r!.universal!.isNotEmpty) {
      _redirectUniversal = r.universal;
    }
  }

  void _onSessionConnect(SessionConnect? e) {
    if (e == null) return;
    _session = e.session;
    _captureRedirect(e.session);
    notifyListeners();
  }

  void _onSessionDelete(SessionDelete? e) {
    if (e == null) return;
    if (e.topic == _session?.topic) {
      _session = null;
      notifyListeners();
    }
  }

  void _onSessionExpire(SessionExpire? e) {
    if (e == null) return;
    if (e.topic == _session?.topic) {
      _session = null;
      notifyListeners();
    }
  }

  /// Seeds the wallet redirect from a picker selection. Used as a fallback for
  /// wallets whose session metadata omits a redirect.
  void setPreferredRedirect({String? native, String? universal}) {
    if (native != null && native.isNotEmpty) _redirectNative = native;
    if (universal != null && universal.isNotEmpty) {
      _redirectUniversal = universal;
    }
  }

  // ---- connect -------------------------------------------------------------

  /// Starts a pairing and returns the `wc:` URI to render as a QR / deep link.
  /// [onConnected] fires once the wallet approves the session.
  Future<String> beginConnect({
    required void Function(String address) onConnected,
    void Function(Object error)? onError,
  }) async {
    if (!isConfigured) {
      throw StateError('WalletConnect is not configured.');
    }
    await ensureReady();
    final app = _app;
    if (app == null) {
      throw StateError('WalletConnect failed to initialize.');
    }
    // Require only what we actually use so wallets that disable extra methods
    // (e.g. eth_sign) don't reject the whole session. Offer the rest as
    // optional for wallets that support them.
    final resp = await app.connect(
      requiredNamespaces: const {
        'eip155': RequiredNamespace(
          chains: [_eip155Mainnet],
          methods: ['eth_sendTransaction'],
          events: ['accountsChanged', 'chainChanged'],
        ),
      },
      optionalNamespaces: const {
        'eip155': RequiredNamespace(
          chains: [_eip155Mainnet],
          methods: ['personal_sign', 'eth_signTransaction'],
          events: ['accountsChanged', 'chainChanged'],
        ),
      },
    );
    resp.session.future.then((session) {
      _session = session;
      _captureRedirect(session);
      notifyListeners();
      final a = address;
      if (a != null) onConnected(a);
    }).catchError((Object e) {
      onError?.call(e);
    });
    return resp.uri?.toString() ?? '';
  }

  // ---- signing -------------------------------------------------------------

  /// Asks the connected wallet to sign + send an `eth_sendTransaction`, bringing
  /// the wallet app to the foreground so the user sees the approval prompt.
  /// Returns the transaction hash.
  Future<String> sendTransaction(Map<String, dynamic> tx) async {
    final app = _app;
    final session = _session;
    if (app == null || session == null || !isConnected) {
      throw StateError('WalletConnect is not connected');
    }

    // Dispatch the request first (do NOT await yet — it only completes once the
    // user approves), then surface the wallet so the prompt is actually shown.
    final pending = app.request(
      topic: session.topic,
      chainId: _eip155Mainnet,
      request: SessionRequestParams(
        method: 'eth_sendTransaction',
        params: [tx],
      ),
    );

    // Give the relay a moment to receive the request, then open the wallet.
    unawaited(Future<void>.delayed(const Duration(milliseconds: 350))
        .then((_) => _openWalletForApproval()));

    // The request only resolves once the user responds in their wallet. Cap the
    // wait so a forgotten/abandoned prompt can't freeze the UI forever. The tx
    // is only broadcast after approval, so timing out before that sends nothing.
    final result = await pending.timeout(
      const Duration(minutes: 3),
      onTimeout: () => throw TimeoutException(
          'No response from wallet — open your wallet and try again.'),
    );
    return result.toString();
  }

  /// Brings the connected wallet app to the foreground for an approval. Tries
  /// the native scheme first, then a universal link. No-op if neither is known
  /// (the user can switch to their wallet manually).
  Future<void> _openWalletForApproval() async {
    for (final target in [_redirectNative, _redirectUniversal]) {
      if (target == null || target.isEmpty) continue;
      final uri = Uri.tryParse(target);
      if (uri == null) continue;
      try {
        if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
      } catch (_) {/* try next */}
    }
  }

  // ---- disconnect ----------------------------------------------------------

  Future<void> disconnect() async {
    final app = _app;
    final session = _session;
    _session = null;
    _redirectNative = null;
    _redirectUniversal = null;
    notifyListeners();
    if (app != null && session != null) {
      try {
        await app.disconnectSession(
          topic: session.topic,
          reason: const WalletConnectError(
              code: 6000, message: 'User disconnected'),
        );
      } catch (_) {/* best effort */}
    }
  }

  // A singleton must never be disposed by a screen; override to a no-op so an
  // accidental dispose() can't mark the notifier dead and break the session.
  // Intentionally does not call super.dispose().
  @override
  // ignore: must_call_super
  void dispose() {/* intentionally not disposed; process-wide singleton */}
}
