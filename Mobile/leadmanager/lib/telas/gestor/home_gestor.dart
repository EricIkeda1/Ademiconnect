import 'package:flutter/material.dart';
import '../widgets/custom_navbar.dart';
import '../widgets/stat_card.dart';
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
          tabsNoAppBar: false,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: GridView.count(
                crossAxisCount: 1,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                childAspectRatio: 5.5,
                children: const [
                  StatCard(title: "Cadastros Hoje", value: "0", icon: Icons.event_available, color: Colors.blue),
                  StatCard(title: "Cadastros Este Mês", value: "0", icon: Icons.stacked_bar_chart, color: Colors.green),
                  StatCard(title: "Cadastros Este Ano", value: "0", icon: Icons.insert_chart, color: Colors.purple),
                  StatCard(title: "Consultores Ativos", value: "2", icon: Icons.groups, color: Colors.orange),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                elevation: 2,
                child: TabBar(
                  isScrollable: true,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 14),
                  labelColor: Colors.black,
                  unselectedLabelColor: Colors.black54,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  indicator: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
                  ),
                  tabs: const [
                    Tab(text: 'Dashboard'),
                    Tab(text: 'Consultores'),
                    Tab(text: 'Designar Trabalho'),
                    Tab(text: 'Todos os Clientes'),
                    Tab(text: 'Relatórios'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

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
