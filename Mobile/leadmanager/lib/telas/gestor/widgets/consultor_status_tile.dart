import 'package:flutter/material.dart';

class ConsultorStatusTile extends StatelessWidget {
  final String nome;
  final String status;
  final String local;

  const ConsultorStatusTile({
    super.key,
    required this.nome,
    required this.status,
    required this.local,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1FFF3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2F6E5)),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const CircleAvatar(child: Icon(Icons.person)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(nome, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.place, size: 16, color: Colors.green),
                  const SizedBox(width: 4),
                  Expanded(child: Text(local, style: const TextStyle(color: Colors.black54))),
                ],
              ),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFE9FFF0),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(status, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
