import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/widgets.dart' show Directionality;
import '../widgets/custom_navbar.dart';
import 'meus_clientes_tab.dart';
import 'minhas_visitas_tab.dart';
import 'exportar_dados_tab.dart';
import 'cadastrar_cliente.dart';
import '../../models/cliente.dart';
import '../../services/cliente_service.dart';

const Color kDashboardCardBackground = Color(0xFFE0E0E0);
const Color kDashboardBorder = Color(0xFFE5E7EB);

class AdaptiveValueText extends StatelessWidget {
  final String valueText;
  final String? compactFallback;
  final double fontSize;
  final FontWeight fontWeight;
  final TextAlign textAlign;
  final bool preferCompactAboveThousand;

  const AdaptiveValueText({
    super.key,
    required this.valueText,
    this.compactFallback,
    this.fontSize = 20,
    this.fontWeight = FontWeight.w800,
    this.textAlign = TextAlign.right,
    this.preferCompactAboveThousand = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, cst) {
      final textStyle = TextStyle(fontSize: fontSize, fontWeight: fontWeight);

      if (preferCompactAboveThousand && compactFallback != null) {
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(
            compactFallback!,
            textAlign: textAlign,
            style: textStyle,
          ),
        );
      }

      final tp = TextPainter(
        text: TextSpan(text: valueText, style: textStyle),
        maxLines: 1,
        textDirection: Directionality.of(context),
      )..layout(maxWidth: cst.maxWidth);

      if (tp.didExceedMaxLines && compactFallback != null) {
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(
            compactFallback!,
            textAlign: textAlign,
            style: textStyle,
          ),
        );
      }

      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Text(
          valueText,
          textAlign: textAlign,
          style: textStyle,
        ),
      );
    });
  }
}

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
  int _totalFinalizados = 0;
  List<Cliente> _clientes = [];

  double _valorMes = 0.0;
  final NumberFormat _brl =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  String _userName = 'Consultor';
  String _matricula = '';
  DateTime _dataCadastro = DateTime.now();

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
          .select('id, uid, nome, matricula, data_cadastro')
          .eq('id', user.id)
          .maybeSingle();

      doc ??= await _client
          .from('consultores')
          .select('id, uid, nome, matricula, data_cadastro')
          .eq('uid', user.id)
          .maybeSingle();

      final nomeTabela = (doc?['nome'] as String?)?.trim() ?? '';
      final nomeAuth = (user.userMetadata?['name'] as String?)?.trim() ?? '';
      final nomeEscolhido = nomeTabela.isNotEmpty
          ? nomeTabela
          : (nomeAuth.isNotEmpty ? nomeAuth : 'Consultor');

      final matricula = (doc?['matricula'] as String?)?.trim() ?? '';
      final dataCadastroIso = doc?['data_cadastro']?.toString();

      DateTime? parsed;
      if (dataCadastroIso != null && dataCadastroIso.isNotEmpty) {
        parsed = DateTime.tryParse(dataCadastroIso);
      }

      if (mounted) {
        setState(() {
          _userName = _formatarNome(nomeEscolhido);
          _matricula = matricula;
          _dataCadastro = parsed ?? _dataCadastro;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _userName = 'Consultor';
          _matricula = '';
        });
      }
    }
  }

  Future<void> _loadStats() async {
    final user = _client.auth.currentSession?.user;
    if (user == null || !mounted) return;
    final uid = user.id;

    final rows = await _client
        .from('clientes')
        .select('*')
        .eq('consultor_uid_t', uid) as List;

    final clientes =
        rows.map((m) => Cliente.fromMap(m as Map<String, dynamic>)).toList();

    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);

    final visitasHoje = clientes.where((c) {
      final d = c.dataVisita;
      return d.year == hoje.year &&
          d.month == hoje.month &&
          d.day == hoje.day;
    }).length;

    final inicioMes = DateTime(agora.year, agora.month, 1);
    final proximoMes = DateTime(agora.year, agora.month + 1, 1);
    double somaMes = 0.0;

    for (final row in rows) {
      final map = row as Map<String, dynamic>;
      final dataStr = map['data_visita']?.toString();
      if (dataStr == null || dataStr.isEmpty) continue;

      DateTime? d;
      try {
        d = DateTime.parse(dataStr);
      } catch (_) {
        continue;
      }

      final dentroDoMes = !d.isBefore(inicioMes) && d.isBefore(proximoMes);
      if (!dentroDoMes) continue;

      final raw = map['valor_proposta'];
      double v = 0.0;
      if (raw is num) {
        v = raw.toDouble();
      } else if (raw != null) {
        v = double.tryParse(raw.toString()) ?? 0.0;
      }
      somaMes += v;
    }

    final finalizados = rows.where((row) {
      final status =
          (row as Map<String, dynamic>)['status_negociacao'] as String?;
      return status != null && status.toLowerCase() == 'fechada';
    }).length;

    if (!mounted) return;
    setState(() {
      _clientes = clientes;
      _totalClientes = clientes.length;
      _totalVisitasHoje = visitasHoje;
      _valorMes = somaMes;
      _totalFinalizados = finalizados;
    });
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

      final web = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$q');
      final ok =
          await launchUrl(web, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Não foi possível abrir o Maps'),
              backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Erro ao abrir o Maps: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  Stream<List<Map<String, dynamic>>> _streamClientes() {
    final user = _client.auth.currentSession?.user;
    if (user == null) {
      return const Stream<List<Map<String, dynamic>>>.empty();
    }

    return _client
        .from('clientes')
        .select(
            'id, estabelecimento, endereco, logradouro, numero, cidade, estado, data_visita, hora_visita, consultor_uid_t')
        .eq('consultor_uid_t', user.id)
        .order('data_visita', ascending: true)
        .asStream();
  }

  // ==== CARD RUA DE TRABALHO (COM DESTAQUE) ====

  Widget _buildRuaTrabalhoCard() {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 6,
      shadowColor: Colors.black26,
      color: kDashboardCardBackground,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(
          color: kDashboardBorder,
          width: 1,
        ),
      ),
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
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: kDashboardBorder),
                  ),
                  child: const Icon(
                    Icons.flag,
                    size: 12,
                    color: Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 4),
                const Expanded(
                  child: Text(
                    'Rua de Trabalho - Hoje',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
        int parsePart(int idx) =>
            (idx < parts.length) ? int.tryParse(parts[idx]) ?? 0 : 0;
        data = DateTime(data.year, data.month, data.day, parsePart(0),
            parsePart(1), parsePart(2));
        return DateFormat('HH:mm').format(data);
      }
      final embutida = DateFormat('HH:mm').format(data);
      return embutida != '00:00' ? embutida : '';
    } catch (_) {
      return '';
    }
  }

  DateTime _composeToday(DateTime data, String? hora) {
    if (hora is! String || hora.isEmpty) {
      return DateTime(data.year, data.month, data.day);
    }
    final parts = hora.split(':');
    int parsePart(int idx) =>
        (idx < parts.length) ? int.tryParse(parts[idx]) ?? 0 : 0;
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
          return _buildRuaTrabalhoPlaceholder(
              cs, 'Carregando...', 'Buscando dados do banco');
        }

        if (snapshot.hasError ||
            !snapshot.hasData ||
            snapshot.data!.isEmpty) {
          return _buildRuaTrabalhoPlaceholder(cs, 'Nenhuma visita hoje',
              'Cadastre clientes para ver as visitas aqui');
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
          return _buildRuaTrabalhoPlaceholder(cs, 'Nenhuma visita para hoje',
              'As visitas de hoje aparecerão aqui');
        }

        deHoje.sort(_safeCompare);
        final clienteHoje = deHoje.first;

        final estabelecimento =
            (clienteHoje['estabelecimento'] as String?)?.trim() ??
                'Estabelecimento';
        final tipoAbrev =
            (clienteHoje['logradouro'] as String?)?.trim() ?? '';
        final nomeVia =
            (clienteHoje['endereco'] as String?)?.trim() ?? '';
        final numero =
            (clienteHoje['numero']?.toString() ?? '').trim();
        final cidade =
            (clienteHoje['cidade'] as String?)?.trim() ?? '';
        final estado =
            (clienteHoje['estado'] as String?)?.trim() ?? '';
        final horaHHmm = _formatHoraHoje(clienteHoje);

        final enderecoCompleto = [
          [
            if (tipoAbrev.isNotEmpty) tipoAbrev,
            if (nomeVia.isNotEmpty) nomeVia
          ].where((e) => e.isNotEmpty).join(' '),
          if (numero.isNotEmpty) numero,
          if (cidade.isNotEmpty || estado.isNotEmpty)
            '$cidade - $estado',
        ].where((e) => e.isNotEmpty).join(', ');

        final tituloLinha = horaHHmm.isNotEmpty
            ? 'HOJE $horaHHmm - $estabelecimento'
            : 'HOJE - $estabelecimento';

        return GestureDetector(
          onTap: () => _abrirNoGoogleMaps(enderecoCompleto),
          onLongPress: () => _copiarEndereco(enderecoCompleto),
          child: _buildRuaTrabalhoReal(
              cs, tituloLinha, enderecoCompleto),
        );
      },
    );
  }

  Widget _buildRuaTrabalhoPlaceholder(
      ColorScheme cs, String titulo, String subtitulo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.info_outline,
              color: cs.onSurfaceVariant,
              size: 18,
            ),
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
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuaTrabalhoReal(
      ColorScheme cs, String tituloLinha, String localizacao) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Card(
        elevation: 2,
        shadowColor: Colors.black12,
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: kDashboardBorder, width: 1),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.flag_rounded,
                  color: cs.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      tituloLinha,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                    ),
                    Text(
                      localizacao,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                    Text(
                      'Toque para abrir no Maps',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: Text(
                  'PRIORIDADE',
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String abreviarBRL(num v) {
    final abs = v.abs();
    if (abs >= 1e9) {
      return 'R\$ ${(v / 1e9).toStringAsFixed(1)} bi';
    } else if (abs >= 1e6) {
      return 'R\$ ${(v / 1e6).toStringAsFixed(1)} mi';
    } else if (abs >= 1e3) {
      return 'R\$ ${(v / 1e3).toStringAsFixed(0)} mil';
    }
    return _brl.format(v);
  }

  String formatBRLSeguro(num v) => _brl.format(v);

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
              nomeCompleto: _userName,
              email: _client.auth.currentUser?.email ?? '',
              idUsuario: _client.auth.currentUser?.id ?? '',
              matricula: _matricula,
              dataCadastro: _dataCadastro,
              tabsNoAppBar: false,
              hideAvatar: false,
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
                  final isSmall =
                      MediaQuery.of(context).size.width < 400;
                  final gutter = isSmall ? 8.0 : 12.0;
                  final itemWidth =
                      (cst.maxWidth - 3 * gutter) / 2;

                  return Wrap(
                    spacing: gutter,
                    runSpacing: gutter + 4,
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
                        ),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: _metricCard(
                          title: 'Valor no mês',
                          value: _valorMes,
                          icon: Icons.account_balance_wallet_rounded,
                          color: Colors.orange,
                          subtitle: 'Propostas',
                          dense: true,
                          isCurrency: true,
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
                  labelStyle:
                      TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
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
    required dynamic value,
    required IconData icon,
    required Color color,
    String? subtitle,
    bool dense = false,
    bool isCurrency = false,
  }) {
    final EdgeInsets pad = EdgeInsets.symmetric(
      horizontal: dense ? 10 : 12,
      vertical: dense ? 8 : 9,
    );

    final double iconSize = dense ? 18 : 20;
    final double iconBoxSize = dense ? 26 : 28;
    final double valueSize = dense ? 17 : 18;
    final double titleSize = dense ? 12 : 13;
    final double subtitleSize = dense ? 11 : 12;

    String fullText;
    String? fallbackText;

    if (isCurrency && value is num) {
      fullText = formatBRLSeguro(value);
      fallbackText = abreviarBRL(value);
    } else {
      fullText = value.toString();
      fallbackText = null;
    }

    return Card(
      margin: EdgeInsets.zero,
      elevation: 6,
      shadowColor: Colors.black26,
      color: kDashboardCardBackground,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: kDashboardBorder, width: 1),
      ),
      child: Padding(
        padding: pad,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: iconBoxSize,
              height: iconBoxSize,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kDashboardBorder),
              ),
              child: Icon(
                icon,
                color: color,
                size: iconSize,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AdaptiveValueText(
                    valueText: fullText,
                    compactFallback: fallbackText,
                    fontSize: valueSize,
                    fontWeight: FontWeight.w800,
                    textAlign: TextAlign.left,
                    preferCompactAboveThousand: isCurrency,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: titleSize,
                      fontWeight: FontWeight.w600,
                      color: Colors.black.withOpacity(0.85),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: subtitleSize,
                        fontWeight: FontWeight.w400,
                        color: Colors.black.withOpacity(0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
