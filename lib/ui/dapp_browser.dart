import 'dart:async';
import 'dart:collection';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show Colors, Material, InkWell, LinearProgressIndicator;
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';

import '../dapp/dapp_permissions.dart';
import '../dapp/octra_provider_host.dart';
import '../wallet.dart';

const _bg = Color(0xFF000000);
const _card = Color(0xFF1C1C1E);
const _card2 = Color(0xFF2C2C2E);
const _sub = Color(0xFF8E8E93);
const _brand = Color(0xFF0A84FF);

/// A featured Octra dApp shortcut.
class _FeaturedDapp {
  final String name;
  final String url;
  final IconData icon;
  final Color color;
  const _FeaturedDapp(this.name, this.url, this.icon, this.color);
}

const _featured = <_FeaturedDapp>[
  _FeaturedDapp('Octra Explorer', 'https://octra.network',
      CupertinoIcons.cube_box, Color(0xFF0A84FF)),
  _FeaturedDapp('OCT ⇄ wOCT Bridge', 'https://bridge.0xio.xyz',
      CupertinoIcons.arrow_2_squarepath, Color(0xFF30D158)),
];

// ─────────────────────────────────────────────────────────────────────────────
//  dApp home — URL bar + featured + recents
// ─────────────────────────────────────────────────────────────────────────────

class DappHomeScreen extends StatefulWidget {
  const DappHomeScreen({super.key});
  @override
  State<DappHomeScreen> createState() => _DappHomeScreenState();
}

class _DappHomeScreenState extends State<DappHomeScreen> {
  final _urlCtrl = TextEditingController();

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  void _open(String input) {
    final url = _normalizeUrl(input);
    if (url == null) return;
    FocusScope.of(context).unfocus();
    Navigator.of(context).push(CupertinoPageRoute(
      builder: (_) => DappBrowserScreen(initialUrl: url),
    ));
  }

  static String? _normalizeUrl(String input) {
    var s = input.trim();
    if (s.isEmpty) return null;
    final looksLikeDomain = s.contains('.') && !s.contains(' ');
    if (!s.startsWith('http://') && !s.startsWith('https://')) {
      s = looksLikeDomain
          ? 'https://$s'
          : 'https://duckduckgo.com/?q=${Uri.encodeQueryComponent(s)}';
    }
    return Uri.tryParse(s)?.toString();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: _bg,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('dApps'),
        backgroundColor: Color(0xCC000000),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _urlBar(),
            const SizedBox(height: 8),
            const Text(
              'Connect to Octra dApps. The site sees only your address until you '
              'approve each action.',
              style: TextStyle(color: _sub, fontSize: 12.5, height: 1.3),
            ),
            const SizedBox(height: 22),
            const Text('Featured',
                style: TextStyle(
                    color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            ..._featured.map(_featuredTile),
          ],
        ),
      ),
    );
  }

  Widget _urlBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.search, size: 17, color: _sub),
          const SizedBox(width: 8),
          Expanded(
            child: CupertinoTextField(
              controller: _urlCtrl,
              placeholder: 'Search or enter dApp URL',
              placeholderStyle: const TextStyle(color: Color(0xFF48484A)),
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: const BoxDecoration(),
              padding: const EdgeInsets.symmetric(vertical: 12),
              keyboardType: TextInputType.url,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.go,
              onSubmitted: _open,
            ),
          ),
        ],
      ),
    );
  }

  Widget _featuredTile(_FeaturedDapp d) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _open(d.url),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: d.color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(d.icon, color: d.color, size: 21),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(Uri.parse(d.url).host,
                          style: const TextStyle(color: _sub, fontSize: 12.5)),
                    ],
                  ),
                ),
                const Icon(CupertinoIcons.chevron_right, size: 16, color: _sub),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  dApp browser — webview + RFC-O-1 provider host
// ─────────────────────────────────────────────────────────────────────────────

class DappBrowserScreen extends StatefulWidget {
  final String initialUrl;
  const DappBrowserScreen({super.key, required this.initialUrl});
  @override
  State<DappBrowserScreen> createState() => _DappBrowserScreenState();
}

class _DappBrowserScreenState extends State<DappBrowserScreen> {
  final DappPermissionStore _perms = DappPermissionStore();
  InAppWebViewController? _controller;
  OctraProviderHost? _host;
  String? _injectedJs;

  String _origin = '';
  String _title = '';
  int _progress = 0;
  bool _isSecure = true;
  bool _canBack = false;

  @override
  void initState() {
    super.initState();
    _origin = _originOf(widget.initialUrl);
    _loadProviderJs();
  }

  Future<void> _loadProviderJs() async {
    final js = await rootBundle.loadString('assets/octra_provider.js');
    if (mounted) setState(() => _injectedJs = js);
  }

  static String _originOf(String url) {
    final u = Uri.tryParse(url);
    if (u == null) return url;
    return u.hasPort ? '${u.scheme}://${u.host}:${u.port}' : '${u.scheme}://${u.host}';
  }

  OctraProviderHost _ensureHost() {
    final wallet = context.read<WalletController>();
    final host = _host ??= OctraProviderHost(
      wallet: wallet,
      perms: _perms,
      origin: _origin,
      onConnect: _showConnectSheet,
      onApprove: _showApprovalSheet,
    );
    host.origin = _origin;
    return host;
  }

  @override
  void dispose() {
    _perms.dispose();
    super.dispose();
  }

  // ── chrome actions ───────────────────────────────────────────────────────────

  Future<void> _updateNav() async {
    final c = _controller;
    if (c == null) return;
    final back = await c.canGoBack();
    if (mounted) setState(() => _canBack = back);
  }

  void _disconnect() async {
    await _perms.revoke(_origin);
    _host?.emitDisconnect();
    _host?.emitAccountsChanged();
    if (mounted) setState(() {});
  }

  // ── build ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final connected = _perms.isConnected(_origin);
    return CupertinoPageScaffold(
      backgroundColor: _bg,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: const Color(0xCC000000),
        middle: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_title.isEmpty ? 'Loading…' : _title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_isSecure ? CupertinoIcons.lock_fill : CupertinoIcons.exclamationmark_triangle,
                    size: 9, color: _isSecure ? const Color(0xFF30D158) : const Color(0xFFFF9F0A)),
                const SizedBox(width: 3),
                Text(Uri.tryParse(_origin)?.host ?? _origin,
                    style: const TextStyle(fontSize: 11, color: _sub)),
              ],
            ),
          ],
        ),
        trailing: connected
            ? GestureDetector(
                onTap: _disconnect,
                child: const Icon(CupertinoIcons.link, size: 20, color: Color(0xFF30D158)),
              )
            : null,
      ),
      child: SafeArea(
        child: Column(
          children: [
            if (_progress < 100)
              LinearProgressIndicator(
                value: _progress / 100.0,
                minHeight: 2,
                backgroundColor: Colors.transparent,
                valueColor: const AlwaysStoppedAnimation(_brand),
              ),
            Expanded(child: _webview()),
            _bottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _webview() {
    if (_injectedJs == null) {
      return const Center(child: CupertinoActivityIndicator());
    }
    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(widget.initialUrl)),
      initialUserScripts: UnmodifiableListView([
        UserScript(
          source: _injectedJs!,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
          forMainFrameOnly: true,
        ),
      ]),
      initialSettings: InAppWebViewSettings(
        transparentBackground: true,
        useHybridComposition: true, // smoother Android rendering
        javaScriptEnabled: true,
        supportZoom: false,
        useShouldOverrideUrlLoading: false,
      ),
      onWebViewCreated: (c) {
        _controller = c;
        _ensureHost().attach(c);
      },
      onLoadStart: (c, url) {
        if (url != null) {
          final o = _originOf(url.toString());
          setState(() {
            _origin = o;
            _isSecure = url.scheme == 'https';
          });
          _ensureHost().origin = o;
          // Load any persisted grant so the connected chip reflects it.
          _perms.load(o).then((_) {
            if (mounted) setState(() {});
          });
        }
      },
      onLoadStop: (c, url) async {
        final t = await c.getTitle();
        if (mounted) setState(() => _title = t ?? '');
        _updateNav();
      },
      onProgressChanged: (c, p) {
        if (mounted) setState(() => _progress = p);
      },
      onUpdateVisitedHistory: (c, url, isReload) {
        if (url != null) {
          final o = _originOf(url.toString());
          if (o != _origin) {
            setState(() => _origin = o);
            _ensureHost().origin = o;
          }
        }
        _updateNav();
      },
    );
  }

  Widget _bottomBar() {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: Color(0xCC1C1C1E),
        border: Border(top: BorderSide(color: Color(0xFF2C2C2E))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navBtn(CupertinoIcons.back, _canBack, () => _controller?.goBack()),
          _navBtn(CupertinoIcons.refresh, true, () => _controller?.reload()),
          _navBtn(CupertinoIcons.house, true,
              () => Navigator.of(context).maybePop()),
        ],
      ),
    );
  }

  Widget _navBtn(IconData icon, bool enabled, VoidCallback onTap) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: enabled ? onTap : null,
      child: Icon(icon, size: 22, color: enabled ? Colors.white : const Color(0xFF48484A)),
    );
  }

  // ── consent + approval sheets ──────────────────────────────────────────────────

  Future<Set<DappPermission>?> _showConnectSheet(
      String origin, List<DappPermission> requested) {
    final selected = requested.toSet();
    return showCupertinoModalPopup<Set<DappPermission>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => _sheet(
          title: 'Connect',
          subtitle: Uri.tryParse(origin)?.host ?? origin,
          children: [
            const Text('This dApp is requesting:',
                style: TextStyle(color: _sub, fontSize: 13)),
            const SizedBox(height: 10),
            ...requested.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.checkmark_seal_fill,
                          size: 16, color: _brand),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(p.label,
                              style: const TextStyle(color: Colors.white, fontSize: 13.5))),
                    ],
                  ),
                )),
            const SizedBox(height: 14),
            _approveRow(
              ctx,
              approveLabel: 'Connect',
              onApprove: () => Navigator.of(ctx).pop(selected),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showApprovalSheet(DappPrompt prompt) async {
    final result = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (ctx) => _sheet(
        title: prompt.title,
        subtitle: Uri.tryParse(prompt.origin)?.host ?? prompt.origin,
        children: [
          if (prompt.body != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: _card2, borderRadius: BorderRadius.circular(10)),
              child: Text(prompt.body!,
                  style: const TextStyle(color: Colors.white, fontSize: 13)),
            ),
            const SizedBox(height: 12),
          ],
          ...prompt.rows.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                        width: 84,
                        child: Text(r.key,
                            style: const TextStyle(color: _sub, fontSize: 13))),
                    Expanded(
                        child: Text(r.value,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13))),
                  ],
                ),
              )),
          const SizedBox(height: 14),
          _approveRow(
            ctx,
            approveLabel: 'Approve',
            onApprove: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Widget _approveRow(BuildContext ctx,
      {required String approveLabel, required VoidCallback onApprove}) {
    return Row(
      children: [
        Expanded(
          child: CupertinoButton(
            color: _card2,
            padding: const EdgeInsets.symmetric(vertical: 13),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Reject',
                style: TextStyle(color: Colors.white, fontSize: 15)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: CupertinoButton(
            color: _brand,
            padding: const EdgeInsets.symmetric(vertical: 13),
            onPressed: onApprove,
            child: Text(approveLabel, style: const TextStyle(fontSize: 15)),
          ),
        ),
      ],
    );
  }

  Widget _sheet(
      {required String title, required String subtitle, required List<Widget> children}) {
    return Container(
      decoration: const BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: const Color(0xFF48484A),
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _brand, fontSize: 13)),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}
