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
    const branco = Color(0xFFFFFFFF);
    const preto09 = Color(0xFF231F20);
    const cinzaClaro = Color(0xFFDCDDDE);
    const vermelhoClaro = Color(0xFFEA3124);

    return Container(
      color: branco, // igual aos cards
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          // 3 total
          Container(
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cinzaClaro),
              color: branco,
            ),
            padding: const EdgeInsets.all(2),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: vermelhoClaro, borderRadius: BorderRadius.circular(8)),
              child: Text('$total total', style: const TextStyle(color: branco, fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ),
          const SizedBox(width: 8),
          // Avisos
          Container(
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cinzaClaro),
              color: branco,
            ),
            child: TextButton.icon(
              onPressed: onAvisos,
              icon: const Icon(Icons.notifications_none, size: 16, color: preto09),
              label: const Text('Avisos', style: TextStyle(color: preto09, fontSize: 12)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Text('Meus Leads', style: TextStyle(color: preto09, fontSize: 12.5, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
