import 'package:flutter/material.dart';

class TodosClientesTab extends StatelessWidget {
  const TodosClientesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("Todos os Clientes", style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text("Visualize todos os clientes cadastrados pelos consultores",
                style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 12),
            const TextField(
              decoration: InputDecoration(
                hintText: "Buscar por nome do estabelecimento, endereço ou cliente...",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text("Nenhum cliente cadastrado ainda."),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
