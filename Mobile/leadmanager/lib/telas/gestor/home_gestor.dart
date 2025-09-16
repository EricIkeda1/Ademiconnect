import 'package:flutter/material.dart';
import 'dashboard_tab.dart';
import 'consultores_tab.dart';
import 'designar_trabalho_tab.dart';
import 'todos_clientes_tab.dart';
import 'relatorios_tab.dart';

class HomeGestor extends StatelessWidget {
  const HomeGestor({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          title: Row(
            children: [
              const CircleAvatar(
                radius: 16,
                backgroundColor: Color(0xFFEAEAEA),
                child: Text("MS", style: TextStyle(color: Colors.black)),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "Olá, Maria Santos",
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
                  ),
                  Text("Gestor", style: TextStyle(color: Colors.black54, fontSize: 12)),
                ],
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/login');
                },
                icon: const Icon(Icons.logout, size: 18),
                label: const Text("Sair"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black87,
                  side: const BorderSide(color: Colors.black12),
                ),
              ),
            ),
          ],
        ),

        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 720;
                  final crossCount = isWide ? 4 : 2;
                  return GridView.count(
                    crossAxisCount: crossCount,
                    childAspectRatio: isWide ? 2.5 : 1.8,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    children: const [
                      _StatCard(title: "Cadastros Hoje", value: "0", icon: Icons.event_available, color: Colors.blue),
                      _StatCard(title: "Cadastros Este Mês", value: "0", icon: Icons.stacked_bar_chart, color: Colors.green),
                      _StatCard(title: "Cadastros Este Ano", value: "0", icon: Icons.insert_chart, color: Colors.purple),
                      _StatCard(title: "Consultores Ativos", value: "2", icon: Icons.groups, color: Colors.orange),
                    ],
                  );
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F2F5),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TabBar(
                  isScrollable: true,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 14),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.black,
                  unselectedLabelColor: Colors.black54,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  indicator: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
                  ),
                  tabs: const [
                    Tab(text: "Dashboard"),
                    Tab(text: "Consultores"),
                    Tab(text: "Designar Trabalho"),
                    Tab(text: "Todos os Clientes"),
                    Tab(text: "Relatórios"),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: TabBarView(
                children: const [
                  DashboardTab(),    
                  ConsultoresTab(),
                  DesignarTrabalhoTab(),
                  TodosClientesTab(),
                  RelatoriosTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFFF7F7F7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: color.withOpacity(.15), child: Icon(icon, color: color)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 6),
                  Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
