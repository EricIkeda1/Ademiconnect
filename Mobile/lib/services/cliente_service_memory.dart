import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cliente.dart';

class ClienteServiceHybrid {
  static final ClienteServiceHybrid _instance = ClienteServiceHybrid._internal();
  factory ClienteServiceHybrid() => _instance;
  ClienteServiceHybrid._internal();

  final SupabaseClient _client = Supabase.instance.client;
  List<Cliente> _clientes = [];

  static const String _cacheKey = 'clientes_cache';
  static const String _pendingKey = 'pending_ops';

  List<Cliente> get clientes => List.unmodifiable(_clientes);
  int get totalClientes => _clientes.length;

  int get totalVisitasHoje {
    final hoje = DateTime.now();
    return _clientes.where((c) =>
        c.dataVisita.year == hoje.year &&
        c.dataVisita.month == hoje.month &&
        c.dataVisita.day == hoje.day
    ).length;
  }

  Future<void> loadClientes() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString(_cacheKey);

    if (cachedData != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(cachedData);
        _clientes = jsonList.map((e) => Cliente.fromJson(e)).toList();
        if (kDebugMode) print('✅ Cache carregado: ${_clientes.length} clientes');
      } catch (e) {
        if (kDebugMode) print('❌ Erro ao ler cache: $e');
      }
    }

    if (await _isOnline()) {
      if (kDebugMode) print('📡 Online: sincronizando com Supabase');
      try {
        final user = _client.auth.currentSession?.user?.id;
        if (user == null) {
          if (kDebugMode) print('❌ Usuário não autenticado');
          return;
        }

        final response = await _client
            .from('clientes')
            .select('*')
            .eq('consultor_uid_t', user)
            .order('data_visita', ascending: true);

        if (response is List && response.isNotEmpty) {
          _clientes = response
              .map((row) => Cliente.fromMap(row as Map<String, dynamic>))
              .toList();
          await _saveToCache();
          if (kDebugMode) print('✅ Clientes do Supabase carregados');
        } else {
          if (kDebugMode) print('🟨 Nenhum cliente no Supabase');
        }
      } catch (e, st) {
        if (kDebugMode) {
          print('❌ Falha ao carregar do Supabase: $e');
          print('❌ Stack: $st');
        }
      }
    } else {
      if (kDebugMode) print('💤 Offline: usando cache local');
    }
  }

  Future<void> saveCliente(Cliente cliente) async {
    final user = _client.auth.currentSession?.user?.id;
    if (user == null) {
      if (kDebugMode) print('❌ ERRO: Usuário não autenticado.');
      return;
    }

    final clienteComUid = Cliente(
      id: cliente.id,
      nomeCliente: cliente.nomeCliente,
      telefone: cliente.telefone,
      estabelecimento: cliente.estabelecimento,
      estado: cliente.estado,
      cidade: cliente.cidade,
      endereco: cliente.endereco,
      bairro: cliente.bairro,
      cep: cliente.cep,
      dataVisita: cliente.dataVisita,
      observacoes: cliente.observacoes,
      consultorResponsavel: cliente.consultorResponsavel,
      consultorUid: user,
    );

    _clientes.removeWhere((c) => c.id == cliente.id);
    _clientes.add(clienteComUid);
    await _saveToCache();
    if (kDebugMode) print('💾 Salvo no cache local: ${clienteComUid.estabelecimento}');

    final online = await _isOnline();
    if (kDebugMode) print('🌐 Online? $online');

    if (online) {
      try {
        final data = _clienteToMap(clienteComUid);
        if (kDebugMode) print('📤 Dados enviados ao Supabase: $data');

        await _client.from('clientes').upsert(data, onConflict: 'id');
        if (kDebugMode) print('✅ SUCESSO: Salvo no Supabase');

        await _removePendingOperation('save', cliente.id);
      } catch (e, st) {
        if (kDebugMode) {
          print('❌ FALHA no Supabase: $e');
          print('❌ Stack: $st');
          print('📌 Cliente salvo offline para sincronizar depois');
        }
        await _savePendingOperation('save', clienteComUid);
      }
    } else {
      if (kDebugMode) print('💤 OFFLINE: salvo apenas local');
      await _savePendingOperation('save', clienteComUid);
    }
  }

  Future<void> removeCliente(String id) async {
    final user = _client.auth.currentSession?.user?.id;
    if (user == null) {
      if (kDebugMode) print('❌ ERRO: Usuário não autenticado.');
      return;
    }

    final cliente = Cliente(
      id: id,
      nomeCliente: 'Removido',
      telefone: '',
      estabelecimento: 'Removido',
      estado: 'SC',
      cidade: 'Florianópolis',
      endereco: 'Removido',
      bairro: null,
      cep: null,
      dataVisita: DateTime.now(),
      observacoes: null,
      consultorResponsavel: 'Sistema',
      consultorUid: user,
    );

    _clientes.removeWhere((c) => c.id == id);
    await _saveToCache();

    final online = await _isOnline();
    if (online) {
      try {
        await _client.from('clientes').delete().eq('id', id);
        if (kDebugMode) print('✅ Removido do Supabase: $id');
        await _removePendingOperation('remove', id);
      } catch (e) {
        if (kDebugMode) print('❌ Falha ao remover no Supabase: $e');
        await _savePendingOperation('remove', cliente);
      }
    } else {
      if (kDebugMode) print('📁 Remoção salva offline');
      await _savePendingOperation('remove', cliente);
    }
  }

  Future<void> syncPendingOperations() async {
    if (!await _isOnline()) {
      if (kDebugMode) print('sync: offline, não sincronizando');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final pendingData = prefs.getString(_pendingKey);
    if (pendingData == null || pendingData.isEmpty) {
      if (kDebugMode) print('sync: sem operações pendentes');
      return;
    }

    final List<dynamic> pendingOps = jsonDecode(pendingData);
    if (kDebugMode) print('📤 Sincronizando ${pendingOps.length} operações pendentes...');

    for (final op in pendingOps) {
      final tipo = op['tipo'] as String;
      final clienteMap = op['cliente'] as Map<String, dynamic>;
      final cliente = Cliente.fromJson(clienteMap);

      try {
        if (tipo == 'save') {
          final data = _clienteToMap(cliente);
          await _client.from('clientes').upsert(data, onConflict: 'id');
          if (kDebugMode) print('✅ Sync: salvo ${cliente.estabelecimento}');
        } else if (tipo == 'remove') {
          await _client.from('clientes').delete().eq('id', cliente.id);
          if (kDebugMode) print('✅ Sync: removido ${cliente.id}');
        }
        await _removePendingOperation(tipo, cliente.id);
      } catch (e) {
        if (kDebugMode) print('❌ Falha ao sincronizar $tipo: $e');
        break;
      }
    }

    if (kDebugMode) print('✅ Sincronização concluída!');
  }

  Future<void> _saveToCache() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = jsonEncode(_clientes.map((c) => c.toJson()).toList());
    await prefs.setString(_cacheKey, jsonData);
  }

  Future<void> _savePendingOperation(String tipo, Cliente cliente) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_pendingKey);
    List<dynamic> ops = data != null ? jsonDecode(data) : [];

    ops.add({'tipo': tipo, 'cliente': cliente.toJson()});
    await prefs.setString(_pendingKey, jsonEncode(ops));
    if (kDebugMode) print('📌 Operação "$tipo" salva offline: ${cliente.estabelecimento}');
  }

  Future<void> _removePendingOperation(String tipo, String clienteId) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_pendingKey);
    if (data == null) return;
    List<dynamic> ops = jsonDecode(data);
    ops.removeWhere((op) => 
      op['tipo'] == tipo && 
      op['cliente']['id'] == clienteId
    );
    await prefs.setString(_pendingKey, jsonEncode(ops));
  }

  Future<bool> _isOnline() async {
    try {
      final result = await Connectivity().checkConnectivity();
      if (result == ConnectivityResult.none) return false;

      if (!kIsWeb) return true;

      final response = await _client
          .from('clientes')
          .select('id')
          .limit(1);

      return response is List && response.isNotEmpty;
    } catch (e) {
      if (kDebugMode) print('❌ Erro em _isOnline: $e');
      return false;
    }
  }

  Map<String, dynamic> _clienteToMap(Cliente cliente) {
    return {
      'id': cliente.id,
      'nome_cliente': cliente.nomeCliente,
      'telefone': cliente.telefone,
      'estabelecimento': cliente.estabelecimento,
      'estado': cliente.estado,
      'cidade': cliente.cidade,
      'endereco': cliente.endereco,
      'bairro': cliente.bairro,
      'cep': cliente.cep,
      'data_visita': cliente.dataVisita.toIso8601String(),
      'observacoes': cliente.observacoes,
      'consultor_responsavel': cliente.consultorResponsavel,
      'consultor_uid_t': cliente.consultorUid,
    };
  }
}
