import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
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
      Map<String, dynamic>? doc = await _client
          .from('consultores')
          .select('id, uid, nome')
          .eq('id', user.id)
          .maybeSingle();

      if (doc == null) {
        doc = await _client
            .from('consultores')
            .select('id, uid, nome')
            .eq('uid', user.id)
            .maybeSingle();
      }

      final nomeTabela = (doc?['nome'] as String?)?.trim() ?? '';
      final nomeAuth = (user.userMetadata?['name'] as String?)?.trim() ?? '';
      final nomeEscolhido =
          nomeTabela.isNotEmpty ? nomeTabela : (nomeAuth.isNotEmpty ? nomeAuth : 'Consultor');

      if (mounted) setState(() => _userName = _formatarNome(nomeEscolhido));
    } catch (_) {
      if (mounted) setState(() => _userName = 'Consultor');
    }
  }

  Future<void> _loadStats() async {
    final user = _client.auth.currentSession?.user;
    if (user == null || !mounted) return;
    final uid = user.id;

    final rows = await _client.from('clientes').select('*').eq('consultor_uid_t', uid);
    final clientes =
        (rows as List).map((m) => Cliente.fromMap(m as Map<String, dynamic>)).toList();

    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);

    final visitasHoje = clientes
        .where((c) {
          final d = c.dataVisita;
          return d.year == hoje.year && d.month == hoje.month && d.day == hoje.day;
        })
        .length;

    final alertas = clientes
        .where((c) {
          final d = DateTime(c.dataVisita.year, c.dataVisita.month, c.dataVisita.day);
          return d.isBefore(hoje);
        })
        .length;

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

  void _onClienteCadastrado() => _loadStats();

  Future<void> _copiarEndereco(String texto) async {
    await Clipboard.setData(ClipboardData(text: texto));
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Endereço copiado: $texto'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _abrirNoGoogleMaps(String endereco) async {
    final q = Uri.encodeComponent(endereco.trim());
    final androidGeo = Uri.parse('geo:0,0?q=$q');
    final androidWeb = Uri.parse('https://maps.google.com/?q=$q');
    final iosGmm = Uri.parse('comgooglemaps://?q=$q');
    final iosApple = Uri.parse('http://maps.apple.com/?q=$q');

    try {
      final platform = Theme.of(context).platform;

      if (platform == TargetPlatform.android) {
        if (await canLaunchUrl(androidGeo)) {
          await launchUrl(androidGeo);
          return;
        }
        if (await canLaunchUrl(androidWeb)) {
          await launchUrl(androidWeb, mode: LaunchMode.externalApplication);
          return;
        }
      } else if (platform == TargetPlatform.iOS) {
        if (await canLaunchUrl(iosGmm)) {
          await launchUrl(iosGmm);
          return;
        }
        if (await canLaunchUrl(iosApple)) {
          await launchUrl(iosApple);
          return;
        }
      }

      final web = Uri.parse('https://www.google.com/maps/search/?api=1&query=$q');
      final ok = await launchUrl(web, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o Maps'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao abrir o Maps: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Stream<List<Map<String, dynamic>>> _streamClientes() {
    final user = _client.auth.currentSession?.user;
    if (user == null) return const Stream<List<Map<String, dynamic>>>.empty();

    return _client
        .from('clientes')
        .select(
            'id, estabelecimento, endereco, logradouro, numero, cidade, estado, data_visita, hora_visita, consultor_uid_t')
        .eq('consultor_uid_t', user.id)
        .order('data_visita', ascending: true)
        .asStream();
  }

  Widget _buildRuaTrabalhoCard() {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFFAF1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFDCEFE1)),
                  ),
                  child: const Icon(Icons.flag, size: 12, color: Color(0xFF3CB371)),
                ),
                const SizedBox(width: 4),
                const Expanded(
                  child: Text(
                    'Rua de Trabalho - Hoje',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 78),
              child: _buildRuaTrabalhoHoje(),
            ),
          ],
        ),
      ),
    );
  }

  String _formatHoraHoje(Map<String, dynamic> clienteHoje) {
    final dataStr = clienteHoje['data_visita']?.toString();
    final horaStr = clienteHoje['hora_visita']?.toString();
    if (dataStr == null || dataStr.isEmpty) return '';
    try {
      DateTime data = DateTime.parse(dataStr);
      if (horaStr != null && horaStr.isNotEmpty) {
        final parts = horaStr.split(':');
        int parsePart(int idx) => (idx < parts.length) ? int.tryParse(parts[idx]) ?? 0 : 0;
        data = DateTime(data.year, data.month, data.day, parsePart(0), parsePart(1), parsePart(2));
        return DateFormat('HH:mm').format(data);
      }
      final embutida = DateFormat('HH:mm').format(data);
      return embutida != '00:00' ? embutida : '';
    } catch (_) {
      return '';
    }
  }

  DateTime _composeToday(DateTime data, String? hora) {
    if (hora == null || hora.isEmpty) {
      return DateTime(data.year, data.month, data.day);
    }
    final parts = hora.split(':');
    int parsePart(int idx) => (idx < parts.length) ? int.tryParse(parts[idx]) ?? 0 : 0;
    final h = parsePart(0);
    final m = parsePart(1);
    final s = parsePart(2);
    return DateTime(data.year, data.month, data.day, h, m, s);
  }

  int _safeCompare(Map<String, dynamic> a, Map<String, dynamic> b) {
    DateTime? parseDate(Map<String, dynamic> r) {
      final s = r['data_visita']?.toString();
      if (s == null || s.isEmpty) return null;
      try {
        return DateTime.parse(s);
      } catch (_) {
        return null;
      }
    }

    final da = parseDate(a);
    final db = parseDate(b);
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;

    final ta = _composeToday(da, a['hora_visita']?.toString());
    final tb = _composeToday(db, b['hora_visita']?.toString());
    return ta.compareTo(tb);
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
          return _buildRuaTrabalhoPlaceholder(
              cs, 'Nenhuma visita hoje', 'Cadastre clientes para ver as visitas aqui');
        }

        final lista = snapshot.data!;
        final now = DateTime.now();
        final hoje = DateTime(now.year, now.month, now.day);

        final deHoje = <Map<String, dynamic>>[];
        for (final row in lista) {
          final s = row['data_visita']?.toString();
          if (s == null || s.isEmpty) continue;
          try {
            final dt = DateTime.parse(s);
            final d = DateTime(dt.year, dt.month, dt.day);
            if (d == hoje) deHoje.add(row);
          } catch (_) {}
        }

        if (deHoje.isEmpty) {
          return _buildRuaTrabalhoPlaceholder(cs, 'Nenhuma visita para hoje', 'As visitas de hoje aparecerão aqui');
        }

        deHoje.sort(_safeCompare);
        final clienteHoje = deHoje.first;

        final estabelecimento =
            (clienteHoje['estabelecimento'] as String?)?.trim() ?? 'Estabelecimento';
        final tipoAbrev = (clienteHoje['logradouro'] as String?)?.trim() ?? '';
        final nomeVia = (clienteHoje['endereco'] as String?)?.trim() ?? '';
        final numero = (clienteHoje['numero']?.toString() ?? '').trim();
        final cidade = (clienteHoje['cidade'] as String?)?.trim() ?? '';
        final estado = (clienteHoje['estado'] as String?)?.trim() ?? '';
        final horaHHmm = _formatHoraHoje(clienteHoje);

        final enderecoCompleto = [
          [if (tipoAbrev.isNotEmpty) tipoAbrev, if (nomeVia.isNotEmpty) nomeVia]
              .where((e) => e.isNotEmpty)
              .join(' '),
          if (numero.isNotEmpty) numero,
          if (cidade.isNotEmpty || estado.isNotEmpty) '$cidade - $estado',
        ].where((e) => e.isNotEmpty).join(', ');

        final tituloLinha =
            horaHHmm.isNotEmpty ? 'HOJE $horaHHmm - $estabelecimento' : 'HOJE - $estabelecimento';

        return GestureDetector(
          onTap: () => _abrirNoGoogleMaps(enderecoCompleto),
          onLongPress: () => _copiarEndereco(enderecoCompleto),
          child: _buildRuaTrabalhoReal(cs, tituloLinha, enderecoCompleto),
        );
      },
    );
  }

  Widget _buildRuaTrabalhoPlaceholder(ColorScheme cs, String titulo, String subtitulo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outline.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration:
                BoxDecoration(color: cs.surfaceVariant, borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.info_outline, color: cs.onSurfaceVariant, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuaTrabalhoReal(ColorScheme cs, String tituloLinha, String localizacao) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: cs.primaryContainer.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.primaryContainer.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.flag_rounded, color: cs.onPrimary, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tituloLinha,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                  ),
                  Text(
                    localizacao,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  Text(
                    'Toque para abrir no Maps',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.primary.withOpacity(0.25)),
              ),
              child: Text(
                'PRIORIDADE',
                maxLines: 1,
                overflow: TextOverflow.fade,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
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
              hideAvatar: true,
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              _buildRuaTrabalhoCard(),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, cst) {
                  const gutter = 10.0;
                  final itemWidth = (cst.maxWidth - gutter) / 2;
                  return Wrap(
                    spacing: gutter,
                    runSpacing: gutter,
                    children: [
                      SizedBox(
                        width: itemWidth,
                        child: _metricCard(
                          title: 'Clientes',
                          value: _totalClientes.toString(),
                          icon: Icons.people_alt,
                          color: Colors.blue,
                          subtitle: 'Total cadastrados',
                          dense: true,
                          alignRightValue: true,
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
                          dense: true,
                          alignRightValue: true,
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
                          dense: true,
                          alignRightValue: true,
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
                          dense: true,
                          alignRightValue: true,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              Material(
                color: const Color(0xFFdcddde),
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
                    Tab(text: 'Visitas'),
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
    bool dense = false,
    bool alignRightValue = true,
  }) {
    final double h = dense ? 56 : 72;
    final EdgeInsets pad = dense
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 10);
    final double iconSize = dense ? 16 : 18;
    final double avatarRadius = dense ? 13 : 16;
    final double titleSize = dense ? 11 : 12.5;
    final double valueSize = dense ? 18 : 20;
    final double subtitleSize = dense ? 10 : 11;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        height: h,
        child: Padding(
          padding: pad,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: avatarRadius,
                backgroundColor: color.withOpacity(0.12),
                child: Icon(icon, color: color, size: iconSize),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: titleSize),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: subtitleSize,
                          color: Colors.black.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 24),
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: valueSize,
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
