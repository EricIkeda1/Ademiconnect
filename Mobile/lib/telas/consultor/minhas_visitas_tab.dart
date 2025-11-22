import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

const kBg = Color(0xFFF7F8FA);
const kCard = Colors.white;
const kBorder = Color(0xFFE6E8EC);
const kTitle = Color(0xFF0F172A);
const kText = Color(0xFF475569);
const kMuted = Color(0xFF94A3B8);
const kPrimary = Color(0xFF0B5EA8);
const kSuccess = Color(0xFF2E7D32);
const kInfo = Color(0xFF1565C0);
const kAccent = Color(0xFF4F46E5);
const kWarn = Color(0xFFF57C00);
const kDanger = Color(0xFFD32F2F);

final DateFormat fmtHora = DateFormat('HH:mm');
final DateFormat fmtA = DateFormat('EEE, d MMM', 'pt_BR');
final DateFormat fmtB = DateFormat('EEE, d MMM y', 'pt_BR');

class VisitVM {
  final String id;
  final String estabelecimento;
  final String enderecoCompleto;
  final String dataFmt;
  final IconData icone;
  final String statusTxt;
  final Color corFundo;
  final Color corTexto;
  final String? negociacaoRaw;
  final String? valorPropostaFmt;

  const VisitVM({
    required this.id,
    required this.estabelecimento,
    required this.enderecoCompleto,
    required this.dataFmt,
    required this.icone,
    required this.statusTxt,
    required this.corFundo,
    required this.corTexto,
    this.negociacaoRaw,
    this.valorPropostaFmt,
  });
}

Widget padIcon({
  required IconData icon,
  Color? color,
  double size = 18,
  double box = 36,
  EdgeInsets padding = EdgeInsets.zero,
  Color? borderColor,
  Color? background,
}) {
  final c = color ?? kPrimary;
  return Container(
    width: box,
    height: box,
    padding: padding,
    decoration: BoxDecoration(
      color: (background ?? c.withOpacity(.10)),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: borderColor ?? kBorder),
    ),
    child: Center(child: Icon(icon, size: size, color: c)),
  );
}

class MinhasVisitasTab extends StatefulWidget {
  const MinhasVisitasTab({super.key});
  @override
  State<MinhasVisitasTab> createState() => MinhasVisitasTabState();
}

class MinhasVisitasTabState extends State<MinhasVisitasTab>
    with TickerProviderStateMixin {
  final SupabaseClient client = Supabase.instance.client;

  final TextEditingController searchCtrl = TextEditingController();
  String query = '';

  bool proxExpanded = false;
  bool todosExpanded = false;
  bool finExpanded = false;

  bool showChips = false;

  Timer? _debounceSearch;

  List<Map<String, dynamic>>? cacheProximas;
  List<Map<String, dynamic>>? cacheFinalizados;

  final Set<String> ruasTodas = {};
  String? ruaSelecionada;

  RealtimeChannel? chan;

  @override
  void initState() {
    super.initState();
    invalidateCaches();
    searchCtrl.addListener(() {
      _debounceSearch?.cancel();
      _debounceSearch = Timer(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        setState(() {
          query = searchCtrl.text.trim();
          showChips = FocusScope.of(context).hasFocus;
          invalidateCaches();
        });
      });
    });
    subscribeRealtime();
  }

  @override
  void dispose() {
    _debounceSearch?.cancel();
    searchCtrl.dispose();
    if (chan != null) client.removeChannel(chan!);
    super.dispose();
  }

  void subscribeRealtime() {
    chan = client
        .channel('realtime:clientes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'clientes',
          callback: (_) {
            if (mounted) setState(invalidateCaches);
          },
        )
        .subscribe();
  }

  void invalidateCaches() {
    cacheProximas = null;
    cacheFinalizados = null;
  }

  String normStatusNeg(dynamic raw) {
    final s0 = (raw?.toString() ?? '').trim().toLowerCase();
    return s0
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ç', 'c')
        .replaceAll('é', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('ú', 'u')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool isConexao(dynamic raw) {
    final s = normStatusNeg(raw);
    return s == 'conexao' || s.contains('novo') || s.contains('inicial');
  }

  bool isNegociacao(dynamic raw) {
    final s = normStatusNeg(raw);
    return s == 'negociacao' ||
        s.contains('em negociacao') ||
        s.contains('proposta enviada') ||
        s.contains('propostaenviada') ||
        s.contains('em andamento');
  }

  bool isFechado(dynamic raw) {
    final s = normStatusNeg(raw);
    return s == 'fechado' || s == 'fechada' || s.contains('venda');
  }

  DateTime? visitaDateTime(Map<String, dynamic> c) {
    final ds = c['data_visita']?.toString() ?? c['datavisita']?.toString() ?? '';
    if (ds.isEmpty) return null;
    try {
      DateTime d = DateTime.parse(ds).toLocal();
      final hs = c['hora_visita']?.toString() ?? c['horavisita']?.toString() ?? '';
      if (hs.isNotEmpty) {
        final p = hs.split(':');
        final h = p.isNotEmpty ? int.tryParse(p[0]) ?? 0 : 0;
        final m = p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0;
        final s = p.length > 2 ? int.tryParse(p[2]) ?? 0 : 0;
        d = DateTime(d.year, d.month, d.day, h, m, s);
      } else {
        d = DateTime(d.year, d.month, d.day, 23, 59, 59);
      }
      return d;
    } catch (_) {
      return null;
    }
  }

  bool isPassado(Map<String, dynamic> c) {
    final d = visitaDateTime(c);
    if (d == null) return false;
    final agora = DateTime.now();
    final hojeIni = DateTime(agora.year, agora.month, agora.day, 0, 0, 0);
    return d.isBefore(hojeIni);
  }

  bool matchProximas(Map<String, dynamic> c) {
    final s = c['status_negociacao'] ?? c['statusnegociacao'];
    return (isConexao(s) || isNegociacao(s)) && !isPassado(c);
  }

  bool matchFinalizadas(Map<String, dynamic> c) {
    final s = c['status_negociacao'] ?? c['statusnegociacao'];
    return isFechado(s);
  }

  int _rankNeg(String? raw) {
    final s = (raw ?? '').trim().toLowerCase();
    if (s == 'conexao' || s == 'novo' || s == 'inicial') return 0;
    if (s.contains('negociacao') || s.contains('andamento') || s.contains('proposta')) return 1;
    if (s == 'fechada' || s == 'fechado' || s == 'venda') return 99;
    return 2;
  }

  int _cmp(VisitVM a, VisitVM b) {
    final ra = _rankNeg(a.negociacaoRaw);
    final rb = _rankNeg(b.negociacaoRaw);
    if (ra != rb) return ra.compareTo(rb);
    return a.dataFmt.compareTo(b.dataFmt);
  }

  int compareVmPorNegociacaoDepoisData(VisitVM a, VisitVM b) => _cmp(a, b);

  Stream<List<Map<String, dynamic>>> get meusClientesStream {
    final user = client.auth.currentSession?.user;
    if (user == null) return const Stream<List<Map<String, dynamic>>>.empty();
    return client
        .from('clientes')
        .select(
            'id, nome, estabelecimento, endereco, logradouro, numero, bairro, cidade, estado, cep, data_visita, hora_visita, consultor_uid_t, status_negociacao, valor_proposta')
        .eq('consultor_uid_t', user.id)
        .order('data_visita', ascending: false)
        .order('hora_visita', ascending: false)
        .asStream();
  }

  Stream<List<Map<String, dynamic>>> get todasVisitasStream {
    return client
        .from('clientes')
        .select(
            'id, nome, estabelecimento, endereco, logradouro, numero, bairro, cidade, estado, cep, data_visita, hora_visita, consultor_uid_t, status_negociacao, valor_proposta')
        .order('data_visita', ascending: false)
        .order('hora_visita', ascending: false)
        .asStream();
  }

  Future<void> abrirNoGoogleMaps(String endereco, {String? nome}) async {
    final destino = nome != null && nome.trim().isNotEmpty
        ? '$nome - $endereco'
        : endereco;
    final q = Uri.encodeComponent(destino.trim());
    final platform = Theme.of(context).platform;

    final androidGeo = Uri.parse('geo:0,0?q=$q');
    final androidWeb = Uri.parse('https://maps.google.com/?q=$q');

    final iosGmm = Uri.parse('comgooglemaps://?q=$q');
    final iosApple = Uri.parse('http://maps.apple.com/?q=$q');

    try {
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
      await launchUrl(web, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  String formatarDataVisitaDT(DateTime? d) {
    if (d == null) return 'Data não informada';
    final hoje = DateTime.now();
    final amanha = DateTime(hoje.year, hoje.month, hoje.day + 1);
    final horaExibida = fmtHora.format(d);

    if (d.year == hoje.year && d.month == hoje.month && d.day == hoje.day) {
      return 'Hoje • $horaExibida';
    } else if (d.year == amanha.year &&
        d.month == amanha.month &&
        d.day == amanha.day) {
      return 'Amanhã • $horaExibida';
    } else {
      final base = d.year == hoje.year ? fmtA : fmtB;
      final s = base.format(d);
      return '${s[0].toUpperCase()}${s.substring(1)} • $horaExibida';
    }
  }

  Map<String, dynamic> determinarStatus(String? dataVisitaStr,
      {String? horaVisitaStr}) {
    if (dataVisitaStr == null || dataVisitaStr.isEmpty) {
      return {
        'icone': Icons.schedule_outlined,
        'texto': 'Agendado',
        'corFundo': kSuccess.withOpacity(.10),
        'corTexto': kSuccess,
      };
    }
    try {
      DateTime d = DateTime.parse(dataVisitaStr).toLocal();
      if (horaVisitaStr != null && horaVisitaStr.isNotEmpty) {
        final p = horaVisitaStr.split(':');
        int part(int i) => i < p.length ? int.tryParse(p[i]) ?? 0 : 0;
        d = DateTime(d.year, d.month, d.day, part(0), part(1), part(2));
      } else {
        d = DateTime(d.year, d.month, d.day, 23, 59, 59);
      }

      final agora = DateTime.now();
      final hojeInicio = DateTime(agora.year, agora.month, agora.day, 0, 0, 0);
      final hojeFim = DateTime(agora.year, agora.month, agora.day, 23, 59, 59);
      final ehHoje = (d.isAfter(hojeInicio) && d.isBefore(hojeFim)) ||
          d.isAtSameMomentAs(hojeInicio) ||
          d.isAtSameMomentAs(hojeFim);

      if (ehHoje) {
        return {
          'icone': Icons.flag_outlined,
          'texto': 'Hoje',
          'corFundo': kInfo.withOpacity(.10),
          'corTexto': kInfo,
        };
      } else if (d.isBefore(hojeInicio)) {
        return {
          'icone': Icons.check_circle_outline,
          'texto': 'Realizada',
          'corFundo': kText.withOpacity(.08),
          'corTexto': kText,
        };
      } else {
        return {
          'icone': Icons.schedule_outlined,
          'texto': 'Agendado',
          'corFundo': kSuccess.withOpacity(.10),
          'corTexto': kSuccess,
        };
      }
    } catch (_) {
      return {
        'icone': Icons.schedule_outlined,
        'texto': 'Agendado',
        'corFundo': kSuccess.withOpacity(.10),
        'corTexto': kSuccess,
      };
    }
  }

  Map<String, dynamic> statusNegociacaoChip(String? raw) {
    final s0 = (raw ?? '').trim().toLowerCase();
    final s = s0
        .replaceAll('ã', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ç', 'c')
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .trim();

    if (s == 'conexao' || s == 'novo' || s == 'inicial') {
      return {
        'icone': Icons.link_outlined,
        'texto': 'Conexão',
        'corFundo': kInfo.withOpacity(.10),
        'corTexto': kInfo,
      };
    }
    if (s == 'negociacao' ||
        s == 'em negociacao' ||
        s == 'proposta enviada' ||
        s == 'propostaenviada' ||
        s == 'em andamento') {
      return {
        'icone': Icons.handshake_outlined,
        'texto': 'Negociação',
        'corFundo': kWarn.withOpacity(.12),
        'corTexto': kWarn,
      };
    }
    if (s == 'fechada' || s == 'fechado' || s == 'venda') {
      return {
        'icone': Icons.check_circle_outline,
        'texto': 'Fechada',
        'corFundo': kDanger.withOpacity(.12),
        'corTexto': kDanger,
      };
    }
    if (s == 'perdido' || s == 'perda') {
      return {
        'icone': Icons.cancel_outlined,
        'texto': 'Perdido',
        'corFundo': kDanger.withOpacity(.12),
        'corTexto': kDanger,
      };
    }
    return {
      'icone': Icons.info_outline,
      'texto': 'Sem status',
      'corFundo': kText.withOpacity(.08),
      'corTexto': kText,
    };
  }

  String capitalize(String text) =>
      text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

  bool matchChipsRua(Map<String, dynamic> c) {
    if (ruaSelecionada == null || ruaSelecionada!.isEmpty) return true;
    final any = c['endereco'];
    final rua = any is String ? any : (any?.toString() ?? '');
    return rua.toLowerCase().contains(ruaSelecionada!.toLowerCase());
  }

  Widget chipsDeBusca() {
    if (!showChips) return const SizedBox.shrink();

    final termos = ruasTodas.toList()..sort();
    final visiveis =
        termos.where((t) => query.isEmpty || t.toLowerCase().contains(query.toLowerCase())).toList();

    if (visiveis.isEmpty) return const SizedBox.shrink();

    Widget buildChip(String t) {
      final selecionado = ruaSelecionada == t;
      return Material(
        color: selecionado ? kPrimary.withOpacity(.08) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () {
            if (!mounted) return;
            setState(() {
              if (ruaSelecionada != t) {
                ruaSelecionada = t;
                searchCtrl.text = t;
                query = t;
                showChips = false;
              } else {
                ruaSelecionada = null;
                searchCtrl.clear();
                query = '';
              }
              invalidateCaches();
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: selecionado ? kPrimary : kBorder),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              t,
              style: TextStyle(
                color: selecionado ? kPrimary : kText,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SizedBox(
        height: 160,
        child: ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: visiveis.length,
          itemBuilder: (context, index) =>
              Padding(padding: const EdgeInsets.only(bottom: 8), child: buildChip(visiveis[index])),
        ),
      ),
    );
  }

  InputDecoration obterDecoracaoCampo(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kPrimary, width: 2),
      ),
      suffixIcon: query.isEmpty
          ? const Icon(Icons.search, color: kMuted, size: 20)
          : IconButton(
              icon: const Icon(Icons.close, color: kMuted, size: 20),
              onPressed: () {
                searchCtrl.clear();
                _debounceSearch?.cancel();
                setState(() {
                  query = '';
                  ruaSelecionada = null;
                  showChips = false;
                  invalidateCaches();
                });
                FocusScope.of(context).unfocus();
              },
            ),
      labelStyle:
          const TextStyle(color: kText, fontSize: 13, fontWeight: FontWeight.w500),
      hintStyle: const TextStyle(color: kMuted, fontSize: 13),
    );
  }

  Widget cleanCard({required Widget child, EdgeInsets? padding, EdgeInsets? margin}) {
    return Container(
      margin: margin ?? const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: child,
    );
  }

  Widget buildHeader() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.calendar_month_outlined,
                color: scheme.onPrimaryContainer, size: 28),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Visitas',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: kTitle,
                      letterSpacing: -0.2,
                    )),
                SizedBox(height: 2),
                Text('Agenda e acompanhamento',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: kText,
                      fontWeight: FontWeight.w400,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget skeletonShimmer({required Widget child}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      builder: (context, value, _) {
        final shimmer = LinearGradient(
          colors: const [Color(0xFFEFF2F7), Color(0xFFF7F8FA), Color(0xFFEFF2F7)],
          stops: const [0.1, 0.5, 0.9],
          begin: Alignment(-1 - value, -0.3),
          end: Alignment(1 + value, 0.3),
        );
        return ShaderMask(
          shaderCallback: (rect) => shimmer.createShader(rect),
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
    );
  }

  Widget skeletonBar({double height = 12, double width = double.infinity, BorderRadius? radius}) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: const Color(0xFFEFF2F7),
        borderRadius: radius ?? BorderRadius.circular(6),
      ),
    );
  }

  Widget skeletonVisitaItem({Key? key}) {
    return KeyedSubtree(
      key: key ?? UniqueKey(),
      child: cleanCard(
        padding: const EdgeInsets.all(14),
        child: skeletonShimmer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Expanded(child: SizedBox()),
                Container(
                  height: 22,
                  width: 90,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF2F7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              skeletonBar(height: 12, width: 220),
              const SizedBox(height: 6),
              skeletonBar(height: 12, width: 160),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                skeletonBar(height: 12, width: 100),
                skeletonBar(height: 30, width: 80, radius: BorderRadius.circular(8)),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  VisitVM toVM(Map<String, dynamic> c) {
    final tipo = (c['logradouro'] ?? '').toString().trim();
    final via = (c['endereco'] ?? '').toString().trim();
    final numeroStr = c['numero'] == null ? '' : c['numero'].toString().trim();
    final cidade = (c['cidade'] ?? '').toString().trim();
    final estado = (c['estado'] ?? '').toString().trim();

    final linha1 = [
      if (tipo.isNotEmpty) tipo,
      if (via.isNotEmpty) via,
    ].join(tipo.isNotEmpty ? ' ' : '');
    final linha1Num = [
      if (linha1.isNotEmpty) linha1,
      if (numeroStr.isNotEmpty) numeroStr,
    ].join(numeroStr.isNotEmpty ? ', ' : '');

    final enderecoCompleto = [
      if (linha1Num.isNotEmpty) linha1Num,
      if (cidade.isNotEmpty && estado.isNotEmpty) '$cidade - $estado',
    ].where((e) => e.isNotEmpty).join(', ');

    final ds = (c['data_visita'] ?? '').toString();
    final hs = (c['hora_visita'] ?? '').toString();

    DateTime? d;
    if (ds.isNotEmpty) {
      try {
        d = DateTime.parse(ds).toLocal();
      } catch (_) {}
    }
    if (d != null) {
      if (hs.isNotEmpty) {
        final p = hs.split(':');
        int part(int i) => i < p.length ? int.tryParse(p[i]) ?? 0 : 0;
        d = DateTime(d.year, d.month, d.day, part(0), part(1), part(2));
      } else {
        d = DateTime(d.year, d.month, d.day, 23, 59, 59);
      }
    }

    final dataFmt = formatarDataVisitaDT(d);
    final s = determinarStatus(ds, horaVisitaStr: hs);

    String? valorFmt;
    final vp = c['valor_proposta'];
    if (vp != null) {
      try {
        final num n = vp is num ? vp : num.parse(vp.toString());
        valorFmt = NumberFormat.simpleCurrency(locale: 'pt_BR').format(n);
      } catch (_) {
        final s2 = vp.toString().trim();
        if (s2.isNotEmpty) valorFmt = s2;
      }
    }

    return VisitVM(
      id: (c['id'] ?? '').toString(),
      estabelecimento: ((c['estabelecimento'] ?? '').toString().trim().isEmpty)
          ? 'Estabelecimento não informado'
          : (c['estabelecimento'] ?? '').toString().trim(),
      enderecoCompleto: enderecoCompleto,
      dataFmt: dataFmt,
      icone: s['icone'] as IconData,
      statusTxt: s['texto'] as String,
      corFundo: s['corFundo'] as Color,
      corTexto: s['corTexto'] as Color,
      negociacaoRaw: (c['status_negociacao'] as String?)?.trim(),
      valorPropostaFmt: valorFmt,
    );
  }

  VisitVM toVMParaTodas(Map<String, dynamic> c) => toVM(c);

  Widget chipNegociacaoReadonly(VisitVM vm) {
    final m = statusNegociacaoChip(vm.negociacaoRaw);
    final Color corTxt = m['corTexto'] as Color;
    final Color corF = m['corFundo'] as Color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: corF,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: corTxt.withOpacity(.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(m['icone'] as IconData, size: 14, color: corTxt),
          const SizedBox(width: 6),
          Text(
            m['texto'] as String,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: corTxt),
          ),
        ],
      ),
    );
  }

  Widget buildVisitaVM(
    VisitVM vm, {
    bool mostrarRota = true,
    bool mostrarTitulo = true,
    bool mostrarProposta = true,
  }) {
    return cleanCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            if (mostrarTitulo)
              Expanded(
                child: Text(
                  vm.estabelecimento,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kTitle),
                ),
              )
            else
              const Expanded(child: SizedBox()),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: vm.corFundo,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: vm.corTexto.withOpacity(.25)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(vm.icone, size: 14, color: vm.corTexto),
                const SizedBox(width: 6),
                Text(
                  vm.statusTxt,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: vm.corTexto),
                ),
              ]),
            ),
            const SizedBox(width: 6),
            chipNegociacaoReadonly(vm),
          ]),
          if (vm.enderecoCompleto.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              padIcon(
                  icon: Icons.location_on_outlined,
                  color: kMuted,
                  size: 16,
                  box: 28,
                  background: kBg,
                  borderColor: kBorder),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  vm.enderecoCompleto,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: kText, height: 1.4),
                ),
              ),
            ]),
          ],
          const SizedBox(height: 10),
          Row(children: [
            padIcon(
                icon: Icons.access_time,
                color: kMuted,
                size: 16,
                box: 28,
                background: kBg,
                borderColor: kBorder),
            const SizedBox(width: 8),
            Text(vm.dataFmt,
                style: const TextStyle(
                    fontSize: 13, color: kTitle, fontWeight: FontWeight.w500)),
            const Spacer(),
            if (mostrarRota)
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: kPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: kBorder)),
                ),
                onPressed: () => abrirNoGoogleMaps(
                  vm.enderecoCompleto,
                  nome: vm.estabelecimento,
                ),
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text('Rota',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              ),
          ]),
          if (mostrarProposta && (vm.valorPropostaFmt ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [
              padIcon(
                  icon: Icons.attach_money,
                  color: kMuted,
                  size: 16,
                  box: 28,
                  background: kBg,
                  borderColor: kBorder),
              const SizedBox(width: 8),
              Text('Proposta: ${vm.valorPropostaFmt}',
                  style: const TextStyle(fontSize: 13, color: kTitle)),
            ]),
          ],
        ],
      ),
    );
  }

  Widget buildVisitasVMList(
    List<VisitVM> itens, {
    bool mostrarRota = true,
    bool mostrarTitulo = true,
    bool mostrarProposta = true,
  }) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: itens.length,
      padding: EdgeInsets.zero,
      itemBuilder: (_, i) => buildVisitaVM(
        itens[i],
        mostrarRota: mostrarRota,
        mostrarTitulo: mostrarTitulo,
        mostrarProposta: mostrarProposta,
      ),
    );
  }

  Widget buildTodasVisitasSection() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: todasVisitasStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Column(
              children:
                  List.generate(3, (i) => skeletonVisitaItem(key: ValueKey('sk_all_$i'))));
        }
        if (snap.hasError) return errorBox('Erro: ${snap.error}');
        cacheProximas = null;
        cacheFinalizados = null;

        final todos = snap.data ?? [];

        bool matchesTextoRua(Map<String, dynamic> c) {
          if (query.isEmpty) return true;
          final any = c['endereco'];
          final rua = any is String ? any : (any?.toString() ?? '');
          return rua.toLowerCase().contains(query.toLowerCase());
        }

        bool isAgendado(Map<String, dynamic> c) {
          final d = visitaDateTime(c);
          if (d == null) return false;
          final agora = DateTime.now();
          final hojeInicio = DateTime(agora.year, agora.month, agora.day, 0, 0, 0);
          final hojeFim = DateTime(agora.year, agora.month, agora.day, 23, 59, 59);
          final ehHoje = (d.isAfter(hojeInicio) && d.isBefore(hojeFim)) ||
              d.isAtSameMomentAs(hojeInicio) ||
              d.isAtSameMomentAs(hojeFim);
          return d.isAfter(hojeFim) || ehHoje;
        }

        final agendadosFiltrados = todos
            .where((c) => matchesTextoRua(c) && matchChipsRua(c) && isAgendado(c))
            .map(toVMParaTodas)
            .toList();

        agendadosFiltrados.sort(_cmp);

        if (todosExpanded) {
          ruasTodas
            ..clear()
            ..addAll(agendadosFiltrados
                .map((vm) => vm.enderecoCompleto.split(',').first.trim())
                .where((s) => s.isNotEmpty));
        }

        final count = agendadosFiltrados.length;

        return animatedExpansionCard(
          key: const ValueKey('sec_todas'),
          title: 'Visão Geral das Visitas',
          subtitle: '$count agendadas',
          icon: Icons.groups_outlined,
          iconColor: kAccent,
          expanded: todosExpanded,
          onChanged: (v) => setState(() => todosExpanded = v),
          placeholderChild: Column(
              children:
                  List.generate(2, (i) => skeletonVisitaItem(key: ValueKey('ph_all_$i')))),
          child: todosExpanded
              ? (count == 0
                  ? emptyBox(
                      icon: Icons.event_note_outlined,
                      title: 'Sem visitas agendadas',
                      subtitle: query.isEmpty
                          ? (ruaSelecionada == null || ruaSelecionada!.isEmpty
                              ? 'Nenhum agendamento futuro encontrado'
                              : 'Nenhum resultado com esse filtro')
                          : 'Nenhum resultado com esse filtro',
                    )
                  : buildVisitasVMList(
                      agendadosFiltrados,
                      mostrarRota: false,
                      mostrarTitulo: false,
                      mostrarProposta: false,
                    ))
              : const SizedBox.shrink(),
        );
      },
    );
  }

  Widget emptyBox(
      {required IconData icon,
      required String title,
      required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          padIcon(icon: icon, color: kMuted, size: 28, box: 56, background: kBg),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: kTitle)),
          const SizedBox(height: 6),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: kText, height: 1.5)),
        ],
      ),
    );
  }

  Widget errorBox(String msg) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE57373)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFD32F2F), size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(msg,
                  style: const TextStyle(
                      color: Color(0xFFD32F2F), fontSize: 13))),
        ],
      ),
    );
  }

  Widget animatedExpansionCard({
    Key? key,
    required String title,
    String? subtitle,
    IconData? icon,
    Color? iconColor,
    required bool expanded,
    required ValueChanged<bool> onChanged,
    required Widget child,
    bool isLoading = false,
    Widget? placeholderChild,
  }) {
    return AnimatedSizeExpansionCard(
      key: key,
      title: title,
      subtitle: subtitle,
      icon: icon,
      iconColor: iconColor,
      expanded: expanded,
      onChanged: onChanged,
      child: child,
      vsync: this,
      isLoading: isLoading,
      placeholderChild: placeholderChild,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          FocusScope.of(context).unfocus();
          if (showChips) setState(() => showChips = false);
        },
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverToBoxAdapter(child: buildHeader()),
            SliverToBoxAdapter(
              child: cleanCard(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pesquisar',
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: kTitle)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: searchCtrl,
                      textInputAction: TextInputAction.search,
                      decoration: obterDecoracaoCampo('Nome da rua',
                          hint: 'Digite para filtrar...'),
                      onTap: () => setState(() => showChips = true),
                      onSubmitted: (_) {
                        setState(() => showChips = false);
                        FocusScope.of(context).unfocus();
                      },
                    ),
                    chipsDeBusca(),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: meusClientesStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Column(
                      children: [
                        animatedExpansionCard(
                          key: const ValueKey('sec_proximas'),
                          title: 'Próximas Visitas',
                          icon: Icons.event_available_outlined,
                          iconColor: kSuccess,
                          expanded: proxExpanded,
                          onChanged: (v) => setState(() => proxExpanded = v),
                          isLoading: proxExpanded,
                          placeholderChild: Column(
                              children: List.generate(
                                  3,
                                  (i) => skeletonVisitaItem(
                                      key: ValueKey('sk_prox_$i')))),
                          child: const SizedBox.shrink(),
                        ),
                        animatedExpansionCard(
                          key: const ValueKey('sec_todas'),
                          title: 'Todas as Visitas',
                          icon: Icons.groups_outlined,
                          iconColor: kAccent,
                          expanded: todosExpanded,
                          onChanged: (v) => setState(() => todosExpanded = v),
                          isLoading: todosExpanded,
                          placeholderChild: Column(
                              children: List.generate(
                                  3,
                                  (i) => skeletonVisitaItem(
                                      key: ValueKey('sk_all_$i')))),
                          child: const SizedBox.shrink(),
                        ),
                        animatedExpansionCard(
                          key: const ValueKey('sec_finalizadas'),
                          title: 'Visitas Finalizadas',
                          icon: Icons.check_circle_outline,
                          iconColor: kText,
                          expanded: finExpanded,
                          onChanged: (v) => setState(() => finExpanded = v),
                          isLoading: finExpanded,
                          placeholderChild: Column(
                              children: List.generate(
                                  3,
                                  (i) => skeletonVisitaItem(
                                      key: ValueKey('sk_fin_$i')))),
                          child: const SizedBox.shrink(),
                        ),
                      ],
                    );
                  }
                  if (snapshot.hasError) return errorBox('Erro: ${snapshot.error}');
                  cacheProximas = null;
                  cacheFinalizados = null;

                  final all = snapshot.data ?? [];

                  bool matchesTextoRua(Map<String, dynamic> c) {
                    if (query.isEmpty) return true;
                    final any = c['endereco'];
                    final rua = any is String ? any : (any?.toString() ?? '');
                    return rua.toLowerCase().contains(query.toLowerCase());
                  }

                  final base =
                      all.where((c) => matchesTextoRua(c) && matchChipsRua(c)).toList();

                  ruasTodas
                    ..clear()
                    ..addAll(base
                        .map((c) => (c['endereco'] ?? '').toString().trim())
                        .where((s) => s.isNotEmpty));

                  cacheProximas ??= base.where(matchProximas).toList();
                  cacheFinalizados ??= base.where(matchFinalizadas).toList();

                  final vmsProx = cacheProximas!.map(toVM).toList()..sort(_cmp);
                  final vmsFin = cacheFinalizados!.map(toVM).toList()..sort(_cmp);

                  final countProx = vmsProx.length;
                  final countFin = vmsFin.length;

                  return Column(
                    children: [
                      animatedExpansionCard(
                        key: const ValueKey('sec_proximas'),
                        title: 'Próximas Visitas',
                        subtitle: '$countProx agendadas',
                        icon: Icons.event_available_outlined,
                        iconColor: kSuccess,
                        expanded: proxExpanded,
                        onChanged: (v) => setState(() => proxExpanded = v),
                        placeholderChild: Column(
                            children: List.generate(
                                2,
                                (i) => skeletonVisitaItem(
                                    key: ValueKey('ph_prox_$i')))),
                        child: proxExpanded
                            ? (countProx == 0
                                ? emptyBox(
                                    icon: Icons.calendar_today_outlined,
                                    title: 'Nenhuma visita agendada',
                                    subtitle: query.isEmpty
                                        ? (ruaSelecionada == null ||
                                                ruaSelecionada!.isEmpty
                                            ? 'Cadastre clientes para agendar visitas'
                                            : 'Nenhum resultado encontrado')
                                        : 'Nenhum resultado encontrado',
                                  )
                                : buildVisitasVMList(vmsProx))
                            : const SizedBox.shrink(),
                      ),
                      buildTodasVisitasSection(),
                      animatedExpansionCard(
                        key: const ValueKey('sec_finalizadas'),
                        title: 'Visitas Finalizadas',
                        subtitle: '$countFin concluídas',
                        icon: Icons.check_circle_outline,
                        iconColor: kText,
                        expanded: finExpanded,
                        onChanged: (v) => setState(() => finExpanded = v),
                        placeholderChild: Column(
                            children: List.generate(
                                2,
                                (i) => skeletonVisitaItem(
                                    key: ValueKey('ph_fin_$i')))),
                        child: finExpanded
                            ? (countFin == 0
                                ? emptyBox(
                                    icon: Icons.check_circle_outline,
                                    title: 'Nenhuma visita finalizada',
                                    subtitle: query.isEmpty
                                        ? (ruaSelecionada == null ||
                                                ruaSelecionada!.isEmpty
                                            ? 'Visitas concluídas aparecerão aqui'
                                            : 'Nenhum resultado encontrado')
                                        : 'Nenhum resultado encontrado',
                                  )
                                : buildVisitasVMList(
                                    vmsFin,
                                    mostrarRota: false,
                                  ))
                            : const SizedBox.shrink(),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

class AnimatedSizeExpansionCard extends StatefulWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final bool expanded;
  final ValueChanged<bool> onChanged;
  final Widget child;
  final TickerProvider vsync;
  final bool isLoading;
  final Widget? placeholderChild;

  const AnimatedSizeExpansionCard({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    required this.expanded,
    required this.onChanged,
    required this.child,
    required this.vsync,
    this.isLoading = false,
    this.placeholderChild,
  });

  @override
  State<AnimatedSizeExpansionCard> createState() =>
      AnimatedSizeExpansionCardState();
}

class AnimatedSizeExpansionCardState extends State<AnimatedSizeExpansionCard>
    with TickerProviderStateMixin {
  late AnimationController ctrl;
  late Animation<double> turns;
  late AnimationController fadeCtrl;
  late Animation<double> fadeAnim;

  late bool expandedLocal;
  DateTime? lastTap;
  bool showRealChild = false;

  @override
  void initState() {
    super.initState();
    expandedLocal = widget.expanded;
    ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    turns = Tween<double>(begin: 0.0, end: 0.5)
        .animate(CurvedAnimation(parent: ctrl, curve: Curves.easeInOut));
    if (expandedLocal) ctrl.value = 1.0;

    fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    fadeAnim =
        CurvedAnimation(parent: fadeCtrl, curve: Curves.easeInOut);
    if (expandedLocal) {
      fadeCtrl.value = 1.0;
      showRealChild = true;
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedSizeExpansionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded != expandedLocal) {
      toggle(explicit: widget.expanded);
    }
  }

  void toggle({bool? explicit}) {
    final now = DateTime.now();
    if (lastTap != null &&
        now.difference(lastTap!) < const Duration(milliseconds: 350)) {
      return;
    }
    lastTap = now;

    setState(() {
      expandedLocal = explicit ?? !expandedLocal;
      if (expandedLocal) {
        showRealChild = false;
        ctrl.forward();
        fadeCtrl.forward(from: 0);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => showRealChild = true);
        });
      } else {
        ctrl.reverse();
        fadeCtrl.reverse(from: 1);
      }
      widget.onChanged(expandedLocal);
    });
  }

  @override
  void dispose() {
    ctrl.dispose();
    fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child =
        showRealChild ? widget.child : (widget.placeholderChild ?? const SizedBox(height: 80));

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: toggle,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    if (widget.icon != null) ...[
                      padIcon(
                        icon: widget.icon!,
                        color: widget.iconColor ?? kPrimary,
                        size: 18,
                        box: 36,
                        background:
                            (widget.iconColor ?? kPrimary).withOpacity(.10),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.title,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: kTitle)),
                          if (widget.subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(widget.subtitle!,
                                style: const TextStyle(
                                    fontSize: 12.5, color: kText)),
                          ],
                        ],
                      ),
                    ),
                    if (widget.isLoading) ...[
                      const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: kMuted)),
                      const SizedBox(width: 8),
                    ],
                    RotationTransition(
                      turns: turns,
                      child: const Icon(Icons.keyboard_arrow_down,
                          color: kMuted, size: 22),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: expandedLocal
                  ? const BoxConstraints()
                  : const BoxConstraints(maxHeight: 0.0),
              child: FadeTransition(
                opacity: fadeAnim,
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
