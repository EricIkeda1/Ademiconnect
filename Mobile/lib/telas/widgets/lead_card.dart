import 'package:flutter/material.dart';

class LeadCard extends StatelessWidget {
  final String nome;
  final String telefone;
  final String endereco;
  final String consultor;
  final String observacao;
  final int dias;
  final bool urgente;
  final bool alerta;
  final VoidCallback onEditar;
  final VoidCallback onTransferir;

  // NOVO: estabelecimento opcional (default = '')
  final String estabelecimento;

  const LeadCard({
    super.key,
    required this.nome,
    required this.telefone,
    required this.endereco,
    required this.consultor,
    required this.observacao,
    required this.dias,
    required this.urgente,
    required this.alerta,
    required this.onEditar,
    required this.onTransferir,
    this.estabelecimento = '', // compatível com chamadas antigas
  });

  static const branco = Color(0xFFFFFFFF);
  static const texto = Color(0xFF231F20);
  static const vermelho = Color(0xFFEA3124);
  static const cinzaBorda = Color(0xFFDFDFDF);
  static const cinzaIcone = Color(0xFF6D6D6D);
  static const obsBg = Color(0xFFFFF2F2);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: branco,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: cinzaBorda, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    nome,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: texto),
                  ),
                ),
                _DiasBadge(dias: dias, alerta: alerta, urgente: urgente),
              ],
            ),
            const SizedBox(height: 8),

            // Telefone
            Row(
              children: [
                const Icon(Icons.phone, size: 16, color: cinzaIcone),
                const SizedBox(width: 8),
                Expanded(child: Text(telefone, style: const TextStyle(fontSize: 13.5, color: texto))),
              ],
            ),
            const SizedBox(height: 6),

            // Endereço
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: cinzaIcone),
                const SizedBox(width: 8),
                Expanded(child: Text(endereco, style: const TextStyle(fontSize: 13.5, color: texto))),
              ],
            ),

            // NOVO: Estabelecimento
            if (estabelecimento.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.storefront_outlined, size: 16, color: cinzaIcone),
                  const SizedBox(width: 8),
                  Expanded(child: Text(estabelecimento, style: const TextStyle(fontSize: 13.5, color: texto))),
                ],
              ),
            ],

            const SizedBox(height: 6),

            // Consultor
            Row(
              children: [
                const Icon(Icons.person_outline, size: 16, color: cinzaIcone),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    consultor.isEmpty ? '—' : 'Consultor: $consultor',
                    style: const TextStyle(fontSize: 13.5, color: texto),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Observação
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: obsBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: vermelho.withOpacity(0.25)),
              ),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 13.5, color: texto, height: 1.25),
                  children: [
                    const TextSpan(
                      text: 'Obs: ',
                      style: TextStyle(fontWeight: FontWeight.w700, color: vermelho),
                    ),
                    TextSpan(text: observacao.isEmpty ? '—' : observacao),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Ações
            Row(
              children: [
                _BotaoTexto(
                  icon: Icons.edit_outlined,
                  label: 'Editar',
                  onTap: onEditar,
                  cor: texto,
                  bg: branco,
                  borda: cinzaBorda,
                ),
                const SizedBox(width: 8),
                _BotaoTexto(
                  icon: Icons.swap_horiz_outlined,
                  label: 'Transferir',
                  onTap: onTransferir,
                  cor: branco,
                  bg: vermelho,
                  borda: vermelho,
                ),
                const Spacer(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DiasBadge extends StatelessWidget {
  final int dias;
  final bool urgente;
  final bool alerta;
  const _DiasBadge({required this.dias, required this.urgente, required this.alerta});

  @override
  Widget build(BuildContext context) {
    Color bg = const Color(0xFFE7F7EE);
    Color fg = const Color(0xFF1B8151);
    if (urgente) {
      bg = const Color(0xFFFFEAEA);
      fg = const Color(0xFFB21F1F);
    } else if (alerta) {
      bg = const Color(0xFFFFF4E1);
      fg = const Color(0xFFA86A00);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text('$dias dias', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

class _BotaoTexto extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color cor;
  final Color bg;
  final Color borda;
  const _BotaoTexto({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.cor,
    required this.bg,
    required this.borda,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: borda, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: cor),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: cor)),
            ],
          ),
        ),
      ),
    );
  }
}
