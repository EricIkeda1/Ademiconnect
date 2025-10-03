import 'package:flutter/material.dart';
import '../../models/cliente.dart';
import '../../services/cliente_service.dart';

class TodosClientesTab extends StatefulWidget {
  const TodosClientesTab({super.key});

  @override
  State<TodosClientesTab> createState() => _TodosClientesTabState();
}

class _TodosClientesTabState extends State<TodosClientesTab> {
  final _clienteService = ClienteService();
  bool _isLoading = true;
  List<Cliente> _clientes = [];

  @override
  void initState() {
    super.initState();
    _loadClientes();
  }

  Future<void> _loadClientes() async {
    await _clienteService.loadClientes();
    setState(() {
      _clientes = _clienteService.clientes;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_clientes.isEmpty) {
      return const Center(child: Text("Nenhum cliente cadastrado ainda."));
    }

    final Map<String, List<Cliente>> clientesPorConsultor = {};
    for (var cliente in _clientes) {
      final nome = cliente.consultorResponsavel ?? "Sem consultor definido";
      clientesPorConsultor.putIfAbsent(nome, () => []).add(cliente);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          "Todos os Clientes",
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        const SizedBox(height: 4),
        const Text(
          "Visualize todos os clientes cadastrados pelos consultores",
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 12),
        ...clientesPorConsultor.entries.map((entry) {
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                  const Divider(),
                  ...entry.value.map((c) => ListTile(
                        title: Text(c.estabelecimento),
                        subtitle: Text("${c.cidade} - ${c.estado}"),
                        trailing: Text(
                          "${c.dataVisita.day.toString().padLeft(2, '0')}/"
                          "${c.dataVisita.month.toString().padLeft(2, '0')}/"
                          "${c.dataVisita.year}",
                          style: const TextStyle(
                              color: Colors.black54, fontSize: 12),
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
