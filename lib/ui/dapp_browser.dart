import 'dart:async';
import 'dart:collection';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../dapp/dapp_history.dart';
import '../dapp/dapp_permissions.dart';
import '../dapp/octra_provider_host.dart';
import '../wallet.dart';

const _bg = Color(0xFF000000);
const _card = Color(0xFF1C1C1E);
const _card2 = Color(0xFF2C2C2E);
const _sub = Color(0xFF8E8E93);
const _faint = Color(0xFF48484A);
const _brand = Color(0xFF0A84FF);
const _green = Color(0xFF30D158);
const _amber = Color(0xFFFF9F0A);

// Deterministic accent colour per host, so a site looks the same every visit.
const _palette = [
  Color(0xFF0A84FF), Color(0xFF30D158), Color(0xFFBF5AF2), Color(0xFFFF9F0A),
  Color(0xFFFF375F), Color(0xFF5E5CE6), Color(0xFF64D2FF), Color(0xFFFFD60A),
];
Color _colorFor(String s) {
  var h = 0;
  for (final c in s.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return _palette[h % _palette.length];
}

String _hostOf(String url) => Uri.tryParse(url)?.host ?? url;

String? _normalizeUrl(String input) {
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

// ─────────────────────────────────────────────────────────────────────────────
//  Shared widgets
// ─────────────────────────────────────────────────────────────────────────────

/// A tap target with an iOS-style press-scale animation.
class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  const _Pressable({required this.child, this.onTap, this.scale = 0.96});
  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _p = false;
  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _p = true) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _p = false);
              widget.onTap!();
            }
          : null,
      onTapCancel: enabled ? () => setState(() => _p = false) : null,
      child: AnimatedScale(
        scale: _p ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// A rounded letter avatar coloured deterministically from [host].
class _SiteAvatar extends StatelessWidget {
  final String host;
  final double size;
  const _SiteAvatar({required this.host, this.size = 42});
  @override
  Widget build(BuildContext context) {
    final h = host.replaceFirst('www.', '');
    final letter = h.isEmpty ? '?' : h.characters.first.toUpperCase();
    final color = _colorFor(h);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.30), color.withValues(alpha: 0.14)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      alignment: Alignment.center,
      child: Text(letter,
          style: TextStyle(
              color: color, fontSize: size * 0.42, fontWeight: FontWeight.w800)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  dApp home — search + featured + bookmarks + recents
// ─────────────────────────────────────────────────────────────────────────────

class _Featured {
  final String name;
  final String url;
  final IconData icon;
  final Color color;
  const _Featured(this.name, this.url, this.icon, this.color);
}

const _featured = <_Featured>[
  _Featured('Octra Explorer', 'https://octra.network', CupertinoIcons.cube_box,
      Color(0xFF0A84FF)),
  _Featured('OCT ⇄ wOCT Bridge', 'https://bridge.0xio.xyz',
      CupertinoIcons.arrow_2_squarepath, Color(0xFF30D158)),
];

class DappHomeScreen extends StatefulWidget {
  const DappHomeScreen({super.key});
  @override
  State<DappHomeScreen> createState() => _DappHomeScreenState();
}

class _DappHomeScreenState extends State<DappHomeScreen> {
  final _urlCtrl = TextEditingController();
  final DappHistoryStore _history = DappHistoryStore();

  @override
  void initState() {
    super.initState();
    _history.load();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _history.dispose();
    super.dispose();
  }

  Future<void> _open(String input) async {
    final url = _normalizeUrl(input);
    if (url == null) return;
    FocusScope.of(context).unfocus();
    _urlCtrl.clear();
    await Navigator.of(context).push(CupertinoPageRoute(
      builder: (_) => DappBrowserScreen(initialUrl: url, history: _history),
    ));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: _bg,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('dApps'),
        backgroundColor: Color(0xCC000000),
        border: Border(),
      ),
      child: SafeArea(
        child: AnimatedBuilder(
          animation: _history,
          builder: (context, _) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _searchBar()
                    .animate()
                    .fadeIn(duration: 250.ms)
                    .slideY(begin: -0.15, end: 0, curve: Curves.easeOut),
                const SizedBox(height: 8),
                const Text(
                  'Open Octra dApps. A site sees only your address until you '
                  'approve each action.',
                  style: TextStyle(color: _sub, fontSize: 12.5, height: 1.3),
                ),
                const SizedBox(height: 24),
                _sectionHeader('Featured'),
                const SizedBox(height: 10),
                ..._featured.asMap().entries.map((e) => _featuredTile(e.value)
                    .animate()
                    .fadeIn(delay: (80 * e.key).ms, duration: 260.ms)
                    .slideX(begin: 0.08, end: 0, curve: Curves.easeOut)),
                if (_history.bookmarks.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  _sectionHeader('Bookmarks'),
                  const SizedBox(height: 10),
                  ..._history.bookmarks.map(
                      (s) => _siteTile(s, onRemove: () => _history.toggleBookmark(s.url, s.title))),
                ],
                if (_history.recents.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  _sectionHeader('Recent',
                      action: 'Clear', onAction: _history.clearRecents),
                  const SizedBox(height: 10),
                  ..._history.recents.map(
                      (s) => _siteTile(s, onRemove: () => _history.removeRecent(s.url))),
                ],
                if (_history.bookmarks.isEmpty && _history.recents.isEmpty)
                  _emptyHint(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, {String? action, VoidCallback? onAction}) {
    return Row(
      children: [
        Text(title,
            style: const TextStyle(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
        const Spacer(),
        if (action != null)
          _Pressable(
            onTap: onAction,
            child: Text(action,
                style: const TextStyle(color: _brand, fontSize: 13)),
          ),
      ],
    );
  }

  Widget _searchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _card2),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.search, size: 17, color: _sub),
          const SizedBox(width: 8),
          Expanded(
            child: CupertinoTextField(
              controller: _urlCtrl,
              placeholder: 'Search or enter dApp URL',
              placeholderStyle: const TextStyle(color: _faint, fontSize: 15),
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: const BoxDecoration(),
              padding: const EdgeInsets.symmetric(vertical: 13),
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

  Widget _featuredTile(_Featured d) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _Pressable(
        scale: 0.98,
        onTap: () => _open(d.url),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [d.color.withValues(alpha: 0.14), _card],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: d.color.withValues(alpha: 0.22)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: d.color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(d.icon, color: d.color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(_hostOf(d.url),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _sub, fontSize: 12.5)),
                  ],
                ),
              ),
              const Icon(CupertinoIcons.chevron_right, size: 16, color: _faint),
            ],
          ),
        ),
      ),
    );
  }

  Widget _siteTile(DappSite s, {VoidCallback? onRemove}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _Pressable(
        scale: 0.98,
        onTap: () => _open(s.url),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              _SiteAvatar(host: s.host, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500)),
                    Text(s.host,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _sub, fontSize: 12)),
                  ],
                ),
              ),
              if (onRemove != null)
                _Pressable(
                  onTap: onRemove,
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(CupertinoIcons.xmark, size: 14, color: _faint),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyHint() {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(CupertinoIcons.compass, size: 34, color: _faint),
          ),
          const SizedBox(height: 14),
          const Text('No recent dApps yet',
              style: TextStyle(color: _sub, fontSize: 14)),
          const SizedBox(height: 4),
          const Text('Open one above to get started',
              style: TextStyle(color: _faint, fontSize: 12.5)),
        ],
      ).animate().fadeIn(delay: 150.ms),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  dApp browser — webview + RFC-O-1 provider host
// ─────────────────────────────────────────────────────────────────────────────

class DappBrowserScreen extends StatefulWidget {
  final String initialUrl;
  final DappHistoryStore history;
  const DappBrowserScreen(
      {super.key, required this.initialUrl, required this.history});
  @override
  State<DappBrowserScreen> createState() => _DappBrowserScreenState();
}

class _DappBrowserScreenState extends State<DappBrowserScreen> {
  final DappPermissionStore _perms = DappPermissionStore();
  final _urlCtrl = TextEditingController();
  final _urlFocus = FocusNode();
  InAppWebViewController? _controller;
  OctraProviderHost? _host;
  String? _injectedJs;

  String _url = '';
  String _origin = '';
  String _title = '';
  int _progress = 0;
  bool _isSecure = true;
  bool _canBack = false;
  bool _canForward = false;
  bool _editingUrl = false;
  String? _error;
  String _loadingUrl = '';

  @override
  void initState() {
    super.initState();
    _url = widget.initialUrl;
    _origin = _originOf(widget.initialUrl);
    _urlCtrl.text = widget.initialUrl;
    _urlFocus.addListener(() {
      if (mounted) setState(() => _editingUrl = _urlFocus.hasFocus);
    });
    _loadProviderJs();
  }

  Future<void> _loadProviderJs() async {
    final js = await rootBundle.loadString('assets/octra_provider.js');
    if (mounted) setState(() => _injectedJs = js);
  }

  static String _originOf(String url) {
    final u = Uri.tryParse(url);
    if (u == null) return url;
    return u.hasPort
        ? '${u.scheme}://${u.host}:${u.port}'
        : '${u.scheme}://${u.host}';
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
    _urlCtrl.dispose();
    _urlFocus.dispose();
    _perms.dispose();
    super.dispose();
  }

  // ── navigation / chrome ──────────────────────────────────────────────────────

  Future<void> _refreshNavState() async {
    final c = _controller;
    if (c == null) return;
    final back = await c.canGoBack();
    final fwd = await c.canGoForward();
    if (mounted) {
      setState(() {
        _canBack = back;
        _canForward = fwd;
      });
    }
  }

  void _goUrl(String input) {
    final url = _normalizeUrl(input);
    if (url == null) return;
    _urlFocus.unfocus();
    _controller?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
  }

  void _onUrlChanged(String? url) {
    if (url == null) return;
    final o = _originOf(url);
    setState(() {
      _url = url;
      _origin = o;
      _isSecure = url.startsWith('https');
      if (!_editingUrl) _urlCtrl.text = url;
    });
    _ensureHost().origin = o;
    _perms.load(o).then((_) {
      if (mounted) setState(() {});
    });
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
    return CupertinoPageScaffold(
      backgroundColor: _bg,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _topBar(),
            _ProgressLine(progress: _progress),
            Expanded(
              child: Stack(
                children: [
                  _webview(),
                  if (_error != null) _errorOverlay(),
                ],
              ),
            ),
            _bottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    final connected = _perms.isConnected(_origin);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      color: const Color(0xFF0A0A0A),
      child: Row(
        children: [
          _Pressable(
            onTap: () => Navigator.of(context).maybePop(),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(CupertinoIcons.chevron_down, size: 20, color: Colors.white),
            ),
          ),
          const SizedBox(width: 2),
          Expanded(child: _urlField(connected)),
          const SizedBox(width: 2),
          _Pressable(
            onTap: _showMenu,
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(CupertinoIcons.ellipsis, size: 20, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _urlField(bool connected) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          Icon(
            _isSecure ? CupertinoIcons.lock_fill : CupertinoIcons.exclamationmark_triangle_fill,
            size: 12,
            color: _isSecure ? _green : _amber,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: CupertinoTextField(
              controller: _urlCtrl,
              focusNode: _urlFocus,
              decoration: const BoxDecoration(),
              padding: EdgeInsets.zero,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              keyboardType: TextInputType.url,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.go,
              maxLines: 1,
              onTap: () {
                if (!_editingUrl) {
                  _urlCtrl.selection = TextSelection(
                      baseOffset: 0, extentOffset: _urlCtrl.text.length);
                }
              },
              onSubmitted: _goUrl,
            ),
          ),
          if (connected && !_editingUrl) ...[
            const SizedBox(width: 6),
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(color: _green, shape: BoxShape.circle),
            ),
          ],
        ],
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
        useHybridComposition: true,
        javaScriptEnabled: true,
        supportZoom: false,
        useShouldOverrideUrlLoading: true,
        supportMultipleWindows: true,
        javaScriptCanOpenWindowsAutomatically: true,
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
        useOnDownloadStart: true,
      ),
      onWebViewCreated: (c) {
        _controller = c;
        _ensureHost().attach(c);
      },
      onLoadStart: (c, url) {
        _error = null;
        _loadingUrl = url?.toString() ?? '';
        _onUrlChanged(url?.toString());
      },
      onLoadStop: (c, url) async {
        final t = await c.getTitle();
        if (mounted) setState(() => _title = t ?? '');
        _onUrlChanged(url?.toString());
        _refreshNavState();
        if ((url?.toString() ?? '').startsWith('http')) {
          widget.history.addRecent(url.toString(), t ?? '');
        }
      },
      onTitleChanged: (c, title) {
        if (mounted) setState(() => _title = title ?? '');
      },
      onProgressChanged: (c, p) {
        if (mounted) setState(() => _progress = p);
      },
      onUpdateVisitedHistory: (c, url, isReload) {
        _onUrlChanged(url?.toString());
        _refreshNavState();
      },
      onReceivedError: (c, request, error) {
        // Only surface main-document failures, not sub-resource ones.
        if (request.url.toString() == _loadingUrl) {
          if (mounted) setState(() => _error = error.description);
        }
      },
      shouldOverrideUrlLoading: (c, action) async {
        final u = action.request.url;
        if (u == null) return NavigationActionPolicy.ALLOW;
        const inApp = {'http', 'https', 'about', 'data', 'blob', 'javascript'};
        if (inApp.contains(u.scheme)) return NavigationActionPolicy.ALLOW;
        // tel:, mailto:, wc:, intent:, upi:, etc. → hand to the OS.
        try {
          await launchUrl(Uri.parse(u.toString()),
              mode: LaunchMode.externalApplication);
        } catch (_) {}
        return NavigationActionPolicy.CANCEL;
      },
      onCreateWindow: (c, createWindowAction) async {
        // target=_blank / window.open → keep it in this view.
        final u = createWindowAction.request.url;
        if (u != null) {
          c.loadUrl(urlRequest: URLRequest(url: u));
        }
        return false;
      },
      onDownloadStartRequest: (c, req) async {
        try {
          await launchUrl(Uri.parse(req.url.toString()),
              mode: LaunchMode.externalApplication);
        } catch (_) {}
      },
    );
  }

  Widget _errorOverlay() {
    return Container(
      color: _bg,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _amber.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(CupertinoIcons.wifi_slash, size: 34, color: _amber),
          ),
          const SizedBox(height: 16),
          const Text("Couldn't load page",
              style: TextStyle(
                  color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(_error ?? 'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _sub, fontSize: 13)),
          const SizedBox(height: 20),
          _Pressable(
            onTap: () {
              setState(() => _error = null);
              _controller?.reload();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              decoration: BoxDecoration(
                  color: _brand, borderRadius: BorderRadius.circular(12)),
              child: const Text('Try again',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ).animate().fadeIn(duration: 200.ms),
    );
  }

  Widget _bottomBar() {
    final bookmarked = widget.history.isBookmarked(_url);
    return Container(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewPadding.bottom > 0 ? 8 : 6,
          top: 4),
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A),
        border: Border(top: BorderSide(color: _card2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navBtn(CupertinoIcons.back, _canBack, () => _controller?.goBack()),
          _navBtn(CupertinoIcons.forward, _canForward,
              () => _controller?.goForward()),
          _navBtn(CupertinoIcons.refresh, true, () => _controller?.reload()),
          _navBtn(
            bookmarked ? CupertinoIcons.bookmark_fill : CupertinoIcons.bookmark,
            true,
            () async {
              await widget.history.toggleBookmark(_url, _title);
              if (mounted) {
                HapticFeedback.selectionClick();
                setState(() {});
              }
            },
            color: bookmarked ? _brand : null,
          ),
          _navBtn(CupertinoIcons.house, true,
              () => Navigator.of(context).maybePop()),
        ],
      ),
    );
  }

  Widget _navBtn(IconData icon, bool enabled, VoidCallback onTap, {Color? color}) {
    return _Pressable(
      scale: 0.85,
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Icon(icon,
            size: 23,
            color: enabled ? (color ?? Colors.white) : _faint),
      ),
    );
  }

  // ── ••• menu ───────────────────────────────────────────────────────────────────

  void _showMenu() {
    final connected = _perms.isConnected(_origin);
    final bookmarked = widget.history.isBookmarked(_url);
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(_hostOf(_url)),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              widget.history.toggleBookmark(_url, _title);
              if (mounted) setState(() {});
            },
            child: Text(bookmarked ? 'Remove bookmark' : 'Add bookmark'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              Clipboard.setData(ClipboardData(text: _url));
              HapticFeedback.selectionClick();
            },
            child: const Text('Copy link'),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(ctx);
              final uri = Uri.tryParse(_url);
              if (uri != null) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('Open in browser'),
          ),
          if (connected)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(ctx);
                _disconnect();
              },
              child: const Text('Disconnect'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  // ── consent + approval sheets ──────────────────────────────────────────────────

  Future<Set<DappPermission>?> _showConnectSheet(
      String origin, List<DappPermission> requested) {
    // read_address is always required; others are toggleable.
    final selected = requested.toSet();
    final host = Uri.tryParse(origin)?.host ?? origin;
    return showCupertinoModalPopup<Set<DappPermission>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => _Sheet(
          host: host,
          title: 'Connect wallet',
          children: [
            const Text('This dApp is requesting permission to:',
                style: TextStyle(color: _sub, fontSize: 13)),
            const SizedBox(height: 12),
            ...requested.map((p) {
              final required = p == DappPermission.readAddress;
              final on = selected.contains(p);
              return _Pressable(
                onTap: required
                    ? null
                    : () => setSheet(() =>
                        on ? selected.remove(p) : selected.add(p)),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  decoration: BoxDecoration(
                    color: _card2,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        on
                            ? CupertinoIcons.checkmark_circle_fill
                            : CupertinoIcons.circle,
                        size: 18,
                        color: on ? _brand : _faint,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(p.label,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13.5)),
                      ),
                      if (required)
                        const Text('required',
                            style: TextStyle(color: _faint, fontSize: 11)),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            _SheetActions(
              approveLabel: 'Connect',
              approveColor: _brand,
              onApprove: selected.isEmpty
                  ? null
                  : () => Navigator.of(ctx).pop(selected),
              onReject: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showApprovalSheet(DappPrompt prompt) async {
    final host = Uri.tryParse(prompt.origin)?.host ?? prompt.origin;
    final result = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (ctx) => _Sheet(
        host: host,
        title: prompt.title,
        children: [
          if (prompt.body != null) ...[
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 180),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: _card2, borderRadius: BorderRadius.circular(10)),
              child: SingleChildScrollView(
                child: Text(prompt.body!,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontFamily: 'monospace')),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (prompt.rows.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                  color: _card2, borderRadius: BorderRadius.circular(10)),
              child: Column(
                children: prompt.rows
                    .map((r) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                  width: 76,
                                  child: Text(r.key,
                                      style: const TextStyle(
                                          color: _sub, fontSize: 13))),
                              Expanded(
                                child: Text(r.value,
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500)),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
          const SizedBox(height: 14),
          _SheetActions(
            approveLabel: 'Approve',
            approveColor: _brand,
            onApprove: () => Navigator.of(ctx).pop(true),
            onReject: () => Navigator.of(ctx).pop(false),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

// ── progress line that fades out at 100% ───────────────────────────────────────

class _ProgressLine extends StatelessWidget {
  final int progress;
  const _ProgressLine({required this.progress});
  @override
  Widget build(BuildContext context) {
    final done = progress >= 100;
    return AnimatedOpacity(
      opacity: done ? 0 : 1,
      duration: const Duration(milliseconds: 250),
      child: SizedBox(
        height: 2.5,
        child: Stack(
          children: [
            Container(color: _card),
            AnimatedFractionallySizedBox(
              duration: const Duration(milliseconds: 180),
              widthFactor: (progress / 100.0).clamp(0.02, 1.0),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Color(0xFF0A84FF), Color(0xFF64D2FF)]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── shared sheet shell + actions ───────────────────────────────────────────────

class _Sheet extends StatelessWidget {
  final String host;
  final String title;
  final List<Widget> children;
  const _Sheet(
      {required this.host, required this.title, required this.children});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                      color: _faint, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 18),
            Center(child: _SiteAvatar(host: host, size: 52)),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(host,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _brand, fontSize: 13)),
            const SizedBox(height: 18),
            ...children,
          ],
        ),
      ),
    ).animate().slideY(
        begin: 0.15, end: 0, duration: 240.ms, curve: Curves.easeOutCubic);
  }
}

class _SheetActions extends StatelessWidget {
  final String approveLabel;
  final Color approveColor;
  final VoidCallback? onApprove;
  final VoidCallback onReject;
  const _SheetActions({
    required this.approveLabel,
    required this.approveColor,
    required this.onApprove,
    required this.onReject,
  });
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Pressable(
            onTap: onReject,
            child: Container(
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: _card2, borderRadius: BorderRadius.circular(14)),
              child: const Text('Reject',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _Pressable(
            onTap: onApprove,
            child: Container(
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: onApprove == null
                    ? approveColor.withValues(alpha: 0.4)
                    : approveColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(approveLabel,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ],
    );
  }
}
