import 'package:flutter/material.dart';

class RelatoriosTab extends StatelessWidget {
  const RelatoriosTab({super.key});

  @override
  Widget build(BuildContext context) {
    final consultores = const [
      _ConsultorResumo(nome: "João Silva", avatarUrl: null, total: 0, mes: 0),
      _ConsultorResumo(nome: "Pedro Costa", avatarUrl: null, total: 0, mes: 0),
    ];

    final atividadesRecentes = const <_Atividade>[
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Relatório por Consultor",
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Resumo de cadastros por consultor",
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                  const SizedBox(height: 12),

                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: consultores.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final c = consultores[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFEAEAEA),
                          backgroundImage:
                              c.avatarUrl != null ? NetworkImage(c.avatarUrl!) : null,
                          child: c.avatarUrl == null
                              ? Text(_iniciais(c.nome),
                                  style: const TextStyle(color: Colors.black))
                              : null,
                        ),
                        title: Text(c.nome,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const SizedBox.shrink(),
                        trailing: _TotaisChip(total: c.total, mes: c.mes),
                        onTap: () {},
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Atividade Recente",
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  const Text("Eventos e ações mais recentes no sistema",
                      style: TextStyle(color: Colors.black54, fontSize: 12)),
                  const SizedBox(height: 12),

                  if (atividadesRecentes.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        "Nenhuma atividade recente.",
                        style: TextStyle(color: Colors.black54),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: atividadesRecentes.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final a = atividadesRecentes[index];
                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFEAEAEA),
                            child: Icon(Icons.history, color: Colors.black54),
                          ),
                          title: Text(a.titulo,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(a.detalhe,
                              style: const TextStyle(color: Colors.black54)),
                          trailing: Text(a.data,
                              style: const TextStyle(color: Colors.black54)),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TotaisChip extends StatelessWidget {
  final int total;
  final int mes;
  const _TotaisChip({required this.total, required this.mes});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96, 
      child: FittedBox(
        fit: BoxFit.scaleDown,          
        alignment: Alignment.centerRight, 
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F2F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text("$total total", style: const TextStyle(fontSize: 11)),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F2F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text("$mes este mês", style: const TextStyle(fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsultorResumo {
  final String nome;
  final String? avatarUrl;
  final int total;
  final int mes;
  const _ConsultorResumo({
    required this.nome,
    this.avatarUrl,
    required this.total,
    required this.mes,
  });
}

class _Atividade {
  final String titulo;
  final String detalhe;
  final String data;
  const _Atividade({
    required this.titulo,
    required this.detalhe,
    required this.data,
  });
}

String _iniciais(String nome) {
  final parts = nome.trim().split(' ').where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return "??";
  final first = parts.first;
  final second = parts.length > 1 ? parts.last : "";
  return (first + second).toUpperCase();
}
