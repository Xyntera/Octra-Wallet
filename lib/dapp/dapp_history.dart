import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// One visited/bookmarked dApp entry.
class DappSite {
  final String url;
  final String title;
  final int visitedAt;
  const DappSite({required this.url, required this.title, required this.visitedAt});

  String get host => Uri.tryParse(url)?.host ?? url;

  /// `scheme://host` used for favicons.
  String get origin {
    final u = Uri.tryParse(url);
    if (u == null) return url;
    return '${u.scheme}://${u.host}';
  }

  Map<String, dynamic> toJson() =>
      {'url': url, 'title': title, 'visitedAt': visitedAt};

  factory DappSite.fromJson(Map<String, dynamic> j) => DappSite(
        url: j['url']?.toString() ?? '',
        title: j['title']?.toString() ?? '',
        visitedAt: int.tryParse(j['visitedAt']?.toString() ?? '') ?? 0,
      );
}

/// Persists the dApp browser's recents (auto) and bookmarks (user-added) in
/// [FlutterSecureStorage]. A single instance is shared between the home and
/// browser screens so changes reflect live.
class DappHistoryStore extends ChangeNotifier {
  static const _kRecents = 'dapp_recents';
  static const _kBookmarks = 'dapp_bookmarks';
  static const _maxRecents = 24;

  final FlutterSecureStorage _storage;
  List<DappSite> recents = [];
  List<DappSite> bookmarks = [];
  bool _loaded = false;

  DappHistoryStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<void> load() async {
    if (_loaded) return;
    recents = await _read(_kRecents);
    bookmarks = await _read(_kBookmarks);
    _loaded = true;
    notifyListeners();
  }

  Future<List<DappSite>> _read(String key) async {
    final raw = await _storage.read(key: key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw);
      if (list is List) {
        return list
            .whereType<Map>()
            .map((m) => DappSite.fromJson(m.cast<String, dynamic>()))
            .where((s) => s.url.isNotEmpty)
            .toList();
      }
    } catch (_) {/* ignore corrupt list */}
    return [];
  }

  Future<void> _write(String key, List<DappSite> list) => _storage.write(
        key: key,
        value: jsonEncode(list.map((s) => s.toJson()).toList()),
      );

  Future<void> addRecent(String url, String title) async {
    final norm = _norm(url);
    if (norm.isEmpty) return;
    recents.removeWhere((s) => _norm(s.url) == norm);
    recents.insert(
        0,
        DappSite(
          url: url,
          title: title.trim().isEmpty ? (Uri.tryParse(url)?.host ?? url) : title.trim(),
          visitedAt: DateTime.now().millisecondsSinceEpoch,
        ));
    if (recents.length > _maxRecents) {
      recents = recents.sublist(0, _maxRecents);
    }
    await _write(_kRecents, recents);
    notifyListeners();
  }

  bool isBookmarked(String url) {
    final norm = _norm(url);
    return bookmarks.any((s) => _norm(s.url) == norm);
  }

  Future<void> toggleBookmark(String url, String title) async {
    final norm = _norm(url);
    if (isBookmarked(url)) {
      bookmarks.removeWhere((s) => _norm(s.url) == norm);
    } else {
      bookmarks.insert(
          0,
          DappSite(
            url: url,
            title: title.trim().isEmpty ? (Uri.tryParse(url)?.host ?? url) : title.trim(),
            visitedAt: DateTime.now().millisecondsSinceEpoch,
          ));
    }
    await _write(_kBookmarks, bookmarks);
    notifyListeners();
  }

  Future<void> removeRecent(String url) async {
    final norm = _norm(url);
    recents.removeWhere((s) => _norm(s.url) == norm);
    await _write(_kRecents, recents);
    notifyListeners();
  }

  Future<void> clearRecents() async {
    recents = [];
    await _storage.delete(key: _kRecents);
    notifyListeners();
  }

  static String _norm(String url) {
    var u = url.trim().toLowerCase();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }
}
