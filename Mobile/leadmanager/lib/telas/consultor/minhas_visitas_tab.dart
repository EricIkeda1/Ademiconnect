import 'package:flutter/material.dart';

class MinhasVisitasTab extends StatelessWidget {
  const MinhasVisitasTab({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget section(String title, Widget child) {
      return Card.outlined(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            child,
          ]),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        section(
          'Ruas de Trabalho',
          Column(
            children: [
              ListTile(
                leading: Icon(Icons.location_on, color: cs.primary),
                title: const Text('HOJE - Sua área de trabalho'),
                subtitle: const Text('Rua das Flores, Centro - Comércio Local'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text('PRIORIDADE'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        section(
          'Cronograma de Visitas',
          Column(
            children: [
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Rua das Flores, Centro - Comércio Local'),
                subtitle: const Text('segunda-feira, 15 de setembro de 2025'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text('HOJE', style: TextStyle(color: Colors.white)),
                ),
              ),
              const Divider(height: 0),
              ListTile(
                leading: const Icon(Icons.event_note_outlined),
                title: const Text('Avenida Principal, Bairro Comercial - Shopping e Lojas'),
                subtitle: const Text('terça-feira, 16 de setembro de 2025'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text('AGENDADO', style: TextStyle(color: Colors.green)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
