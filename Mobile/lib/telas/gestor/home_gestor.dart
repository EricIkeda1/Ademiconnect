import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../widgets/custom_navbar.dart';
import '../widgets/stat_card.dart';
import 'minhas_visitas.dart';
import 'cadastrar_consultores.dart';
import 'todos_clientes_tab.dart';
import 'relatorios_tab.dart';

class HomeGestor extends StatefulWidget {
  const HomeGestor({super.key});

  @override
  State<HomeGestor> createState() => _HomeGestorState();
}

class _HomeGestorState extends State<HomeGestor> {
  double _collapseProgress = 0.0;
  String _userName = 'Gestor';
  int _totalConsultores = 0;
  int _totalClientes = 0;
  int _consultoresAtivos = 0;

  static const double collapseDistance = 60.0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadStats();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('gestor')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final nomeCompleto = doc.get('nome') as String? ?? 'Gestor';
        final nomeFormatado = _formatarNome(nomeCompleto);
        setState(() {
          _userName = nomeFormatado;
        });
      } else {
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

  Future<void> _loadStats() async {
    final gestorUid = FirebaseAuth.instance.currentUser?.uid;
    if (gestorUid == null) return;

    try {
      // Carrega consultores do gestor
      final consultoresSnapshot = await FirebaseFirestore.instance
          .collection('consultores')
          .where('gestorId', isEqualTo: gestorUid)
          .get();

      final consultoresIds = consultoresSnapshot.docs.map((doc) => doc.id).toList();
      final totalConsultores = consultoresIds.length;

      // Carrega total de clientes
      int totalClientes = 0;
      if (consultoresIds.isNotEmpty) {
        final clientesSnapshot = await FirebaseFirestore.instance
            .collection('clientes')
            .where('consultorId', whereIn: consultoresIds)
            .get();
        totalClientes = clientesSnapshot.docs.length;
      }

      // Consultores ativos (que têm pelo menos 1 cliente)
      int consultoresAtivos = 0;
      if (consultoresIds.isNotEmpty) {
        for (final consultorId in consultoresIds) {
          final clientesConsultor = await FirebaseFirestore.instance
              .collection('clientes')
              .where('consultorId', isEqualTo: consultorId)
              .limit(1)
              .get();
          if (clientesConsultor.docs.isNotEmpty) {
            consultoresAtivos++;
          }
        }
      }

      setState(() {
        _totalConsultores = totalConsultores;
        _totalClientes = totalClientes;
        _consultoresAtivos = consultoresAtivos;
      });
    } catch (e) {
      print('❌ Erro ao carregar stats: $e');
    }
  }

  String _formatarNome(String nome) {
    final partes = nome.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) return 'Gestor';
    if (partes.length == 1) return partes[0];
    return '${partes[0]} ${partes.last}';
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4, 
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Theme(
            data: Theme.of(context).copyWith(
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFFD03025),
                surfaceTintColor: Color(0xFFD03025),
                elevation: 1,
                centerTitle: false,
              ),
            ),
            child: CustomNavbar(
              nome: _userName,
              cargo: 'Gestor',
              tabsNoAppBar: false,
              collapseProgress: _collapseProgress,
            ),
          ),
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
                    children: [
                      StatCard(
                        title: "Total Consultores",
                        value: _totalConsultores.toString(),
                        icon: Icons.groups,
                        color: Colors.blue,
                      ),
                      StatCard(
                        title: "Total Clientes",
                        value: _totalClientes.toString(),
                        icon: Icons.people_outline,
                        color: Colors.green,
                      ),
                      StatCard(
                        title: "Consultores Ativos",
                        value: _consultoresAtivos.toString(),
                        icon: Icons.assignment_ind,
                        color: Colors.orange,
                      ),
                      StatCard(
                        title: "Taxa de Atividade",
                        value: _totalConsultores > 0 
                            ? "${((_consultoresAtivos / _totalConsultores) * 100).toStringAsFixed(0)}%" 
                            : "0%",
                        icon: Icons.trending_up,
                        color: Colors.purple,
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
                      Tab(text: 'Visitas dos Consultores'),
                      Tab(text: 'Cadastrar Consultores'),
                      Tab(text: 'Todos os Clientes'),
                      Tab(text: 'Relatórios'),
                    ],
                  ),
                ),
              ),
            ],
            body: TabBarView(
              physics: const BouncingScrollPhysics(),
              children: [
                const DashboardTab(),
                ConsultoresTab(),
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