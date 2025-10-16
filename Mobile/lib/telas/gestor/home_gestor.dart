import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/custom_navbar.dart';
import 'widgets/stat_card.dart';
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
  bool _isLoading = true;

  SupabaseClient get _client => Supabase.instance.client;

  Future<List<Map<String, dynamic>>>? _consultoresFuture;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadConsultores();
  }

  Future<void> _loadUserData() async {
    final user = _client.auth.currentSession?.user;
    if (user == null || !mounted) return;

    try {
      final response = await _client
          .from('gestor')
          .select('nome')
          .eq('id', user.id)
          .maybeSingle();

      String nomeFormatado = 'Gestor';
      if (response != null && response.containsKey('nome')) {
        final nomeCompleto = (response['nome'] as String?) ?? '';
        nomeFormatado = _formatarNome(nomeCompleto);
      } else {
        nomeFormatado = (user.email?.split('@').first ?? 'Gestor');
      }

      if (mounted) {
        setState(() {
          _userName = nomeFormatado;
          _isLoading = false;
        });
      }
    } catch (error) {
      print('❌ Erro ao carregar nome do gestor: $error');
      final fallback = _client.auth.currentSession?.user?.email?.split('@').first ?? 'Gestor';
      if (mounted) {
        setState(() {
          _userName = fallback;
          _isLoading = false;
        });
      }
    }
  }

  void _loadConsultores() {
    final user = _client.auth.currentSession?.user;
    if (user == null || !mounted) return;

    // CORREÇÃO: Tabela com "es"
    final consultoresFuture = _client
        .from('consultores') // ✅ NOME CORRETO
        .select('id, nome')
        .eq('gestor_id', user.id)
        .order('nome')
        .order('created_at', ascending: false)
        .then((data) => data as List<Map<String, dynamic>>);

    if (mounted) {
      setState(() {
        _consultoresFuture = consultoresFuture;
      });
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
            if (n.metrics.axis == Axis.vertical && mounted) {
              final double offset = n.metrics.pixels.clamp(0.0, 60.0);
              final double p = (offset / 60.0).clamp(0.0, 1.0);
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
                  child: _buildStatsCardGrid(),
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
                const ConsultoresTab(),
                const TodosClientesTab(),
                const RelatoriosTab(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCardGrid() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _consultoresFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return GridView.count(
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
                title: "Consultor Ativo",
                value: "0",
                icon: Icons.groups,
                color: Colors.orange,
              ),
            ],
          );
        }

        if (snapshot.hasError) {
          return GridView.count(
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
                title: "Consultor Ativo",
                value: "Erro",
                icon: Icons.error,
                color: Colors.red,
              ),
            ],
          );
        }

        final count = snapshot.data?.length ?? 0;

        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2,
          children: [
            const StatCard(
              title: "Cadastros Hoje",
              value: "0",
              icon: Icons.event_available,
              color: Colors.blue,
            ),
            const StatCard(
              title: "Cadastros Este Mês",
              value: "0",
              icon: Icons.stacked_bar_chart,
              color: Colors.green,
            ),
            const StatCard(
              title: "Cadastros Este Ano",
              value: "0",
              icon: Icons.insert_chart,
              color: Colors.purple,
            ),
            StatCard(
              title: "Consultor Ativo",
              value: count.toString(),
              icon: Icons.groups,
              color: Colors.orange,
            ),
          ],
        );
      },
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
