import 'package:flutter/material.dart';

class VisitaTile extends StatelessWidget {
  final String titulo;
  final String consultor;
  final String data;

  const VisitaTile({
    super.key,
    required this.titulo,
    required this.consultor,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: const Color(0xFFF7F7F7),
      title: Text(titulo),
      subtitle: Text(consultor),
      trailing: Text(data, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}
