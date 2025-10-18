// lib/telas/consultor/home_consultor.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/custom_navbar.dart';
import 'meus_clientes_tab.dart';
import 'minhas_visitas_tab.dart';
import 'exportar_dados_tab.dart';
import 'cadastrar_cliente.dart';
import '../../models/cliente.dart';
import '../../services/cliente_service.dart';

class HomeConsultor extends StatefulWidget {
  const HomeConsultor({super.key});

  @override
  State<HomeConsultor> createState() => _HomeConsultorState();
}

class _HomeConsultorState extends State<HomeConsultor> {
  final ClienteService _clienteService = ClienteService();
  final SupabaseClient _client = Supabase.instance.client;

  int _totalClientes = 0;
  int _totalVisitasHoje = 0;
  int _totalAlertas = 0;
  int _totalFinalizados = 0;
  List<Cliente> _clientes = [];
  String _userName = 'Consultor';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadStats();
  }

  String _formatarNome(String nome) {
    final partes = nome.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) return 'Consultor';
    if (partes.length == 1) return partes[0];
    return '${partes[0]} ${partes.last}';
  }

  Future<void> _loadUserData() async {
    final user = _client.auth.currentSession?.user;
    if (user == null || !mounted) return;

    try {
      final doc = await _client
          .from('consultores')
          .select('nome, email')
          .eq('id', user.id)
          .maybeSingle();

      if (doc != null) {
        final nomeCompleto = (doc['nome'] as String?) ?? '';
        if (nomeCompleto.isNotEmpty) {
          if (mounted) setState(() => _userName = _formatarNome(nomeCompleto));
          return;
        }
        final email = (doc['email'] as String?) ?? user.email ?? '';
        if (email.isNotEmpty && mounted) {
          setState(() => _userName = email.split('@').first);
          return;
        }
      }

      final fallbackEmail = user.email ?? '';
      if (fallbackEmail.isNotEmpty && mounted) {
        setState(() => _userName = fallbackEmail.split('@').first);
        return;
      }

      if (mounted) setState(() => _userName = 'Consultor');
    } catch (_) {
      if (mounted) setState(() => _userName = 'Consultor');
    }
  }

  Future<void> _loadStats() async {
    final user = _client.auth.currentSession?.user;
    if (user == null || !mounted) return;
    final uid = user.id;

    final rows = await _client.from('clientes').select('*').eq('consultor_uid_t', uid);

    final clientes = (rows as List)
        .map((m) => Cliente.fromMap(m as Map<String, dynamic>))
        .toList();

    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);

    final visitasHoje = clientes.where((c) {
      final d = c.dataVisita;
      return d.year == hoje.year && d.month == hoje.month && d.day == hoje.day;
    }).length;

    final alertas = clientes.where((c) {
      final d = DateTime(c.dataVisita.year, c.dataVisita.month, c.dataVisita.day);
      return d.isBefore(hoje);
    }).length;

    final finalizados = alertas;

    if (mounted) {
      setState(() {
        _clientes = clientes;
        _totalClientes = clientes.length;
        _totalVisitasHoje = visitasHoje;
        _totalAlertas = alertas;
        _totalFinalizados = finalizados;
      });
    }
  }

  void _onClienteCadastrado() {
    _loadStats();
  }

  Future<void> _abrirNoGPS(String endereco, String estabelecimento) async {
    final encodedEndereco = Uri.encodeComponent(endereco);
    final url = 'https://www.google.com/maps/search/?api=1&query=$encodedEndereco';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Não foi possível abrir o Google Maps'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  Stream<List<Map<String, dynamic>>> _streamClientes() {
    final user = _client.auth.currentSession?.user;
    if (user == null) return const Stream<List<Map<String, dynamic>>>.empty();

    return _client
        .from('clientes')
        .select('id, estabelecimento, endereco, cidade, estado, data_visita, hora_visita, consultor_uid_t')
        .eq('consultor_uid_t', user.id)
        .order('data_visita', ascending: true)
        .asStream();
  }

  Widget _buildRuaTrabalhoCard() {
    final cs = Theme.of(context).colorScheme;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFFAF1),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: const Color(0xFFDCEFE1)),
                  ),
                  child: const Icon(Icons.flag, size: 13, color: Color(0xFF3CB371)),
                ),
                const SizedBox(width: 4),
                const Expanded(
                  child: Text('Rua de Trabalho - Hoje', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            _buildRuaTrabalhoHoje(),
          ],
        ),
      ),
    );
  }

  Widget _buildRuaTrabalhoHoje() {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _streamClientes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildRuaTrabalhoPlaceholder(cs, 'Carregando...', 'Buscando dados do banco');
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildRuaTrabalhoPlaceholder(cs, 'Nenhuma visita hoje', 'Cadastre clientes para ver as visitas aqui');
        }

        final lista = snapshot.data!;
        final now = DateTime.now();
        final hoje = DateTime(now.year, now.month, now.day);

        Map<String, dynamic>? clienteHoje;

        for (final data in lista) {
          final s = data['data_visita']?.toString();
          if (s == null || s.isEmpty) continue;
          try {
            final dt = DateTime.parse(s);
            final d = DateTime(dt.year, dt.month, dt.day);
            if (d == hoje) {
              clienteHoje = data;
              break;
            }
          } catch (_) {}
        }

        if (clienteHoje == null) {
          return _buildRuaTrabalhoPlaceholder(cs, 'Nenhuma visita para hoje', 'As visitas de hoje aparecerão aqui');
        }

        final estabelecimento = (clienteHoje['estabelecimento'] as String?) ?? 'Estabelecimento';
        final endereco = (clienteHoje['endereco'] as String?) ?? 'Endereço';
        final cidade = (clienteHoje['cidade'] as String?) ?? '';
        final estado = (clienteHoje['estado'] as String?) ?? '';
        final enderecoCompleto = '$endereco, $cidade - $estado';

        return GestureDetector(
          onTap: () => _abrirNoGPS(enderecoCompleto, estabelecimento),
          child: _buildRuaTrabalhoReal(cs, estabelecimento, enderecoCompleto),
        );
      },
    );
  }

  Widget _buildRuaTrabalhoPlaceholder(ColorScheme cs, String titulo, String subtitulo) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: cs.surfaceVariant, borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.info_outline, color: cs.onSurfaceVariant, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface,
                        )),
                const SizedBox(height: 2),
                Text(
                  subtitulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuaTrabalhoReal(ColorScheme cs, String estabelecimento, String localizacao) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.primaryContainer.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.primaryContainer.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.flag_rounded, color: cs.onPrimary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HOJE - $estabelecimento',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    localizacao,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Toque para abrir no GPS',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.primary.withOpacity(0.3)),
              ),
              child: Text('PRIORIDADE',
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      )),
            ),
          ],
        ),
      ),
    );
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
              cargo: 'Consultor',
              tabsNoAppBar: false,
            ),
          ),
        ),
        // Home sem rolagem; rolagem só nas tabs
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              _buildRuaTrabalhoCard(),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, cst) {
                  final itemWidth = (cst.maxWidth - 10) / 2;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: itemWidth,
                        child: _metricCard(
                          title: 'Clientes',
                          value: _totalClientes.toString(),
                          icon: Icons.people_alt,
                          color: Colors.blue,
                          subtitle: 'Total cadastrados',
                        ),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: _metricCard(
                          title: 'Visitas Hoje',
                          value: _totalVisitasHoje.toString(),
                          icon: Icons.place,
                          color: Colors.green,
                          subtitle: 'Agendadas para hoje',
                        ),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: _metricCard(
                          title: 'Alertas',
                          value: _totalAlertas.toString(),
                          icon: Icons.notifications_active,
                          color: Colors.orange,
                          subtitle: 'Visitas vencidas',
                        ),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: _metricCard(
                          title: 'Finalizados',
                          value: _totalFinalizados.toString(),
                          icon: Icons.check_circle,
                          color: Colors.black,
                          subtitle: 'Visitas concluídas',
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                elevation: 2,
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
                    Tab(text: 'Minhas Visitas'),
                    Tab(text: 'Cadastrar Cliente'),
                    Tab(text: 'Meus Clientes'),
                    Tab(text: 'Exportar Dados'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  children: [
                    const MinhasVisitasTab(),
                    CadastrarCliente(onClienteCadastrado: _onClienteCadastrado),
                    MeusClientesTab(onClienteRemovido: _loadStats),
                    ExportarDadosTab(clientes: _clientes),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: SizedBox(
        height: 72,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: color.withOpacity(0.12),
                child: Icon(icon, color: color, size: 17),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: IntrinsicHeight(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 2),
                        Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 1),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 10.5, color: Colors.black.withOpacity(0.6)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
