import 'package:flutter/material.dart';

class AvisosSheetMock extends StatelessWidget {
  const AvisosSheetMock({super.key});

  String _dataStr(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    const texto = Color(0xFF231F20);
    const branco = Color(0xFFFFFFFF);

    final itens = <_AvisoMock>[
      _AvisoMock(
        tipo: _TipoAviso.urgente,
        titulo: 'PAP - Retorno Urgente',
        mensagem:
            'O lead Pedro Oliveira precisa de retorno em 15 dias. Data limite: 25/11/2024',
        data: DateTime(2024, 10, 25),
        lido: false,
      ),
      _AvisoMock(
        tipo: _TipoAviso.programado,
        titulo: 'PAP - Retorno Programado',
        mensagem:
            'O lead Maria Santos tem retorno agendado para 20/01/2025 (85 dias)',
        data: DateTime(2024, 10, 24),
        lido: false,
      ),
      _AvisoMock(
        tipo: _TipoAviso.lead,
        titulo: 'Lead Recebido',
        mensagem:
            'Você recebeu o lead Ana Costa transferido por Carlos Mendes',
        data: DateTime(2024, 10, 23),
        lido: true,
      ),
      _AvisoMock(
        tipo: _TipoAviso.lembrete,
        titulo: 'Lembrete PAP',
        mensagem:
            'O sistema PAP exige retorno em até 3 meses. Configure os parâmetros de retorno para cada lead.',
        data: DateTime(2024, 10, 22),
        lido: true,
      ),
    ];

    final novas = itens.where((e) => !e.lido).length;

    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.82,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.notifications_none_rounded,
                      color: Color(0xFFEA3124)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Notificações',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: texto,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFED1C24),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$novas novas',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                itemCount: itens.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final a = itens[i];
                  final urgenteChip = a.tipo == _TipoAviso.urgente;

                  return Material(
                    color: branco,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: a.isRedBorder
                            ? const Color(0xFFEA3124)
                            : const Color(0xFFDFDFDF),
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(a.iconData, color: a.iconColor),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  a.titulo,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: texto,
                                  ),
                                ),
                              ),
                              if (urgenteChip)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEA3124),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Urgente',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            a.mensagem,
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: Color(0xFF4B4B4F),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _dataStr(a.data),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9A9AA0),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _TipoAviso { urgente, programado, lead, lembrete }

class _AvisoMock {
  final _TipoAviso tipo;
  final String titulo;
  final String mensagem;
  final DateTime data;
  final bool lido;

  _AvisoMock({
    required this.tipo,
    required this.titulo,
    required this.mensagem,
    required this.data,
    required this.lido,
  });

  bool get isRedBorder =>
      tipo == _TipoAviso.urgente || tipo == _TipoAviso.programado;

  IconData get iconData {
    switch (tipo) {
      case _TipoAviso.urgente:
        return Icons.notifications_active_outlined;
      case _TipoAviso.programado:
        return Icons.event_note_outlined;
      case _TipoAviso.lead:
        return Icons.check_circle_outline;
      case _TipoAviso.lembrete:
        return Icons.notifications_none_outlined;
    }
  }

  Color get iconColor {
    switch (tipo) {
      case _TipoAviso.urgente:
      case _TipoAviso.programado:
        return const Color(0xFFEA3124);
      case _TipoAviso.lead:
        return const Color(0xFF2E7D32);
      case _TipoAviso.lembrete:
        return const Color(0xFF9FA3A9);
    }
  }
}
