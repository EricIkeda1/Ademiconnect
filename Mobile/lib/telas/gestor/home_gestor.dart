import 'package:flutter/material.dart';
import '../widgets/custom_navbar.dart';
import '../widgets/stat_card.dart';
import 'minhas_visitas.dart';
import 'cadastrar_consultores.dart';
import 'designar_trabalho_tab.dart';
import 'todos_clientes_tab.dart';
import 'relatorios_tab.dart';

class HomeGestor extends StatelessWidget {
  const HomeGestor({super.key});

  static const Color kAppBarRed = Color(0xFFD03025);
  static const Color kNeutralGray = Color(0xFF939598); 

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Theme(
            data: Theme.of(context).copyWith(
              appBarTheme: const AppBarTheme(
                backgroundColor: kAppBarRed,
                surfaceTintColor: kAppBarRed,
                elevation: 1,
                centerTitle: false,
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: kNeutralGray, 
                  side: const BorderSide(color: kNeutralGray), 
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                ),
              ),
              iconTheme: const IconThemeData(color: kNeutralGray),
            ),
            child: const CustomNavbar(
              nome: 'Maria Santos',
              cargo: 'Gestor',
              tabsNoAppBar: false,
            ),
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2, 
                children: const [
                  SizedBox(
                    height: 80, 
                    child: StatCard(
                      title: "Cadastros Hoje",
                      value: "0",
                      icon: Icons.event_available,
                      color: Colors.blue,
                    ),
                  ),
                  SizedBox(
                    height: 80,
                    child: StatCard(
                      title: "Cadastros Este Mês",
                      value: "0",
                      icon: Icons.stacked_bar_chart,
                      color: Colors.green,
                    ),
                  ),
                  SizedBox(
                    height: 80,
                    child: StatCard(
                      title: "Cadastros Este Ano",
                      value: "0",
                      icon: Icons.insert_chart,
                      color: Colors.purple,
                    ),
                  ),
                  SizedBox(
                    height: 80,
                    child: StatCard(
                      title: "Consultores Ativos",
                      value: "2",
                      icon: Icons.groups,
                      color: Colors.orange,
                    ),
                  ),
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
                  labelStyle:
                      const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  indicator: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 2)
                    ],
                  ),
                  tabs: const [
                    Tab(text: 'Minhas Vistas'),
                    Tab(text: 'Consultores'),
                    Tab(text: 'Designar Trabalho'),
                    Tab(text: 'Todos os Clientes'),
                    Tab(text: 'Relatórios'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Expanded(
              child: TabBarView(
                children: [
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
