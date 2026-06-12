import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

class OctraCoreSnapshot {
  final Map<String, dynamic> data;
  const OctraCoreSnapshot(this.data);
}

abstract class OctraCoreBridge {
  bool get isAvailable;
  String? get unavailableReason;

  Future<String> version();
  Future<Map<String, dynamic>> health();
  Future<Map<String, dynamic>> publicSnapshot(String address);
  Future<List<dynamic>> historySnapshot(
    String address, {
    int limit,
    int offset,
  });
  Future<Map<String, dynamic>> txDetails(String hash);
  Future<Map<String, dynamic>> executePrivacyOperation(Map<String, dynamic> payload);
  Future<Map<String, dynamic>> recommendFee(String operationType, int recipientCount);
  Future<List<dynamic>> scanStealthInbox(String address);
  Future<Map<String, dynamic>> importToken(String contractAddress);
}

typedef _StringFnNative = Pointer<Utf8> Function();
typedef _StringFnDart = Pointer<Utf8> Function();

typedef _OneStringFnNative = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _OneStringFnDart = Pointer<Utf8> Function(Pointer<Utf8>);

typedef _HistoryFnNative = Pointer<Utf8> Function(Pointer<Utf8>, Int32, Int32);
typedef _HistoryFnDart = Pointer<Utf8> Function(Pointer<Utf8>, int, int);

typedef _FreeStringNative = Void Function(Pointer<Utf8>);
typedef _FreeStringDart = void Function(Pointer<Utf8>);

class FfiOctraCoreBridge implements OctraCoreBridge {
  static String? _lastLoadError;

  final DynamicLibrary _lib;
  late final _StringFnDart _version;
  late final _StringFnDart _health;
  late final _OneStringFnDart _publicSnapshot;
  late final _HistoryFnDart _historySnapshot;
  late final _OneStringFnDart _txDetails;
  late final _OneStringFnDart _executePrivacyOperation;
  late final _OneStringFnDart _recommendFee;
  late final _OneStringFnDart _scanStealthInbox;
  late final _OneStringFnDart _importToken;
  late final _FreeStringDart _freeString;

  FfiOctraCoreBridge._(this._lib) {
    _version = _lib.lookupFunction<_StringFnNative, _StringFnDart>('octra_core_version');
    _health = _lib.lookupFunction<_StringFnNative, _StringFnDart>('octra_core_health');
    _publicSnapshot = _lib.lookupFunction<_OneStringFnNative, _OneStringFnDart>(
      'octra_core_public_snapshot',
    );
    _historySnapshot = _lib.lookupFunction<_HistoryFnNative, _HistoryFnDart>(
      'octra_core_history_snapshot',
    );
    _txDetails = _lib.lookupFunction<_OneStringFnNative, _OneStringFnDart>(
      'octra_core_tx_details',
    );
    _executePrivacyOperation = _lib.lookupFunction<_OneStringFnNative, _OneStringFnDart>(
      'octra_core_execute_privacy_operation',
    );
    _recommendFee = _lib.lookupFunction<_OneStringFnNative, _OneStringFnDart>(
      'octra_core_recommend_fee',
    );
    _scanStealthInbox = _lib.lookupFunction<_OneStringFnNative, _OneStringFnDart>(
      'octra_core_scan_stealth_inbox',
    );
    _importToken = _lib.lookupFunction<_OneStringFnNative, _OneStringFnDart>(
      'octra_core_import_token',
    );
    _freeString = _lib.lookupFunction<_FreeStringNative, _FreeStringDart>(
      'octra_core_free_string',
    );
  }

  static FfiOctraCoreBridge? tryLoad() {
    try {
      _lastLoadError = null;
      final lib = _openLibrary();
      return FfiOctraCoreBridge._(lib);
    } catch (error) {
      _lastLoadError = error.toString();
      return null;
    }
  }

  static String? get lastLoadError => _lastLoadError;

  static DynamicLibrary _openLibrary() {
    if (Platform.isAndroid) {
      _tryPreload('libc++_shared.so');
      _tryPreload('libcrypto.so');
      return DynamicLibrary.open('liboctra_core.so');
    }
    if (Platform.isIOS) {
      return DynamicLibrary.process();
    }
    if (Platform.isMacOS) {
      // App bundles ship the dylib in Contents/Frameworks; fall back to the
      // process image for statically linked builds.
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      return _tryOpenFirst([
            '$exeDir/../Frameworks/liboctra_core.dylib',
            '$exeDir/liboctra_core.dylib',
            'liboctra_core.dylib',
          ]) ??
          DynamicLibrary.process();
    }
    if (Platform.isLinux) {
      // Flutter bundles place shared libraries in <bundle>/lib next to the
      // executable; prefer that before the default search path.
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      return _tryOpenFirst([
            '$exeDir/lib/liboctra_core.so',
            '$exeDir/liboctra_core.so',
          ]) ??
          DynamicLibrary.open('liboctra_core.so');
    }
    if (Platform.isWindows) {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      return _tryOpenFirst(['$exeDir\\octra_core.dll']) ??
          DynamicLibrary.open('octra_core.dll');
    }
    throw UnsupportedError('Unsupported platform for Octra native core');
  }

  static DynamicLibrary? _tryOpenFirst(List<String> candidates) {
    for (final path in candidates) {
      try {
        return DynamicLibrary.open(path);
      } catch (_) {
        // Fall through to the next candidate.
      }
    }
    return null;
  }

  static void _tryPreload(String name) {
    try {
      DynamicLibrary.open(name);
    } catch (_) {
      // The final liboctra_core open keeps the actionable linker error.
    }
  }

  @override
  bool get isAvailable => true;

  @override
  String? get unavailableReason => null;

  @override
  Future<String> version() async {
    final data = _callNoArg(_version);
    return (data['version'] ?? '').toString();
  }

  @override
  Future<Map<String, dynamic>> health() async {
    return _callNoArg(_health);
  }

  @override
  Future<Map<String, dynamic>> publicSnapshot(String address) async {
    return _callWithString(_publicSnapshot, address);
  }

  @override
  Future<List<dynamic>> historySnapshot(
    String address, {
    int limit = 20,
    int offset = 0,
  }) async {
    final addressPtr = address.toNativeUtf8();
    try {
      final resultPtr = _historySnapshot(addressPtr, limit, offset);
      final result = _readJson(resultPtr);
      return result['transactions'] is List ? result['transactions'] as List : const [];
    } finally {
      calloc.free(addressPtr);
    }
  }

  @override
  Future<Map<String, dynamic>> txDetails(String hash) async {
    return _callWithString(_txDetails, hash);
  }

  @override
  Future<Map<String, dynamic>> executePrivacyOperation(Map<String, dynamic> payload) async {
    return _callWithString(_executePrivacyOperation, jsonEncode(payload));
  }

  @override
  Future<Map<String, dynamic>> recommendFee(String operationType, int recipientCount) async {
    return _callWithString(
      _recommendFee,
      jsonEncode({
        'operation_type': operationType,
        'recipient_count': recipientCount,
      }),
    );
  }

  @override
  Future<List<dynamic>> scanStealthInbox(String address) async {
    final data = _callWithString(_scanStealthInbox, address);
    return data['claims'] is List ? data['claims'] as List : const [];
  }

  @override
  Future<Map<String, dynamic>> importToken(String contractAddress) async {
    return _callWithString(_importToken, contractAddress);
  }

  Map<String, dynamic> _callNoArg(_StringFnDart fn) {
    return _readJson(fn());
  }

  Map<String, dynamic> _callWithString(_OneStringFnDart fn, String value) {
    final valuePtr = value.toNativeUtf8();
    try {
      return _readJson(fn(valuePtr));
    } finally {
      calloc.free(valuePtr);
    }
  }

  Map<String, dynamic> _readJson(Pointer<Utf8> ptr) {
    if (ptr == nullptr) {
      return {'ok': false, 'error': 'native core returned null'};
    }
    try {
      final text = ptr.toDartString();
      final decoded = jsonDecode(text);
      return decoded is Map<String, dynamic>
          ? decoded
          : {'ok': false, 'error': 'native core returned non-object json'};
    } finally {
      _freeString(ptr);
    }
  }
}

class NoopOctraCoreBridge implements OctraCoreBridge {
  final String reason;

  const NoopOctraCoreBridge([this.reason = 'Native PVAC core is not linked']);

  @override
  bool get isAvailable => false;

  @override
  String? get unavailableReason => reason;

  UnsupportedError _unavailable() {
    return UnsupportedError(reason);
  }

  @override
  Future<String> version() async {
    throw _unavailable();
  }

  @override
  Future<Map<String, dynamic>> health() async {
    throw _unavailable();
  }

  @override
  Future<Map<String, dynamic>> publicSnapshot(String address) async {
    throw _unavailable();
  }

  @override
  Future<List<dynamic>> historySnapshot(
    String address, {
    int limit = 20,
    int offset = 0,
  }) async {
    throw _unavailable();
  }

  @override
  Future<Map<String, dynamic>> txDetails(String hash) async {
    throw _unavailable();
  }

  @override
  Future<Map<String, dynamic>> executePrivacyOperation(Map<String, dynamic> payload) async {
    throw _unavailable();
  }

  @override
  Future<Map<String, dynamic>> recommendFee(String operationType, int recipientCount) async {
    throw _unavailable();
  }

  @override
  Future<List<dynamic>> scanStealthInbox(String address) async {
    throw _unavailable();
  }

  @override
  Future<Map<String, dynamic>> importToken(String contractAddress) async {
    throw _unavailable();
  }
}

OctraCoreBridge createOctraCoreBridge() {
  return FfiOctraCoreBridge.tryLoad() ??
      NoopOctraCoreBridge(
        FfiOctraCoreBridge.lastLoadError ?? 'Native PVAC core is not linked',
      );
}
