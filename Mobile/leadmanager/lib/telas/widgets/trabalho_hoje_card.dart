import 'package:flutter/material.dart';

class TrabalhoHojeCard extends StatelessWidget {
  final String endereco;
  const TrabalhoHojeCard({super.key, this.endereco = "Rua das Flores, Centro - Comércio Local"});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: Icon(Icons.place, color: cs.primary),
        title: const Text('Trabalho para hoje'),
        subtitle: Text('Rua designada: $endereco'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: cs.primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text('Hoje', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
