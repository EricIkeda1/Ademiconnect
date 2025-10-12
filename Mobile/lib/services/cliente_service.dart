import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/cliente.dart';

class ClienteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Cliente> _clientes = [];

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

  Future<void> loadClientes() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString('clientes_cache');

    if (cachedData != null) {
      final List<dynamic> jsonList = jsonDecode(cachedData);
      _clientes = jsonList.map((e) => Cliente.fromJson(e)).toList();
    }

    if (await _isOnline()) {
      final snapshot = await _firestore.collection('clientes').get();
      _clientes = snapshot.docs.map((doc) => Cliente.fromFirestore(doc)).toList();
      await _saveToCache();
    }
  }

  Future<void> saveCliente(Cliente cliente) async {
    _clientes.removeWhere((c) => c.id == cliente.id);
    _clientes.add(cliente);
    await _saveToCache();

    if (await _isOnline()) {
      await _firestore.collection('clientes').doc(cliente.id).set(cliente.toJson());
    } else {
      await _savePendingOperation('save', cliente);
    }
  }

  Future<void> removeCliente(String id) async {
    _clientes.removeWhere((c) => c.id == id);
    await _saveToCache();

    if (await _isOnline()) {
      await _firestore.collection('clientes').doc(id).delete();
    } else {
      await _savePendingOperation('remove', Cliente(
        id: id,
        estabelecimento: '',
        estado: '',
        cidade: '',
        endereco: '',
        dataVisita: DateTime.now(),
      ));
    }
  }

  Future<void> syncPendingOperations() async {
    if (!await _isOnline()) return;

    final prefs = await SharedPreferences.getInstance();
    final pendingData = prefs.getString('pending_ops');
    if (pendingData == null) return;

    final List<dynamic> pendingOps = jsonDecode(pendingData);
    for (var op in pendingOps) {
      final tipo = op['tipo'];
      final cliente = Cliente.fromJson(op['cliente']);

      if (tipo == 'save') {
        await _firestore.collection('clientes').doc(cliente.id).set(cliente.toJson());
      } else if (tipo == 'remove') {
        await _firestore.collection('clientes').doc(cliente.id).delete();
      }
    }

    await prefs.remove('pending_ops');
  }

  Future<void> _saveToCache() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = jsonEncode(_clientes.map((c) => c.toJson()).toList());
    await prefs.setString('clientes_cache', jsonData);
  }

  Future<void> _savePendingOperation(String tipo, Cliente cliente) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('pending_ops');
    List<dynamic> ops = data != null ? jsonDecode(data) : [];
    ops.add({'tipo': tipo, 'cliente': cliente.toJson()});
    await prefs.setString('pending_ops', jsonEncode(ops));
  }

  Future<bool> _isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }
}
