import 'package:flutter/material.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  final TextEditingController _searchCtrl = TextEditingController();

  final List<_ConsultorStatus> _consultores = const [
    _ConsultorStatus(
      nome: "João Silva",
      status: "Trabalhando hoje",
      local: "Rua das Flores, Centro - Comércio Local",
    ),
    _ConsultorStatus(
      nome: "Pedro Costa",
      status: "Trabalhando hoje",
      local: "Rua dos Empresários, Zona Industrial",
    ),
  ];

  final List<_VisitaProg> _visitas = const [
    _VisitaProg(
      titulo: "Avenida Principal, Bairro Comercial - Shopping e Lojas",
      consultor: "João Silva",
      data: "16/09/2025",
    ),
    _VisitaProg(
      titulo: "Boulevard Shopping, Centro da Cidade",
      consultor: "Pedro Costa",
      data: "17/09/2025",
    ),
  ];

  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() {
        _query = _searchCtrl.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_VisitaProg> get _visitasFiltradas {
    if (_query.isEmpty) return _visitas;
    final q = _query.toLowerCase();
    return _visitas.where((v) => v.titulo.toLowerCase().contains(q)).toList();
  }

  bool get _ruaJaProgramada {
    if (_query.isEmpty) return false;
    final q = _query.toLowerCase();
    return _visitas.any((v) => v.titulo.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _SearchBar(
            controller: _searchCtrl,
            hint: 'Pesquisar nome da rua...',
          ),
          const SizedBox(height: 12),

          if (_query.isNotEmpty) _DisponibilidadeChip(disponivel: !_ruaJaProgramada),

          const SizedBox(height: 16),

          _Section(
            title: "Status dos Consultores",
            subtitle: "Situação atual de trabalho de cada consultor",
            child: Column(
              children: _consultores
                  .map((c) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ConsultorStatusTile(
                          nome: c.nome,
                          status: c.status,
                          local: c.local,
                        ),
                      ))
                  .toList(),
            ),
          ),

          const SizedBox(height: 16),

          _Section(
            title: "Visitas Programadas",
            subtitle: _query.isEmpty
                ? "Próximas visitas programadas"
                : "Resultados para: $_query",
            child: Column(
              children: _visitasFiltradas
                  .map((v) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _VisitaTile(
                          titulo: v.titulo,
                          consultor: v.consultor,
                          data: v.data,
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConsultorStatus {
  final String nome;
  final String status;
  final String local;
  const _ConsultorStatus({
    required this.nome,
    required this.status,
    required this.local,
  });
}

class _VisitaProg {
  final String titulo;
  final String consultor;
  final String data;
  const _VisitaProg({
    required this.titulo,
    required this.consultor,
    required this.data,
  });
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  const _SearchBar({required this.controller, this.hint = 'Pesquisar...'});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => controller.clear(),
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
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      ),
      onSubmitted: (_) {},
    );
  }
}

class _DisponibilidadeChip extends StatelessWidget {
  final bool disponivel;
  const _DisponibilidadeChip({required this.disponivel});

  @override
  Widget build(BuildContext context) {
    final color = disponivel ? const Color(0xFF2E7D32) : const Color(0xFF6B7280);
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

class _Section extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  const _Section({required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Colors.black54, fontSize: 12)),
          const SizedBox(height: 12),
          child,
        ]),
      ),
    );
  }
}

class _ConsultorStatusTile extends StatelessWidget {
  final String nome;
  final String status;
  final String local;
  const _ConsultorStatusTile({required this.nome, required this.status, required this.local});

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

class _VisitaTile extends StatelessWidget {
  final String titulo;
  final String consultor;
  final String data;
  const _VisitaTile({required this.titulo, required this.consultor, required this.data});

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