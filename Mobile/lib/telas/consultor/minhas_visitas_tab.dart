import 'package:flutter/material.dart';

class MinhasVisitasTab extends StatefulWidget {
  const MinhasVisitasTab({super.key});

  @override
  State<MinhasVisitasTab> createState() => _MinhasVisitasTabState();
}

class _MinhasVisitasTabState extends State<MinhasVisitasTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  final _hojeTitulo = 'HOJE - Sua área de trabalho';
  final _hojeSub = 'Rua das Flores, Centro - Comércio Local';

  final List<_VisitaItem> _cronograma = const [
    _VisitaItem(
      icone: Icons.flag_outlined,
      titulo: 'Rua das Flores, Centro - Comércio Local',
      subtitulo: 'segunda-feira, 15 de setembro de 2025',
      chipTexto: 'HOJE',
      chipBg: Colors.black,
      chipFg: Colors.white,
    ),
    _VisitaItem(
      icone: Icons.event_note_outlined,
      titulo: 'Avenida Principal, Bairro Comercial - Shopping e Lojas',
      subtitulo: 'terça-feira, 16 de setembro de 2025',
      chipTexto: 'AGENDADO',
      chipBg: Color(0x3328A745),
      chipFg: Colors.green,
    ),
  ];

  List<_VisitaItem> get _cronogramaFiltrado {
    if (_query.isEmpty) return _cronograma;
    final q = _query.toLowerCase();
    return _cronograma.where((v) => v.titulo.toLowerCase().contains(q)).toList();
  }

  bool get _ruaJaProgramada {
    if (_query.isEmpty) return false;
    final q = _query.toLowerCase();
    return _cronograma.any((v) => v.titulo.toLowerCase().contains(q));
  }

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget cardWrapper({required String title, required Widget child}) {
      return Card.outlined(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      );
    }

    final cardPesquisa = cardWrapper(
      title: 'Pesquisar Rua',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchCtrl,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Pesquisar nome da rua...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: _searchCtrl.clear,
                      tooltip: 'Limpar',
                    ),
              filled: true,
              fillColor: const Color(0xFFF7F7F7),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.black12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.black12),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            ),
          ),
          if (_query.isNotEmpty) ...[
            const SizedBox(height: 10),
            _DisponibilidadeChip(disponivel: !_ruaJaProgramada),
          ],
        ],
      ),
    );

    final cardHoje = cardWrapper(
      title: 'Ruas de Trabalho',
      child: ListTile(
        leading: Icon(Icons.location_on, color: cs.primary),
        title: Text(_hojeTitulo),
        subtitle: Text(_hojeSub),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: cs.primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Text('PRIORIDADE'),
        ),
      ),
    );

    final cardCronograma = cardWrapper(
      title: 'Cronograma de Visitas',
      child: Column(
        children: [
          ..._cronogramaFiltrado.map((v) {
            return Column(
              children: [
                ListTile(
                  leading: Icon(v.icone),
                  title: Text(v.titulo),
                  subtitle: Text(v.subtitulo),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: v.chipBg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      v.chipTexto,
                      style: TextStyle(
                          color: v.chipFg, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                if (v != _cronogramaFiltrado.last) const Divider(height: 0),
              ],
            );
          }),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        cardPesquisa,
        const SizedBox(height: 12),
        cardHoje,
        const SizedBox(height: 12),
        cardCronograma,
      ],
    );
  }
}

class _VisitaItem {
  final IconData icone;
  final String titulo;
  final String subtitulo;
  final String chipTexto;
  final Color chipBg;
  final Color chipFg;

  const _VisitaItem({
    required this.icone,
    required this.titulo,
    required this.subtitulo,
    required this.chipTexto,
    required this.chipBg,
    required this.chipFg,
  });
}

class _DisponibilidadeChip extends StatelessWidget {
  final bool disponivel;
  const _DisponibilidadeChip({required this.disponivel});

  @override
  Widget build(BuildContext context) {
    final color =
        disponivel ? const Color(0xFF2E7D32) : const Color(0xFF6B7280);
    final bg = disponivel ? const Color(0xFFE8F5E9) : const Color(0xFFF3F4F6);
    final texto = disponivel ? 'Disponível' : 'Já programada';

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              disponivel ? Icons.check_circle : Icons.info_outline,
              color: color,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              texto,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
