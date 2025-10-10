import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  String _userName = 'Gestor'; // Será substituído pelo nome real

  static const double collapseDistance = 60.0;

  @override
  void initState() {
    super.initState();
    _loadUserData(); // Carrega o nome do gestor
  }

  /// Carrega o nome do gestor a partir da coleção 'gestor'
  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // ✅ Mudança aqui: busca na coleção 'gestor'
      final doc = await FirebaseFirestore.instance
          .collection('gestor')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        // Usa o nome cadastrado no Firestore
        final nome = doc.get('nome') as String? ?? 'Gestor';
        setState(() {
          _userName = nome;
        });
      } else {
        // Fallback: tenta extrair do email
        final fallback = user.email?.split('@').first ?? 'Gestor';
        setState(() {
          _userName = fallback;
        });
      }
    } catch (e) {
      print('❌ Erro ao carregar nome do gestor: $e');
      final fallback = user.email?.split('@').first ?? 'Gestor';
      setState(() {
        _userName = fallback;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: CustomNavbar(
          nome: _userName, // ✅ Nome dinâmico exibido
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
                    labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
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
