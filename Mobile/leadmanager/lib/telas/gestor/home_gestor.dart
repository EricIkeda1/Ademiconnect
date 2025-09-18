import 'package:flutter/material.dart';
import '../widgets/custom_navbar.dart';
import '../widgets/stat_card.dart';
import '../widgets/trabalho_hoje_card.dart';
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
        appBar: const CustomNavbar(
          nome: 'Maria Santos',
          cargo: 'Gestor',
          tabs: [
            Tab(text: 'Dashboard'),
            Tab(text: 'Consultores'),
            Tab(text: 'Designar Trabalho'),
            Tab(text: 'Todos os Clientes'),
            Tab(text: 'Relatórios'),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: const [
                  StatCard(title: "Cadastros Hoje", value: "0", icon: Icons.event_available, color: Colors.blue),
                  StatCard(title: "Cadastros Este Mês", value: "0", icon: Icons.stacked_bar_chart, color: Colors.green),
                  StatCard(title: "Cadastros Este Ano", value: "0", icon: Icons.insert_chart, color: Colors.purple),
                  StatCard(title: "Consultores Ativos", value: "2", icon: Icons.groups, color: Colors.orange),
                ],
              ),
            ),
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
