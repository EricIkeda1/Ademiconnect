import '../../models/cliente.dart';
import 'package:flutter/material.dart';
import 'home_consultor.dart';

class MeusClientesTab extends StatefulWidget {
  final List<Cliente> clientes;
  const MeusClientesTab({super.key, required this.clientes});

  @override
  State<MeusClientesTab> createState() => _MeusClientesTabState();
}

class _MeusClientesTabState extends State<MeusClientesTab> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final filtrados = widget.clientes.where((c) {
      final hay = '${c.estabelecimento} ${c.endereco} ${c.nomeCliente ?? ''}'.toLowerCase();
      return hay.contains(_q.toLowerCase());
    }).toList();

    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Meus Clientes', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Buscar por nome de estabelecimento, endereço ou cliente...',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _q = v),
          ),
          const SizedBox(height: 12),
          if (filtrados.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('Nenhum cliente cadastrado ainda.'),
              ),
            )
          else
            ...filtrados.map((c) {
              final data = '${c.dataVisita.day.toString().padLeft(2, '0')}/${c.dataVisita.month.toString().padLeft(2, '0')}/${c.dataVisita.year}';
              return Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.store_outlined),
                    title: Text(c.estabelecimento),
                    subtitle: Text('${c.endereco}\nData: $data'),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                  ),
                  const Divider(height: 0),
                ],
              );
            }),
        ]),
      ),
    );
  }
}
