import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/cliente.dart';
import 'notification_service.dart';

class ClienteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Cliente> _clientes = [];
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

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
        .map((List<ConnectivityResult> results) =>
            results.isNotEmpty ? results.first : ConnectivityResult.none)
        .listen((ConnectivityResult result) async {
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
    final cachedData = prefs.getString('clientes_cache');
    if (cachedData != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(cachedData);
        _clientes = jsonList.map((e) => Cliente.fromJson(e)).toList();
      } catch (e) {
        print('❌ Erro ao carregar cache: $e');
      }
    }
  }

  Future<bool> _hasRealInternet() async {
    final result = await Connectivity().checkConnectivity();
    if (result == ConnectivityResult.none) return false;
    try {
      final lookup =
          await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 3));
      return lookup.isNotEmpty;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> saveCliente(Cliente cliente) async {
    final user = _auth.currentUser;
    if (user == null) {
      print('⚠️ Usuário não autenticado.');
      return;
    }

    // Garante que o UID do consultor seja salvo junto
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
      consultorUid: user.uid,
    );

    _clientes.removeWhere((c) => c.id == cliente.id);
    _clientes.add(clienteComUid);
    await _saveToCache();

    final isConnected = await _hasRealInternet();

    try {
      if (isConnected) {
        await _firestore.collection('clientes').doc(clienteComUid.id).set(clienteComUid.toJson());
        await NotificationService.showSuccessNotification();
      } else {
        await _savePendingOperation('save', clienteComUid);
        await NotificationService.showOfflineNotification();
      }
    } catch (e) {
      print('❌ Falha ao salvar cliente: $e');
      await _savePendingOperation('save', clienteComUid);
      await NotificationService.showOfflineNotification();
    }
  }

  Future<void> removeCliente(String id) async {
    final user = _auth.currentUser;
    if (user == null) {
      print('⚠️ Usuário não autenticado.');
      return;
    }

    _clientes.removeWhere((c) => c.id == id);
    await _saveToCache();

    final isConnected = await _hasRealInternet();

    try {
      if (isConnected) {
        await _firestore.collection('clientes').doc(id).delete();
      } else {
        await _savePendingOperation(
            'remove',
            Cliente(
              id: id,
              estabelecimento: '',
              estado: '',
              cidade: '',
              endereco: '',
              bairro: null,
              cep: null,
              dataVisita: DateTime.now(),
              consultorUid: user.uid,
            ));
      }
    } catch (e) {
      print('❌ Falha ao remover cliente: $e');
      await _savePendingOperation(
          'remove',
          Cliente(
            id: id,
            estabelecimento: '',
            estado: '',
            cidade: '',
            endereco: '',
            bairro: null,
            cep: null,
            dataVisita: DateTime.now(),
            consultorUid: user.uid,
          ));
    }
  }

  Future<void> syncPendingOperations() async {
    final isConnected = await _hasRealInternet();
    if (!isConnected) return;

    final prefs = await SharedPreferences.getInstance();
    final pendingData = prefs.getString('pending_ops');
    if (pendingData == null) return;

    final List<dynamic> pendingOps = jsonDecode(pendingData);
    print('📤 Sincronizando ${pendingOps.length} operações pendentes...');

    for (var op in pendingOps) {
      final tipo = op['tipo'] as String;
      final cliente = Cliente.fromJson(op['cliente']);
      try {
        if (tipo == 'save') {
          await _firestore.collection('clientes').doc(cliente.id).set(cliente.toJson());
          print('✅ Enviado para Firebase: ${cliente.estabelecimento}');
        } else if (tipo == 'remove') {
          await _firestore.collection('clientes').doc(cliente.id).delete();
          print('✅ Removido no Firebase: ${cliente.id}');
        }
      } catch (e) {
        print('❌ Falha ao sincronizar: $e');
        return;
      }
    }

    await prefs.remove('pending_ops');
    print('✅ Fila de operações pendentes limpa!');
  }

  Future<void> _saveToCache() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = jsonEncode(_clientes.map((c) => c.toJson()).toList());
    await prefs.setString('clientes_cache', jsonData);
  }

  Future<void> _savePendingOperation(String tipo, Cliente cliente) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('pending_ops');
    final List<dynamic> ops = data != null ? jsonDecode(data) : [];
    ops.add({'tipo': tipo, 'cliente': cliente.toJson()});
    await prefs.setString('pending_ops', jsonEncode(ops));
    print('📁 Operação $tipo salva na fila offline');
  }
}
