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
  Future<Map<String, int>>? _contadoresFuture;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadConsultores();
    _contadoresFuture = _loadContadores();
  }

  Future<void> _loadUserData() async {
    final user = _client.auth.currentSession?.user;
    if (user == null || !mounted) return;

    try {
      final response = await _client.from('gestor').select('nome').eq('id', user.id).maybeSingle();
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
    } catch (_) {
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

    final consultoresFuture = _client
        .from('consultores')
        .select('id, nome, data_cadastro')
        .eq('gestor_id', user.id)
        .eq('ativo', true)
        .order('nome', ascending: true)
        .order('data_cadastro', ascending: false)
        .then((data) {
      final list = (data as List).cast<Map<String, dynamic>>();
      debugPrint('Consultores ativos carregados: ${list.length}');
      return list;
    });

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

  Future<int> _countRpc({required String gestorId, DateTime? inicio, DateTime? fim}) async {
    try {
      final params = <String, dynamic>{
        'p_gestor_id': gestorId,
        'p_inicio': inicio?.toIso8601String(),
        'p_fim': fim?.toIso8601String(),
      };
      final res = await _client.rpc('count_consultores_periodo', params: params);
      if (res is int) return res;
      if (res is num) return res.toInt();
      if (res is List && res.isNotEmpty) {
        final v = res.first;
        if (v is int) return v;
        if (v is num) return v.toInt();
        if (v is Map && v.values.isNotEmpty) {
          final firstVal = v.values.first;
          if (firstVal is int) return firstVal;
          if (firstVal is num) return firstVal.toInt();
        }
      }
      if (res is Map && res.isNotEmpty) {
        final firstVal = res.values.first;
        if (firstVal is int) return firstVal;
        if (firstVal is num) return firstVal.toInt();
      }
      return 0;
    } catch (e) {
      debugPrint('Erro RPC count_consultores_periodo: $e');
      return 0;
    }
  }

  Future<Map<String, int>> _loadContadores() async {
    final user = _client.auth.currentSession?.user;
    if (user == null) {
      return {'hoje': 0, 'mes': 0, 'ano': 0, 'ativos': 0};
    }

    final now = DateTime.now().toUtc();
    final inicioHoje = DateTime.utc(now.year, now.month, now.day);
    final inicioAmanha = inicioHoje.add(const Duration(days: 1));
    final inicioMes = DateTime.utc(now.year, now.month, 1);
    final inicioProxMes = (now.month == 12) ? DateTime.utc(now.year + 1, 1, 1) : DateTime.utc(now.year, now.month + 1, 1);
    final inicioAno = DateTime.utc(now.year, 1, 1);
    final inicioProxAno = DateTime.utc(now.year + 1, 1, 1);

    final gestorId = user.id;
    final futures = <Future<int>>[
      _countRpc(gestorId: gestorId, inicio: inicioHoje, fim: inicioAmanha),
      _countRpc(gestorId: gestorId, inicio: inicioMes, fim: inicioProxMes),
      _countRpc(gestorId: gestorId, inicio: inicioAno, fim: inicioProxAno),
      _countRpc(gestorId: gestorId),
    ];
    final r = await Future.wait(futures);
    return {'hoje': r[0], 'mes': r[1], 'ano': r[2], 'ativos': r[3]};
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
              hideAvatar: true,
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
              SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(12), child: _buildStatsCardGrid())),
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabsHeaderDelegate(
                  Container(
                    height: 56,
                    color: const Color(0xFFdcddde),
                    alignment: Alignment.centerLeft,
                    child: const TabBar(
                      isScrollable: true,
                      labelPadding: EdgeInsets.symmetric(horizontal: 12), 
                      labelColor: Colors.black,
                      unselectedLabelColor: Colors.black54,
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                      indicator: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2)],
                      ),
                      tabs: [
                        Tab(text: 'Visitas do Consultor'),
                        Tab(text: 'Consultores'),
                        Tab(text: 'Todos os Clientes'),
                        Tab(text: 'Relatórios'),
                      ],
                    ),
                  ),
                  min: 56,
                  max: 56,
                ),
              ),
            ],
            body: const TabBarView(
              children: [
                MinhasVisitasPage(),
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

  Widget _buildStatsCardGrid() {
    return FutureBuilder<Map<String, int>>(
      future: _contadoresFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2,
            children: const [
              StatCard(title: "Cadastros Hoje", value: "0", icon: Icons.event_available, color: Colors.blue),
              StatCard(title: "Cadastros Este Mês", value: "0", icon: Icons.stacked_bar_chart, color: Colors.green),
              StatCard(title: "Cadastros Este Ano", value: "0", icon: Icons.insert_chart, color: Colors.purple),
              StatCard(title: "Consultor Ativo", value: "0", icon: Icons.groups, color: Colors.orange),
            ],
          );
        }

        if (snap.hasError || snap.data == null) {
          return GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2,
            children: const [
              StatCard(title: "Cadastros Hoje", value: "0", icon: Icons.event_available, color: Colors.blue),
              StatCard(title: "Cadastros Este Mês", value: "0", icon: Icons.stacked_bar_chart, color: Colors.green),
              StatCard(title: "Cadastros Este Ano", value: "0", icon: Icons.insert_chart, color: Colors.purple),
              StatCard(title: "Consultor Ativo", value: "Erro", icon: Icons.error, color: Colors.red),
            ],
          );
        }

        final dados = snap.data!;
        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2,
          children: [
            StatCard(title: "Cadastros Hoje", value: (dados['hoje'] ?? 0).toString(), icon: Icons.event_available, color: Colors.blue),
            StatCard(title: "Cadastros Este Mês", value: (dados['mes'] ?? 0).toString(), icon: Icons.stacked_bar_chart, color: Colors.green),
            StatCard(title: "Cadastros Este Ano", value: (dados['ano'] ?? 0).toString(), icon: Icons.insert_chart, color: Colors.purple),
            StatCard(title: "Consultor Ativo", value: (dados['ativos'] ?? 0).toString(), icon: Icons.groups, color: Colors.orange),
          ],
        );
      },
    );
  }
}

class _TabsHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double min;
  final double max;
  _TabsHeaderDelegate(this.child, {this.min = 56, this.max = 56});

  @override
  double get minExtent => min;
  @override
  double get maxExtent => max;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(
      color: Colors.transparent,
      elevation: overlapsContent ? 1 : 0,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => false;
}
