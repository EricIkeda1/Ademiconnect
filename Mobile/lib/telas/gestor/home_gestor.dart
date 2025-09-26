import 'package:flutter/material.dart';
import '../widgets/custom_navbar.dart';
import '../widgets/stat_card.dart';
import 'minhas_visitas.dart';
import 'cadastrar_consultores.dart';
import 'designar_trabalho_tab.dart';
import 'todos_clientes_tab.dart';
import 'relatorios_tab.dart';

class HomeGestor extends StatefulWidget {
  const HomeGestor({super.key});

  @override
  State<HomeGestor> createState() => _HomeGestorState();
}

class _HomeGestorState extends State<HomeGestor> {
  double _collapseProgress = 0.0;

  static const double collapseDistance = 60.0;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: CustomNavbar(
          nome: 'Maria Santos',
          cargo: 'Gestor',
          tabsNoAppBar: false,
          collapseProgress: _collapseProgress,
        ),
        body: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.axis == Axis.vertical) {
              final double offset = n.metrics.pixels.clamp(0.0, collapseDistance);
              final double p = (offset / collapseDistance).clamp(0.0, 1.0);
              if (p != _collapseProgress) {
                setState(() => _collapseProgress = p);
              }
            }
            return false;
          },
          child: NestedScrollView(
            headerSliverBuilder: (context, inner) => [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2,
                    children: const [
                      StatCard(
                        title: "Cadastros Hoje",
                        value: "0",
                        icon: Icons.event_available,
                        color: Colors.blue,
                      ),
                      StatCard(
                        title: "Cadastros Este Mês",
                        value: "0",
                        icon: Icons.stacked_bar_chart,
                        color: Colors.green,
                      ),
                      StatCard(
                        title: "Cadastros Este Ano",
                        value: "0",
                        icon: Icons.insert_chart,
                        color: Colors.purple,
                      ),
                      StatCard(
                        title: "Consultores Ativos",
                        value: "2",
                        icon: Icons.groups,
                        color: Colors.orange,
                      ),
                    ],
                  ),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabsHeaderDelegate(
                  TabBar(
                    isScrollable: true,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 14),
                    labelColor: Colors.black,
                    unselectedLabelColor: Colors.black54,
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 2),
                      ],
                    ),
                    tabs: const [
                      Tab(text: 'Minhas Visitas'),
                      Tab(text: 'Consultores'),
                      Tab(text: 'Designar Trabalho'),
                      Tab(text: 'Todos os Clientes'),
                      Tab(text: 'Relatórios'),
                    ],
                  ),
                ),
              ),
            ],
            body: const TabBarView(
              physics: BouncingScrollPhysics(),
              children: [
                DashboardTab(),
                ConsultoresTab(),
                DesignarTrabalhoTab(),
                TodosClientesTab(),
                RelatoriosTab(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabsHeaderDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabsHeaderDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height + 12;
  @override
  double get maxExtent => tabBar.preferredSize.height + 12;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(
      color: Colors.white,
      elevation: overlapsContent ? 1 : 0,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: tabBar,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => false;
}
