import 'dart:js' as js;
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

  // Keys for local storage
  static const String _cacheKey = 'clientes_cache';
  static const String _pendingKey = 'pending_ops';
  static const String _webStorageKey = 'clientes_data';

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

  // ---------------------- CARREGAR CLIENTES ----------------------
  Future<void> loadClientes() async {
    // Tenta carregar do cache local (mobile)
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString(_cacheKey);
    if (cachedData != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(cachedData);
        _clientes = jsonList.map((e) => Cliente.fromJson(e)).toList();
      } catch (e) {
        if (kDebugMode) print('Erro ao decodificar cache local: $e');
      }
    }

    // Para web (localStorage)
    if (kIsWeb) {
      try {
        final stored = _getFromLocalStorageWeb();
        if (stored != null) {
          final List<dynamic> jsonList = json.decode(stored);
          _clientes = jsonList.map((json) => Cliente.fromJson(json)).toList();
        }
      } catch (e) {
        if (kDebugMode) print('Erro web ao carregar clientes: $e');
      }
    }

    // Se online, sincroniza com Supabase
    if (await _isOnline()) {
      try {
        final response = await _client
            .from('clientes')
            .select('*')
            .order('data_visita');

        if (response is List) {
          final supabaseClientes = response
              .map((row) => Cliente.fromMap(row as Map<String, dynamic>))
              .toList();
          
          // Merge com cache local apenas se Supabase retornar dados
          if (supabaseClientes.isNotEmpty) {
            _clientes = supabaseClientes;
            // Salva cache local
            await _saveToCache();
            if (kIsWeb) _saveToLocalStorageWeb(jsonEncode(_clientes.map((c) => c.toJson()).toList()));
          }
        }
      } catch (e) {
        if (kDebugMode) print('Erro ao carregar clientes do Supabase: $e');
      }
    }
  }

  // ---------------------- SALVAR CLIENTE ----------------------
  Future<void> saveCliente(Cliente cliente) async {
    // Remove e adiciona cliente na lista local
    _clientes.removeWhere((c) => c.id == cliente.id);
    _clientes.add(cliente);

    // Salva em cache local
    await _saveToCache();
    if (kIsWeb) _saveToLocalStorageWeb(jsonEncode(_clientes.map((c) => c.toJson()).toList()));

    // Tenta salvar no Supabase se estiver online
    if (await _isOnline()) {
      try {
        final data = _clienteToMap(cliente);
        await _client
            .from('clientes')
            .upsert(data)
            .single();
        
        // Remove da fila de pendentes após sucesso
        await _removePendingOperation('save', cliente.id);
      } catch (e) {
        if (kDebugMode) print('Erro ao salvar cliente no Supabase: $e');
        await _savePendingOperation('save', cliente);
      }
    } else {
      await _savePendingOperation('save', cliente);
    }
  }

  // ---------------------- REMOVER CLIENTE ----------------------
  Future<void> removeCliente(String id) async {
    // Busca cliente para salvar na operação pendente
    final cliente = _clientes.firstWhere((c) => c.id == id, orElse: () => Cliente(
      id: id,
      estabelecimento: '',
      estado: '',
      cidade: '',
      endereco: '',
      dataVisita: DateTime.now(),
    ));
    
    // Remove da lista local
    _clientes.removeWhere((c) => c.id == id);

    // Salva cache atualizado
    await _saveToCache();
    if (kIsWeb) _saveToLocalStorageWeb(jsonEncode(_clientes.map((c) => c.toJson()).toList()));

    // Tenta remover do Supabase se estiver online
    if (await _isOnline()) {
      try {
        await _client
            .from('clientes')
            .delete()
            .eq('id', id)
            .execute();
        
        // Remove da fila de pendentes após sucesso
        await _removePendingOperation('remove', id);
      } catch (e) {
        if (kDebugMode) print('Erro ao remover cliente do Supabase: $e');
        await _savePendingOperation('remove', cliente);
      }
    } else {
      await _savePendingOperation('remove', cliente);
    }
  }

  // ---------------------- SINCRONIZAR OPERAÇÕES PENDENTES ----------------------
  Future<void> syncPendingOperations() async {
    if (!await _isOnline()) return;

    final prefs = await SharedPreferences.getInstance();
    final pendingData = prefs.getString(_pendingKey);
    if (pendingData == null) return;

    final List<dynamic> pendingOps = jsonDecode(pendingData);
    
    if (kDebugMode) {
      print('📤 Sincronizando ${pendingOps.length} operações pendentes...');
    }

    try {
      // Processa operações em batch
      for (var op in pendingOps) {
        final tipo = op['tipo'];
        final clienteMap = op['cliente'] as Map<String, dynamic>;
        final cliente = Cliente.fromJson(clienteMap);

        if (tipo == 'save') {
          try {
            final data = _clienteToMap(cliente);
            await _client
                .from('clientes')
                .upsert(data)
                .single();
            
            if (kDebugMode) {
              print('✅ Enviado para Supabase: ${cliente.estabelecimento}');
            }
          } catch (e) {
            if (kDebugMode) {
              print('❌ Falha ao sincronizar save: ${cliente.estabelecimento} - $e');
            }
            // Continua com próximas operações
            continue;
          }
        } else if (tipo == 'remove') {
          try {
            final response = await _client
                .from('clientes')
                .delete()
                .eq('id', cliente.id)
                .execute();

            if (response.error != null) {
              if (kDebugMode) {
                print('❌ Erro ao excluir: ${response.error?.message}');
              }
              continue;
            }

            if (kDebugMode) {
              print('✅ Removido do Supabase: ${cliente.id}');
            }
          } catch (e) {
            if (kDebugMode) {
              print('❌ Falha ao sincronizar remove: ${cliente.id} - $e');
            }
            // Continua com próximas operações
            continue;
          }
        }
      }

      // Limpa fila após sync bem-sucedido
      await prefs.remove(_pendingKey);
      if (kDebugMode) {
        print('✅ Fila de operações pendentes limpa!');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erro crítico ao sincronizar: $e');
      }
    }
  }

  // ---------------------- CACHE E OPERAÇÕES PENDENTES ----------------------
  Future<void> _saveToCache() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = jsonEncode(_clientes.map((c) => c.toJson()).toList());
    await prefs.setString(_cacheKey, jsonData);
  }

  Future<void> _savePendingOperation(String tipo, Cliente cliente) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_pendingKey);
    List<dynamic> ops = data != null ? jsonDecode(data) : [];
    
    // Evita duplicatas na fila
    ops.removeWhere((op) => 
      op['tipo'] == tipo && 
      op['cliente']['id'] == cliente.id
    );
    
    ops.add({'tipo': tipo, 'cliente': cliente.toJson()});
    await prefs.setString(_pendingKey, jsonEncode(ops));
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
    final result = await Connectivity().checkConnectivity();
    if (result == ConnectivityResult.none) return false;
    
    // Verificação extra para web
    if (kIsWeb) {
      try {
        final response = await _client.from('clientes').select('count()', count: CountOption.exact).execute();
        return response.error == null;
      } catch (e) {
        return false;
      }
    }
    
    return true;
  }

  // ---------------------- WEB LOCALSTORAGE ----------------------
  void _saveToLocalStorageWeb(String data) {
    try {
      js.context.callMethod('eval', ['localStorage.setItem("$_webStorageKey", "$data")']);
    } catch (e) {
      if (kDebugMode) print('Erro salvar localStorage web: $e');
    }
  }

  String? _getFromLocalStorageWeb() {
    try {
      return js.context.callMethod('eval', ['localStorage.getItem("$_webStorageKey")']) as String?;
    } catch (e) {
      if (kDebugMode) print('Erro ler localStorage web: $e');
      return null;
    }
  }

  // ---------------------- SUPABASE MAPPING ----------------------
  /// Converte Cliente para formato Supabase (snake_case)
  Map<String, dynamic> _clienteToMap(Cliente cliente) {
    return {
      'id': cliente.id,
      'estabelecimento': cliente.estabelecimento,
      'estado': cliente.estado,
      'cidade': cliente.cidade,
      'endereco': cliente.endereco,
      'bairro': cliente.bairro,
      'cep': cliente.cep,
      'data_visita': cliente.dataVisita.toIso8601String(),
      'nome_cliente': cliente.nomeCliente,
      'telefone': cliente.telefone,
      'observacoes': cliente.observacoes,
      'consultor_responsavel': cliente.consultorResponsavel,
      'consultor_uid': cliente.consultorUid,
    };
  }
}
