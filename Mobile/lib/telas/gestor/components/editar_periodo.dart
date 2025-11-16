import 'package:flutter/material.dart';

typedef OnPeriodoSelecionado = void Function(int meses);

class EditarPeriodoSheet extends StatelessWidget {
  final int selecionado;
  final OnPeriodoSelecionado onSelecionar;

  const EditarPeriodoSheet({
    super.key,
    required this.selecionado,
    required this.onSelecionar,
  });

  static const Color vermelhoBrand = Color(0xFFD03025);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final opcoes = const [3, 6, 9, 12];

    Widget tile(int m) {
      final active = m == selecionado;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => onSelecionar(m),
          child: Container(
            height: 108,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: active ? const Color(0xFFFFE9E9) : Colors.white,
              border: Border.all(
                color: active ? vermelhoBrand : const Color(0xFFE6E6E6),
                width: 1.2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0F000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_note_outlined,
                  color: active ? vermelhoBrand : Colors.black54,
                ),
                const SizedBox(height: 6),
                Text(
                  '$m',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: active ? vermelhoBrand : const Color(0xFF222222),
                  ),
                ),
                Text(
                  'meses',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: active ? vermelhoBrand : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: vermelhoBrand,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.event, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Selecionar Período',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF222222),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.black54),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FBFF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE6EEF9)),
              ),
              child: Text(
                'Dica: Selecione diferentes períodos para analisar tendências de vendas.',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                tile(opcoes[0]),
                const SizedBox(width: 12),
                tile(opcoes[1]),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                tile(opcoes[2]),
                const SizedBox(width: 12),
                tile(opcoes[3]),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: vermelhoBrand,
                  side: const BorderSide(color: vermelhoBrand),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Cancelar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
