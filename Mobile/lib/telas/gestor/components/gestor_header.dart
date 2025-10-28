// lib/telas/gestor/components/gestor_header_row.dart
import 'package:flutter/material.dart';

class GestorHeaderRow extends StatelessWidget {
  final int total;
  final VoidCallback onAvisos;

  const GestorHeaderRow({
    super.key,
    required this.total,
    required this.onAvisos,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          _pill(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.shade700,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('$total total', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _pill(
            child: TextButton.icon(
              onPressed: onAvisos,
              icon: const Icon(Icons.notifications_none, color: Colors.black87, size: 18),
              label: const Text('Avisos', style: TextStyle(color: Colors.black87)),
            ),
          ),
          const Spacer(),
          const Text('Meus Leads', style: TextStyle(color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _pill({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: child,
    );
  }
}
