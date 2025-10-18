import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cliente.dart';
import 'notification_service.dart';

class ClienteService {
  final SupabaseClient _client = Supabase.instance.client;
  List<Cliente> _clientes = [];
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  static const String _cacheKey = 'clientes_cache';
  static const String _pendingKey = 'pending_ops';

  List<Cliente> get clientes => _clientes;
  int get totalClientes => _clientes.length;

  int get totalVisitasHoje {
    final hoje = DateTime.now();
    return _clientes
        .where((c) =>
            c.dataVisita.year == hoje.year &&
            c.dataVisita.month == hoje.month &&
            c.dataVisita.day == hoje.day)
        .length;
  }

  Future<void> initialize() async {
    await loadClientes();
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .map((results) => results.isNotEmpty ? results.first : ConnectivityResult.none)
        .listen((result) async {
      if (result != ConnectivityResult.none) {
        await syncPendingOperations();
      }
    });
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }

  Future<void> loadClientes() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString(_cacheKey);

    if (cachedData != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(cachedData);
        final List<Cliente> carregados = jsonList.map((e) => Cliente.fromJson(e)).toList();

        final user = _client.auth.currentSession?.user?.id;
        if (user != null) {
          _clientes = carregados.map((cliente) {
            return Cliente(
              id: cliente.id,
              estabelecimento: cliente.estabelecimento,
              estado: cliente.estado,
              cidade: cliente.cidade,
              endereco: cliente.endereco,
              bairro: cliente.bairro,
              cep: cliente.cep,
              dataVisita: cliente.dataVisita,
              nomeCliente: cliente.nomeCliente,
              telefone: cliente.telefone,
              observacoes: cliente.observacoes,
              consultorResponsavel: cliente.consultorResponsavel,
              consultorUid: cliente.consultorUid.isNotEmpty ? cliente.consultorUid : user,
            );
          }).toList();
        } else {
          _clientes = carregados;
        }
      } catch (e) {
        print('❌ Erro ao carregar cache: $e');
      }
    }
  }

  Future<bool> _hasRealInternet() async {
    try {
      final result = await Connectivity().checkConnectivity();
      if (result == ConnectivityResult.none) {
        print('❌ Sem conexão de rede');
        return false;
      }

      print('📡 Testando conexão com Supabase...');

      final response = await _client
          .from('clientes')
          .select('id')
          .limit(1)
          .timeout(const Duration(seconds: 10));

      final temConexao = response is List;
      print('✅ Conexão com Supabase: ${temConexao ? "OK" : "Falhou"}');
      return temConexao;
    } catch (e, st) {
      print('❌ ERRO REAL ao testar internet: $e');
      print('📝 Stack: $st');
      return false;
    }
  }

  Future<void> saveCliente(Cliente cliente) async {
    final user = _client.auth.currentSession?.user?.id;
    if (user == null) {
      print('⚠️ Usuário não autenticado.');
      return;
    }

    final clienteComUid = Cliente(
      id: cliente.id,
      estabelecimento: cliente.estabelecimento,
      estado: cliente.estado,
      cidade: cliente.cidade,
      endereco: cliente.endereco,
      bairro: cliente.bairro,
      cep: cliente.cep,
      dataVisita: cliente.dataVisita,
      nomeCliente: cliente.nomeCliente,
      telefone: cliente.telefone,
      observacoes: cliente.observacoes,
      consultorResponsavel: cliente.consultorResponsavel,
      consultorUid: user,
    );

    _clientes.removeWhere((c) => c.id == cliente.id);
    _clientes.add(clienteComUid);
    await _saveToCache();

    final isConnected = await _hasRealInternet();
    print('🌐 Online? $isConnected');

    try {
      if (isConnected) {
        final data = _clienteToMap(clienteComUid);
        print('📊 Dados: $data');
        await _client.from('clientes').upsert(data, onConflict: 'id');
        print('✅ Cliente salvo no Supabase: ${clienteComUid.estabelecimento}');
        await NotificationService.showSuccessNotification();
      } else {
        await _savePendingOperation('save', clienteComUid);
        await NotificationService.showOfflineNotification();
      }
    } catch (e, st) {
      print('❌ Falha ao salvar no Supabase: $e');
      print('📜 Stack: $st');
      await _savePendingOperation('save', clienteComUid);
      await NotificationService.showOfflineNotification();
    }
  }

  Future<void> removeCliente(String id) async {
    final user = _client.auth.currentSession?.user?.id;
    if (user == null) {
      print('⚠️ Usuário não autenticado.');
      return;
    }

    _clientes.removeWhere((c) => c.id == id);
    await _saveToCache();

    final isConnected = await _hasRealInternet();
    print('🌐 Remover - Online? $isConnected');

    try {
      if (isConnected) {
        await _client.from('clientes').delete().eq('id', id);
        print('✅ Cliente removido do Supabase: $id');
      } else {
        await _savePendingOperation('remove', Cliente(
          id: id,
          estabelecimento: '',
          estado: '',
          cidade: '',
          endereco: '',
          bairro: null,
          cep: null,
          dataVisita: DateTime.now(),
          consultorUid: user,
        ));
      }
    } catch (e, st) {
      print('❌ Falha ao remover do Supabase: $e\n$st');
      await _savePendingOperation('remove', Cliente(
        id: id,
        estabelecimento: '',
        estado: '',
        cidade: '',
        endereco: '',
        bairro: null,
        cep: null,
        dataVisita: DateTime.now(),
        consultorUid: user,
      ));
    }
  }

  Future<void> syncPendingOperations() async {
    final isConnected = await _hasRealInternet();
    if (!isConnected) {
      print('📡 Sem internet para sincronizar');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final pendingData = prefs.getString(_pendingKey);
    if (pendingData == null) return;

    final List<dynamic> pendingOps = jsonDecode(pendingData);
    print('📤 Sincronizando ${pendingOps.length} operações pendentes...');

    for (final op in pendingOps) {
      final tipo = op['tipo'] as String;
      final cliente = Cliente.fromJson(op['cliente']);

      try {
        if (tipo == 'save') {
          final data = _clienteToMap(cliente);
          await _client.from('clientes').upsert(data, onConflict: 'id');
          print('✅ Sync: cliente salvo -> ${cliente.estabelecimento}');
        } else if (tipo == 'remove') {
          await _client.from('clientes').delete().eq('id', cliente.id);
          print('✅ Sync: cliente removido -> ${cliente.id}');
        }
      } catch (e, st) {
        print('❌ Falha ao sincronizar com Supabase: $e\n$st');
        return;
      }
    }

    await prefs.remove(_pendingKey);
    print('✅ Fila de operações pendentes limpa!');
  }

  Future<void> _saveToCache() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = jsonEncode(_clientes.map((c) => c.toJson()).toList());
    await prefs.setString(_cacheKey, jsonData);
  }

  Future<void> _savePendingOperation(String tipo, Cliente cliente) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_pendingKey);
    final List<dynamic> ops = data != null ? jsonDecode(data) : [];

    ops.add({'tipo': tipo, 'cliente': cliente.toJson()});
    await prefs.setString(_pendingKey, jsonEncode(ops));
    print('📁 Operação $tipo salva na fila offline');
  }

  Map<String, dynamic> _clienteToMap(Cliente cliente) {
    return {
      'id': cliente.id,
      'nome': cliente.nomeCliente,
      'telefone': cliente.telefone,
      'estabelecimento': cliente.estabelecimento,
      'estado': cliente.estado,
      'cidade': cliente.cidade,
      'endereco': cliente.endereco,
      'bairro': cliente.bairro,
      'cep': cliente.cep,
      'data_visita': cliente.dataVisita.toIso8601String(),
      'observacoes': cliente.observacoes,
      'consultor_uid_t': cliente.consultorUid,
      'responsavel': cliente.consultorResponsavel,
    };
  }
}
