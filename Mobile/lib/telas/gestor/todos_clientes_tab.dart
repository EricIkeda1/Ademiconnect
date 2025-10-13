import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/cliente.dart';
import '../../services/cliente_service.dart';
import '../../services/consultor_service.dart';

class TodosClientesTab extends StatefulWidget {
  const TodosClientesTab({super.key});

  @override
  State<TodosClientesTab> createState() => _TodosClientesTabState();
}

class _TodosClientesTabState extends State<TodosClientesTab> {
  final _clienteService = ClienteService();
  final _consultorService = ConsultorService();
  bool _isLoading = true;
  List<Cliente> _clientes = [];
  Map<String, String> _consultoresDoGestor = {}; // uid -> nome

  @override
  void initState() {
    super.initState();
    _loadClientes();
  }

  Future<void> _loadClientes() async {
    final gestorUid = FirebaseAuth.instance.currentUser?.uid;
    if (gestorUid == null) return;

    _isLoading = true;
    setState(() {});

    final consultores = await _consultorService.getConsultoresByGestor(gestorUid);
    _consultoresDoGestor.clear();
    for (var c in consultores) _consultoresDoGestor[c.uid] = c.nome;

    await _clienteService.loadClientes();
    _clientes = _clienteService.clientes
        .where((c) => _consultoresDoGestor.containsKey(c.consultorUid))
        .toList();

    _isLoading = false;
    setState(() {});
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
        const Text("Clientes do Meu Time", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        const SizedBox(height: 4),
        const Text("Visualize apenas os clientes cadastrados pelos consultores do seu time",
            style: TextStyle(color: Colors.black54)),
        const SizedBox(height: 12),
        ...clientesPorConsultor.entries.map((entry) {
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Divider(),
                  ...entry.value.map((c) => ListTile(
                        title: Text(c.estabelecimento),
                        subtitle: Text("${c.cidade} - ${c.estado}"),
                        trailing: Text(
                          "${c.dataVisita.day.toString().padLeft(2, '0')}/"
                          "${c.dataVisita.month.toString().padLeft(2, '0')}/"
                          "${c.dataVisita.year}",
                          style: const TextStyle(color: Colors.black54, fontSize: 12),
                        ),
                      )),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
