import 'package:flutter/material.dart';

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: const [
          _Section(
            title: "Status dos Consultores",
            subtitle: "Situação atual de trabalho de cada consultor",
            child: Column(
              children: [
                _ConsultorStatusTile(
                  nome: "João Silva",
                  status: "Trabalhando hoje",
                  local: "Rua das Flores, Centro - Comércio Local",
                ),
                SizedBox(height: 8),
                _ConsultorStatusTile(
                  nome: "Pedro Costa",
                  status: "Trabalhando hoje",
                  local: "Rua dos Empresários, Zona Industrial",
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          _Section(
            title: "Visitas Programadas",
            subtitle: "Próximas visitas programadas",
            child: Column(
              children: [
                _VisitaTile(
                  titulo: "Avenida Principal, Bairro Comercial - Shopping e Lojas",
                  consultor: "João Silva",
                  data: "16/09/2025",
                ),
                SizedBox(height: 8),
                _VisitaTile(
                  titulo: "Boulevard Shopping, Centro da Cidade",
                  consultor: "Pedro Costa",
                  data: "17/09/2025",
                ),
              ],
            ),
          ),
        ],
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
