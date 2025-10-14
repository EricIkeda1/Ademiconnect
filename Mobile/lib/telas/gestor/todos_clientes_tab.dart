import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/cliente.dart';
import '../../services/consultor_service.dart';

class TodosClientesTab extends StatefulWidget {
  const TodosClientesTab({super.key});

  @override
  State<TodosClientesTab> createState() => _TodosClientesTabState();
}

class _TodosClientesTabState extends State<TodosClientesTab> {
  final _consultorService = ConsultorService();
  bool _isLoading = true;
  List<Cliente> _clientes = [];
  Map<String, String> _consultoresDoGestor = {}; 

  @override
  void initState() {
    super.initState();
    _loadClientes();
  }

  Future<void> _loadClientes() async {
    final gestorUid = FirebaseAuth.instance.currentUser?.uid;
    if (gestorUid == null) return;

    setState(() => _isLoading = true);

    final consultores = await _consultorService.getConsultoresByGestor(gestorUid);
    _consultoresDoGestor.clear();
    for (var c in consultores) {
      _consultoresDoGestor[c.uid] = c.nome;
    }

    if (_consultoresDoGestor.isNotEmpty) {
      final snapshot = await FirebaseFirestore.instance
          .collection('clientes')
          .where('consultorUid', whereIn: _consultoresDoGestor.keys.toList())
          .get();

      _clientes = snapshot.docs.map((doc) => Cliente.fromFirestore(doc)).toList();
    } else {
      _clientes = [];
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_clientes.isEmpty) return const Center(child: Text("Nenhum cliente cadastrado pelo seu time."));

    final Map<String, List<Cliente>> clientesPorConsultor = {};
    for (var c in _clientes) {
      final nome = _consultoresDoGestor[c.consultorUid] ?? 'Sem consultor';
      clientesPorConsultor.putIfAbsent(nome, () => []).add(c);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          "Clientes do Meu Time",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 28),
        ),
        const SizedBox(height: 8),
        const Text(
          "Clique no nome do consultor para ver os clientes cadastrados por ele",
          style: TextStyle(color: Colors.black54, fontSize: 15),
        ),
        const SizedBox(height: 20),
        ...clientesPorConsultor.entries.map((entry) => _buildExpansionTile(entry.key, entry.value)),
      ],
    );
  }

  Widget _buildExpansionTile(String consultor, List<Cliente> clientes) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 6,
      shadowColor: Colors.black26,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            radius: 26,
            backgroundColor: Colors.blueAccent.shade700,
            child: Text(
              _iniciais(consultor),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          title: Text(
            consultor,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: clientes.map((c) => _buildClienteTile(c)).toList(),
        ),
      ),
    );
  }

  Widget _buildClienteTile(Cliente c) {
    final bool recente = c.dataVisita.isAfter(DateTime.now().subtract(const Duration(days: 7)));

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: recente ? Colors.blue.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(c.estabelecimento, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        subtitle: Text("${c.cidade} - ${c.estado}", style: const TextStyle(color: Colors.black54, fontSize: 14)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: recente ? Colors.blue.shade100 : Colors.green.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "${c.dataVisita.day.toString().padLeft(2, '0')}/"
                "${c.dataVisita.month.toString().padLeft(2, '0')}/"
                "${c.dataVisita.year}",
                style: TextStyle(
                  color: recente ? Colors.blue.shade700 : Colors.green.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _iniciais(String nome) {
    final parts = nome.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return "??";
    final first = parts.first;
    final second = parts.length > 1 ? parts.last : "";
    return (first[0] + second[0]).toUpperCase();
  }
}
