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
      // Tabela correta: consultores
      final doc = await _client
          .from('consultores')
          .select('nome, email')
          .eq('id', user.id)
          .maybeSingle();

      if (doc != null) {
        final nomeCompleto = (doc['nome'] as String?) ?? '';
        if (nomeCompleto.isNotEmpty) {
          if (mounted) {
            setState(() => _userName = _formatarNome(nomeCompleto));
          }
          return;
        }
        final email = (doc['email'] as String?) ?? user.email ?? '';
        if (email.isNotEmpty && mounted) {
          setState(() => _userName = email.split('@').first);
          return;
        }
      }

      final email = user.email ?? '';
      if (email.isNotEmpty && mounted) {
        setState(() => _userName = email.split('@').first);
        return;
      }

      if (mounted) setState(() => _userName = 'Consultor');
    } catch (e) {
      print('❌ Erro ao carregar nome do consultor: $e');
      if (mounted) setState(() => _userName = 'Consultor');
    }
  }

  Future<void> _loadStats() async {
    final user = _client.auth.currentSession?.user;
    if (user == null || !mounted) return;
    final uid = user.id;

    final rows = await _client
        .from('clientes')
        .select('*')
        .eq('consultor_uid', uid);

    final clientes = (rows as List)
        .map((m) => Cliente.fromMap(m as Map<String, dynamic>))
        .toList();

    final hoje = DateTime.now();
    final visitasHoje = clientes.where((c) {
      final dataVisita = c.dataVisita;
      return dataVisita.year == hoje.year &&
          dataVisita.month == hoje.month &&
          dataVisita.day == hoje.day;
    }).length;

    final alertas = clientes.where((c) => c.dataVisita.isBefore(hoje)).length;

    if (mounted) {
      setState(() {
        _clientes = clientes;
        _totalClientes = clientes.length;
        _totalVisitasHoje = visitasHoje;
        _totalAlertas = alertas;
      });
    }
  }

  void _onClienteCadastrado() {
    _loadStats();
  }

  Future<void> _abrirNoGPS(String endereco, String estabelecimento) async {
    final encodedEndereco = Uri.encodeComponent(endereco);

    final apps = [
      {
        'nome': 'Google Maps',
        'icone': Icons.map_rounded,
        'cor': Colors.red,
        'url': 'https://www.google.com/maps/search/?api=1&query=$encodedEndereco',
      },
      {
        'nome': 'Waze',
        'icone': Icons.directions_car_rounded,
        'cor': Colors.blue,
        'url': 'https://waze.com/ul?q=$encodedEndereco&navigate=yes',
      },
      {
        'nome': 'Apple Maps',
        'icone': Icons.location_on_rounded,
        'cor': Colors.black,
        'url': 'https://maps.apple.com/?q=$encodedEndereco',
      },
    ];

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Icon(Icons.place_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Abrir localização',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 18,
                                      color: Colors.grey[800])),
                              const SizedBox(height: 2),
                              Text(
                                estabelecimento,
                                style: TextStyle(color: Colors.grey[600], fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.location_on_outlined, color: Colors.grey[600], size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              endereco,
                              style: TextStyle(color: Colors.grey[700], fontSize: 14),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    ...apps.map((app) => Column(
                          children: [
                            ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: app['cor'] as Color,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(app['icone'] as IconData, color: Colors.white, size: 20),
                              ),
                              title: Text(
                                app['nome'] as String,
                                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                              ),
                              trailing: Icon(Icons.arrow_forward_ios_rounded,
                                  color: Colors.grey[400], size: 16),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                              onTap: () async {
                                Navigator.pop(context);
                                await _launchUrl(app['url'] as String);
                              },
                            ),
                            if (app != apps.last)
                              Divider(height: 1, color: Colors.grey[200], indent: 56),
                          ],
                        )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                title: const Text('Cancelar',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 16, color: Color(0xFF128C7E))),
                onTap: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Não foi possível abrir o aplicativo'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  Widget _buildRuaTrabalhoHoje() {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getMeusClientesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildRuaTrabalhoPlaceholder(cs, 'Carregando...', 'Buscando dados do banco');
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildRuaTrabalhoPlaceholder(
              cs, 'Nenhuma visita hoje', 'Cadastre clientes para ver as visitas aqui');
        }

        final clientes = snapshot.data!;
        final hoje = DateTime.now();
        final hojeInicio = DateTime(hoje.year, hoje.month, hoje.day);
        final hojeFim = DateTime(hoje.year, hoje.month, hoje.day, 23, 59, 59);

        Map<String, dynamic>? clienteHoje;

        for (final data in clientes) {
          final dataVisitaStr = data['data_visita']?.toString();
          if (dataVisitaStr != null) {
            try {
              final dataVisita = DateTime.parse(dataVisitaStr);
              if (dataVisita.isAfter(hojeInicio) && dataVisita.isBefore(hojeFim)) {
                clienteHoje = data;
                break;
              }
            } catch (_) {}
          }
        }

        if (clienteHoje == null) {
          return _buildRuaTrabalhoPlaceholder(
              cs, 'Nenhuma visita para hoje', 'As visitas de hoje aparecerão aqui');
        }

        final estabelecimento = clienteHoje['estabelecimento'] ?? 'Estabelecimento';
        final endereco = clienteHoje['endereco'] ?? 'Endereço';
        final cidade = clienteHoje['cidade'] ?? '';
        final estado = clienteHoje['estado'] ?? '';
        final enderecoCompleto = '$endereco, $cidade - $estado';

        return GestureDetector(
          onTap: () => _abrirNoGPS(enderecoCompleto, estabelecimento),
          child: _buildRuaTrabalhoReal(cs, estabelecimento, enderecoCompleto),
        );
      },
    );
  }

  Stream<List<Map<String, dynamic>>> _getMeusClientesStream() {
    final user = _client.auth.currentSession?.user;
    if (user == null) {
      return const Stream<List<Map<String, dynamic>>>.empty();
    }

    return _client
        .from('clientes')
        .select('id, estabelecimento, endereco, cidade, estado, data_visita, consultor_uid')
        .eq('consultor_uid', user.id)
        .order('data_visita', ascending: true)
        .asStream();
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
            decoration:
                BoxDecoration(color: cs.surfaceVariant, borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.info_outline, color: cs.onSurfaceVariant, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w500, color: cs.onSurface)),
                const SizedBox(height: 4),
                Text(subtitulo,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: cs.onSurfaceVariant)),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('HOJE - $estabelecimento',
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600, color: cs.onSurface)),
                  const SizedBox(height: 4),
                  Text(localizacao,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text('Toque para abrir no GPS',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: cs.primary, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.primary.withOpacity(0.3)),
              ),
              child: Text('PRIORIDADE',
                  style:
                      Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w600)),
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
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              _buildRuaTrabalhoCard(),
              const SizedBox(height: 10),
              _proximasVisitasCard(),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _statCardIcon(title: 'Clientes', value: _totalClientes.toString(), icon: Icons.people_alt, color: Colors.blue),
                  _statCardIcon(title: 'Visitas Hoje', value: _totalVisitasHoje.toString(), icon: Icons.place, color: Colors.green),
                  _statCardIcon(title: 'Alertas', value: _totalAlertas.toString(), icon: Icons.notifications_active, color: Colors.orange),
                ],
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

  Widget _proximasVisitasCard() {
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
                  child: const Icon(Icons.place, size: 13, color: Color(0xFF3CB371)),
                ),
                const SizedBox(width: 4),
                const Expanded(
                  child: Text('Próximas Visitas Programadas',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text('Ruas designadas pelo gestor para os próximos dias',
                style: TextStyle(color: Colors.black.withOpacity(0.6), fontSize: 11)),
            const SizedBox(height: 4),
            ListTile(
              leading: Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F5FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.black12),
                ),
                child: const Icon(Icons.place_outlined, color: Color(0xFF2F6FED), size: 16),
              ),
              title: const Text('Av. Principal, Bairro Comercial', style: TextStyle(fontSize: 13)),
              subtitle: const Text('qui, 18 de setembro de 2025', style: TextStyle(fontSize: 11)),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(4)),
                child: const Text('Hoje', style: TextStyle(color: Colors.white, fontSize: 11)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
              dense: true,
              visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuaTrabalhoCard() {
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
                  child: Text('Rua de Trabalho - Hoje',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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

  Widget _statCardIcon({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: color.withOpacity(0.12),
                    child: Icon(icon, color: color, size: 16),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(title, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}
