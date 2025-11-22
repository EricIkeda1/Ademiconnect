import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';             
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cliente.dart';


class ClienteService {
  ClienteService._internal();

  static final ClienteService _singleton = ClienteService._internal();

  factory ClienteService() => _singleton;

  static ClienteService get instance => _singleton;

  final SupabaseClient _client = Supabase.instance.client;
  final List<Cliente> _clientes = [];
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  static const String _cacheKey = 'clientes_cache';
  static const String _pendingKey = 'pending_ops';

  List<Cliente> get clientes => List.unmodifiable(_clientes);

  ConnectivityResult? _lastState;
  bool _initialized = false;
  bool _syncRunning = false;

  final StreamController<int> _syncedCountController =
      StreamController<int>.broadcast();

  Stream<int> get onSyncedCount => _syncedCountController.stream;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _loadFromCache();

    if (await _hasRealInternet() && _client.auth.currentSession != null) {
      unawaited(_syncWithRetry());
    }

    await _connectivitySub?.cancel();
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen((results) async {
      final isNone = results.contains(ConnectivityResult.none);
      final current = isNone
          ? ConnectivityResult.none
          : (results.contains(ConnectivityResult.wifi)
              ? ConnectivityResult.wifi
              : (results.contains(ConnectivityResult.mobile)
                  ? ConnectivityResult.mobile
                  : ConnectivityResult.other));

      final wasOffline =
          _lastState == null || _lastState == ConnectivityResult.none;
      _lastState = current;

      final becameOnline = wasOffline && current != ConnectivityResult.none;
      if (!becameOnline) return;

      await Future.delayed(const Duration(milliseconds: 700));

      if (!await _hasRealInternet()) return;

      final session = _client.auth.currentSession;
      if (session == null || session.user == null) return;

      unawaited(_syncWithRetry());
    });
  }

  void dispose() {
    _connectivitySub?.cancel();
    _syncedCountController.close();
  }

  Future<bool> _hasRealInternet() async {
    final results = await Connectivity().checkConnectivity();
    if (results.contains(ConnectivityResult.none)) return false;
    try {
      final lookup = await InternetAddress.lookup('one.one.one.one')
          .timeout(const Duration(seconds: 3));
      return lookup.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _loadFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return;
    try {
      final List list = jsonDecode(raw);
      _clientes
        ..clear()
        ..addAll(
          list.map(
            (e) => Cliente.fromJson(e as Map<String, dynamic>),
          ),
        );
    } catch (_) {}
  }

  Future<void> _saveToCache() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(_clientes.map((c) => c.toJson()).toList());
    await prefs.setString(_cacheKey, data);
  }

  Future<void> _enqueue(String tipo, Cliente c) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingKey);
    final List ops = raw != null ? jsonDecode(raw) : [];
    ops.add({'tipo': tipo, 'cliente': c.toJson()});
    await prefs.setString(_pendingKey, jsonEncode(ops));
  }

  /// Fluxo padrão ONLINE: tenta enviar para o Supabase; se der erro, enfileira.
  Future<bool> saveCliente(Cliente c) async {
    final uid = _client.auth.currentSession?.user.id;
    final payload =
        (uid != null && uid.isNotEmpty) ? c.copyWith(consultorUid: uid) : c;

    _clientes.removeWhere((x) => x.id == payload.id);
    _clientes.add(payload);
    await _saveToCache();

    try {
      await _client
          .from('clientes')
          .upsert(
            payload.toSupabaseMap(),
            onConflict: 'id',         
            ignoreDuplicates: false,
          )
          .select();               
      return true;                   
    } on PostgrestException catch (e) {
      debugPrint('saveCliente PostgrestException: ${e.message}');
      await _enqueue('save', payload);
      return false;
    } catch (e) {
      debugPrint('saveCliente erro genérico: $e');
      await _enqueue('save', payload);
      return false;
    }
  }

  Future<void> removeCliente(String id) async {
    _clientes.removeWhere((x) => x.id == id);
    await _saveToCache();
    try {
      await _client.from('clientes').delete().eq('id', id);
    } catch (_) {
      final stub = Cliente(
        id: id,
        nomeCliente: '',
        telefone: '',
        estabelecimento: '',
        estado: '',
        cidade: '',
        endereco: '',
        logradouro: '',
        numero: null,
        dataVisita: DateTime.now(),
        consultorUid: '',
      );
      await _enqueue('remove', stub);
    }
  }

  Future<void> _syncWithRetry() async {
    if (_syncRunning) return;
    _syncRunning = true;
    try {
      const attempts = 3;
      var delay = const Duration(milliseconds: 400);
      for (var i = 0; i < attempts; i++) {
        final ok = await _trySyncOnce();
        if (ok) return;
        await Future.delayed(delay);
        delay *= 2;
      }
    } finally {
      _syncRunning = false;
    }
  }

  Future<bool> _trySyncOnce() async {
    final session = _client.auth.currentSession;
    if (session == null || session.user == null) return false;
    if (!await _hasRealInternet()) return false;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingKey);
    if (raw == null) return true;

    final List ops;
    try {
      ops = jsonDecode(raw);
    } catch (_) {
      await prefs.remove(_pendingKey);
      return true;
    }
    if (ops.isEmpty) return true;

    final List remain = [];
    int enviadosAgora = 0;

    for (final op in ops) {
      try {
        final tipo = op['tipo'] as String;
        final c = Cliente.fromJson(op['cliente'] as Map<String, dynamic>);
        final uid = _client.auth.currentSession?.user.id;
        final payload =
            (uid != null && uid.isNotEmpty) ? c.copyWith(consultorUid: uid) : c;

        if (tipo == 'save') {
          await _client
              .from('clientes')
              .upsert(
                payload.toSupabaseMap(),
                onConflict: 'id',
                ignoreDuplicates: false,
              )
              .select();
          enviadosAgora++;
        } else if (tipo == 'remove') {
          await _client.from('clientes').delete().eq('id', payload.id);
          enviadosAgora++;
        }
      } catch (_) {
        remain.add(op);
      }
    }

    if (remain.isEmpty) {
      await prefs.remove(_pendingKey);
    } else {
      await prefs.setString(_pendingKey, jsonEncode(remain));
    }

    if (enviadosAgora > 0) {
      _syncedCountController.add(enviadosAgora);
    }

    return remain.isEmpty;
  }

  Future<void> syncPendingOperations() => _syncWithRetry();

  /// Fluxo OFFLINE explícito: salva somente em cache + fila, sem tentar enviar agora.
  Future<bool> saveClienteOffline(Cliente c) async {
    final uid = _client.auth.currentSession?.user.id;
    final payload =
        (uid != null && uid.isNotEmpty) ? c.copyWith(consultorUid: uid) : c;

    _clientes.removeWhere((x) => x.id == payload.id);
    _clientes.add(payload);
    await _saveToCache();

    await _enqueue('save', payload);

    return true;
  }
}
