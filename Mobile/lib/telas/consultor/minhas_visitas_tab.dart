import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

const _kBg = Color(0xFFF7F8FA);
const _kCard = Colors.white;
const _kBorder = Color(0xFFE6E8EC);
const _kTitle = Color(0xFF0F172A);
const _kText = Color(0xFF475569);
const _kMuted = Color(0xFF94A3B8);
const _kPrimary = Color(0xFF0B5EA8);
const _kSuccess = Color(0xFF2E7D32);
const _kInfo = Color(0xFF1565C0);
const _kAccent = Color(0xFF4F46E5);

final DateFormat _fmtHora = DateFormat('HH:mm');
final DateFormat _fmtA = DateFormat('EEE, d MMM', 'pt_BR');
final DateFormat _fmtB = DateFormat('EEE, d MMM y', 'pt_BR');

class VisitVM {
  final String id;
  final String estabelecimento;
  final String enderecoCompleto;
  final String dataFmt;
  final IconData icone;
  final String statusTxt;
  final Color corFundo;
  final Color corTexto;
  const VisitVM({
    required this.id,
    required this.estabelecimento,
    required this.enderecoCompleto,
    required this.dataFmt,
    required this.icone,
    required this.statusTxt,
    required this.corFundo,
    required this.corTexto,
  });
}

class MinhasVisitasTab extends StatefulWidget {
  const MinhasVisitasTab({super.key});

  @override
  State<MinhasVisitasTab> createState() => _MinhasVisitasTabState();
}

class _MinhasVisitasTabState extends State<MinhasVisitasTab> with TickerProviderStateMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  final SupabaseClient _client = Supabase.instance.client;

  bool _proxExpanded = true;
  bool _todosExpanded = false;
  bool _finExpanded = false;
  bool _showChips = true;

  List<Map<String, dynamic>>? _cacheProximas;
  List<Map<String, dynamic>>? _cacheFinalizados;

  final Set<String> _ruasTodas = <String>{};
  String? _ruaSelecionada;

  @override
  void initState() {
    super.initState();
    _invalidateCaches();
    _searchCtrl.addListener(() {
      if (!mounted) return;
      setState(() {
        _query = _searchCtrl.text.trim();
        _showChips = true;
        _invalidateCaches();
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _invalidateCaches() {
    _cacheProximas = null;
    _cacheFinalizados = null;
  }

  Stream<List<Map<String, dynamic>>> get _meusClientesStream {
    final user = _client.auth.currentSession?.user;
    if (user == null) return const Stream<List<Map<String, dynamic>>>.empty();
    return _client
        .from('clientes')
        .select('*')
        .eq('consultor_uid_t', user.id)
        .order('data_visita', ascending: false)
        .order('hora_visita', ascending: false)
        .asStream();
  }

  Stream<List<Map<String, dynamic>>> get _todasVisitasStream {
    return _client
        .from('clientes')
        .select('id, estabelecimento, endereco, cidade, estado, data_visita, hora_visita, consultor_uid_t')
        .order('data_visita', ascending: false)
        .order('hora_visita', ascending: false)
        .asStream();
  }

  Future<void> _abrirNoGoogleMaps(String endereco) async {
    final q = Uri.encodeComponent(endereco.trim());
    final platform = Theme.of(context).platform;

    final androidGeo = Uri.parse('geo:0,0?q=$q');
    final androidWeb = Uri.parse('https://maps.google.com/?q=$q');
    final iosGmm = Uri.parse('comgooglemaps://?q=$q');
    final iosApple = Uri.parse('http://maps.apple.com/?q=$q');
    
    try {
      if (platform == TargetPlatform.android) {
        if (await canLaunchUrl(androidGeo)) { await launchUrl(androidGeo); return; }
        if (await canLaunchUrl(androidWeb)) { await launchUrl(androidWeb, mode: LaunchMode.externalApplication); return; }
      } else if (platform == TargetPlatform.iOS) {
        if (await canLaunchUrl(iosGmm)) { await launchUrl(iosGmm); return; }
        if (await canLaunchUrl(iosApple)) { await launchUrl(iosApple); return; }
      }
      final web = Uri.parse('https://www.google.com/maps/search/?api=1&query=$q');
      final ok = await launchUrl(web, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o Maps')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao abrir o Maps: $e')),
        );
      }
    }
  }

  String _formatarDataVisitaDT(DateTime? d) {
    if (d == null) return 'Data não informada';
    final hoje = DateTime.now();
    final amanha = DateTime(hoje.year, hoje.month, hoje.day + 1);
    final horaExibida = _fmtHora.format(d);
    if (d.year == hoje.year && d.month == hoje.month && d.day == hoje.day) {
      return 'Hoje às $horaExibida';
    } else if (d.year == amanha.year && d.month == amanha.month && d.day == amanha.day) {
      return 'Amanhã às $horaExibida';
    } else {
      final base = d.year == hoje.year ? _fmtA : _fmtB;
      return '${_capitalize(base.format(d))} às $horaExibida';
    }
  }

  Map<String, dynamic> _determinarStatus(String? dataVisitaStr, {String? horaVisitaStr}) {
    if (dataVisitaStr == null || dataVisitaStr.isEmpty) {
      return {
        'icone': Icons.schedule_outlined,
        'texto': 'Agendado',
        'corFundo': _kSuccess.withOpacity(.10),
        'corTexto': _kSuccess,
      };
    }
    try {
      DateTime d = DateTime.parse(dataVisitaStr).toLocal();
      if (horaVisitaStr != null && horaVisitaStr.isNotEmpty) {
        final p = horaVisitaStr.split(':');
        final h = int.tryParse(p[0]) ?? 0;
        final m = p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0;
        final s = p.length > 2 ? int.tryParse(p[2]) ?? 0 : 0;
        d = DateTime(d.year, d.month, d.day, h, m, s);
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
          'corFundo': _kInfo.withOpacity(.10),
          'corTexto': _kInfo,
        };
      } else if (d.isBefore(hojeInicio)) {
        return {
          'icone': Icons.check_circle_outline,
          'texto': 'Realizada',
          'corFundo': _kText.withOpacity(.08),
          'corTexto': _kText,
        };
      } else {
        return {
          'icone': Icons.schedule_outlined,
          'texto': 'Agendado',
          'corFundo': _kSuccess.withOpacity(.10),
          'corTexto': _kSuccess,
        };
      }
    } catch (_) {
      return {
        'icone': Icons.schedule_outlined,
        'texto': 'Agendado',
        'corFundo': _kSuccess.withOpacity(.10),
        'corTexto': _kSuccess,
      };
    }
  }

  String _capitalize(String text) => text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

  InputDecoration _obterDecoracaoCampo(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _kBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _kPrimary, width: 2),
      ),
      suffixIcon: _query.isEmpty
          ? const Icon(Icons.search, color: _kMuted, size: 20)
          : IconButton(
              icon: const Icon(Icons.close, color: _kMuted, size: 20),
              onPressed: () {
                _searchCtrl.clear();
                setState(() {
                  _query = '';
                  _ruaSelecionada = null;
                  _invalidateCaches();
                });
              },
            ),
      labelStyle: const TextStyle(color: _kText, fontSize: 13, fontWeight: FontWeight.w500),
      hintStyle: const TextStyle(color: _kMuted, fontSize: 13),
    );
  }

  Widget _cleanCard({required Widget child, EdgeInsets? padding, EdgeInsets? margin}) {
    return Container(
      margin: margin ?? const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: child,
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _kBorder),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.calendar_today_outlined, color: _kPrimary, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Minhas Visitas',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _kTitle,
                    letterSpacing: -0.2,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Agenda e acompanhamento',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: _kText,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipsDeBusca() {
    if (!_showChips) return const SizedBox.shrink();

    final termos = _ruasTodas.toList()..sort();
    final visiveis = termos.where((t) => _query.isEmpty || t.toLowerCase().contains(_query.toLowerCase())).toList();
    if (visiveis.isEmpty) return const SizedBox.shrink();

    Widget buildChip(String t) {
      final selecionado = _ruaSelecionada == t;
      return Material(
        color: selecionado ? _kPrimary.withOpacity(.08) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () {
            if (!mounted) return;
            setState(() {
              if (_ruaSelecionada != t) {
                _ruaSelecionada = t;
                _searchCtrl.text = t;
                _query = t;
                _showChips = false;
              } else {
                _ruaSelecionada = null;
                _searchCtrl.clear();
                _query = '';
              }
              _invalidateCaches();
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: selecionado ? _kPrimary : _kBorder),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              t,
              style: TextStyle(
                color: selecionado ? _kPrimary : _kText,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

    const double alturaChips = 160;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SizedBox(
        height: alturaChips,
        child: Scrollbar(
          thumbVisibility: true,
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: visiveis.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: buildChip(visiveis[index]),
            ),
          ),
        ),
      ),
    );
  }

  bool _matchChipsRua(Map<String, dynamic> c) {
    if (_ruaSelecionada == null || _ruaSelecionada!.isEmpty) return true;
    final any = c['endereco'];
    final rua = ((any is String) ? any : (any?.toString() ?? '')).toLowerCase();
    return rua.contains(_ruaSelecionada!.toLowerCase());
  }

  Widget _skeletonShimmer({required Widget child}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      builder: (context, value, _) {
        final shimmer = LinearGradient(
          colors: [const Color(0xFFEFF2F7), const Color(0xFFF7F8FA), const Color(0xFFEFF2F7)],
          stops: [0.1, 0.5, 0.9],
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

  Widget _skeletonBar({double height = 12, double width = double.infinity, BorderRadius? radius}) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: const Color(0xFFEFF2F7),
        borderRadius: radius ?? BorderRadius.circular(6),
      ),
    );
  }

  Widget _skeletonVisitaItem({Key? key}) {
    return KeyedSubtree(
      key: key ?? UniqueKey(),
      child: _cleanCard(
        padding: const EdgeInsets.all(14),
        child: _skeletonShimmer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: _skeletonBar(height: 14, width: 160)),
                const SizedBox(width: 12),
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
              _skeletonBar(height: 12, width: 220),
              const SizedBox(height: 6),
              _skeletonBar(height: 12, width: 160),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _skeletonBar(height: 12, width: 100),
                  _skeletonBar(height: 30, width: 80, radius: BorderRadius.circular(8)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  VisitVM _toVM(Map<String, dynamic> c) {
    final end = (c['endereco'] ?? '').toString().trim();
    final cidade = (c['cidade'] ?? '').toString().trim();
    final estado = (c['estado'] ?? '').toString().trim();
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
        final h = int.tryParse(p[0]) ?? 0;
        final m = p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0;
        final s = p.length > 2 ? int.tryParse(p[2]) ?? 0 : 0;
        d = DateTime(d.year, d.month, d.day, h, m, s);
      } else {
        d = DateTime(d.year, d.month, d.day, 23, 59, 59);
      }
    }
    final dataFmt = _formatarDataVisitaDT(d);
    final s = _determinarStatus(ds, horaVisitaStr: hs);
    final enderecoCompleto = [
      if (end.isNotEmpty) end,
      if (cidade.isNotEmpty || estado.isNotEmpty) '$cidade - $estado',
    ].where((e) => e.isNotEmpty).join(', ');
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
    );
  }

  Widget _buildVisitaVM(VisitVM vm, {bool mostrarRota = true}) {
    return _cleanCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  vm.estabelecimento,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _kTitle),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: vm.corFundo,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: vm.corTexto.withOpacity(.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(vm.icone, size: 14, color: vm.corTexto),
                    const SizedBox(width: 6),
                    Text(
                      vm.statusTxt,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: vm.corTexto),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (vm.enderecoCompleto.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: _kMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    vm.enderecoCompleto,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: _kText, height: 1.4),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.access_time, size: 16, color: _kMuted),
              const SizedBox(width: 6),
              Text(vm.dataFmt, style: const TextStyle(fontSize: 13, color: _kTitle, fontWeight: FontWeight.w500)),
              const Spacer(),
              if (mostrarRota && vm.enderecoCompleto.trim().length > 3)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: _kPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: _kBorder),
                    ),
                  ),
                  onPressed: () => _abrirNoGoogleMaps(vm.enderecoCompleto),
                  icon: const Icon(Icons.map_outlined, size: 16),
                  label: const Text('Rota', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVisitasVMList(List<VisitVM> itens, {bool mostrarRota = true}) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: itens.length,
      padding: EdgeInsets.zero,
      itemBuilder: (_, i) => _buildVisitaVM(itens[i], mostrarRota: mostrarRota),
    );
  }

  Widget _buildTodasVisitasSection() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _todasVisitasStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Column(children: List.generate(3, (i) => _skeletonVisitaItem(key: ValueKey('sk_all_$i'))));
        }
        if (snap.hasError) {
          return _errorBox('Erro: ${snap.error}');
        }

        final todos = snap.data ?? [];

        bool matchesTextoRua(Map<String, dynamic> c) {
          if (_query.isEmpty) return true;
          final any = c['endereco'];
          final rua = ((any is String) ? any : (any?.toString() ?? '')).toLowerCase();
          return rua.contains(_query.toLowerCase());
        }

        bool isAgendado(Map<String, dynamic> c) {
          final ds = c['data_visita']?.toString();
          DateTime? data;
          if (ds != null && ds.isNotEmpty) {
            try {
              data = DateTime.parse(ds).toLocal();
            } catch (_) {}
          }
          final hs = c['hora_visita']?.toString();
          if (data != null) {
            if (hs != null && hs.isNotEmpty) {
              final p = hs.split(':');
              final h = int.tryParse(p[0]) ?? 0;
              final m = p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0;
              final s = p.length > 2 ? int.tryParse(p[2]) ?? 0 : 0;
              data = DateTime(data.year, data.month, data.day, h, m, s);
            } else {
              data = DateTime(data.year, data.month, data.day, 23, 59, 59);
            }
          }

          final agora = DateTime.now();
          final hojeInicio = DateTime(agora.year, agora.month, agora.day, 0, 0, 0);
          final hojeFim = DateTime(agora.year, agora.month, agora.day, 23, 59, 59);

          if (data == null) return false;

          final ehHoje = (data.isAfter(hojeInicio) && data.isBefore(hojeFim)) ||
              data.isAtSameMomentAs(hojeInicio) ||
              data.isAtSameMomentAs(hojeFim);

          return data.isAfter(hojeFim) && !ehHoje;
        }

        final agendadosFiltrados = todos
            .where((c) => matchesTextoRua(c) && _matchChipsRua(c) && isAgendado(c))
            .map(_toVM)
            .toList();

        if (_todosExpanded) {
          _ruasTodas
            ..clear()
            ..addAll(
              agendadosFiltrados.map((vm) => vm.enderecoCompleto.split(',').first.trim()).where((s) => s.isNotEmpty),
            );
        }

        final count = agendadosFiltrados.length;

        return _animatedExpansionCard(
          key: const ValueKey('sec_todas'),
          title: 'Todas as Visitas',
          subtitle: '$count agendadas',
          icon: Icons.groups_outlined,
          iconColor: _kAccent,
          expanded: _todosExpanded,
          onChanged: (v) => setState(() => _todosExpanded = v),
          placeholderChild: Column(children: List.generate(2, (i) => _skeletonVisitaItem(key: ValueKey('ph_all_$i')))),
          child: _todosExpanded
              ? (count == 0
                  ? _emptyBox(
                      icon: Icons.event_note,
                      title: 'Sem visitas agendadas',
                      subtitle: _query.isEmpty && (_ruaSelecionada == null || _ruaSelecionada!.isEmpty)
                          ? 'Nenhum agendamento futuro encontrado'
                          : 'Nenhum resultado com esse filtro')
                  : _buildVisitasVMList(agendadosFiltrados, mostrarRota: false))
              : const SizedBox.shrink(),
        );
      },
    );
  }

  Widget _expansionSkeleton({required String title}) {
    return _cleanCard(
      child: _skeletonShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _skeletonBar(height: 16, width: 140),
            const SizedBox(height: 12),
            ...List.generate(
              2,
              (i) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF2F7),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyBox({required IconData icon, required String title, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _kBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kBorder),
            ),
            child: Icon(icon, size: 28, color: _kMuted),
          ),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _kTitle)),
          const SizedBox(height: 6),
          Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: _kText, height: 1.5)),
        ],
      ),
    );
  }

  Widget _errorBox(String msg) {
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
          Expanded(child: Text(msg, style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 13))),
        ],
      ),
    );
  }

  Widget _animatedExpansionCard({
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
    return _AnimatedSizeExpansionCard(
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
      backgroundColor: _kBg,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          FocusScope.of(context).unfocus();
          if (_showChips) setState(() => _showChips = false);
        },
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(
              child: _cleanCard(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pesquisar', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: _kTitle)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _searchCtrl,
                      textInputAction: TextInputAction.search,
                      decoration: _obterDecoracaoCampo('Nome da rua', hint: 'Digite para filtrar...'),
                      onTap: () => setState(() => _showChips = true),
                      onSubmitted: (_) => setState(() => _showChips = false),
                    ),
                    _chipsDeBusca(),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _meusClientesStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Column(
                      children: [
                        _animatedExpansionCard(
                          key: const ValueKey('sec_proximas'),
                          title: 'Próximas Visitas',
                          icon: Icons.event_available_outlined,
                          iconColor: _kSuccess,
                          expanded: _proxExpanded,
                          onChanged: (v) => setState(() => _proxExpanded = v),
                          isLoading: _proxExpanded,
                          placeholderChild: Column(children: List.generate(3, (i) => _skeletonVisitaItem(key: ValueKey('sk_prox_$i')))),
                          child: const SizedBox.shrink(),
                        ),
                        _animatedExpansionCard(
                          key: const ValueKey('sec_todas'),
                          title: 'Todas as Visitas',
                          icon: Icons.groups_outlined,
                          iconColor: _kAccent,
                          expanded: _todosExpanded,
                          onChanged: (v) => setState(() => _todosExpanded = v),
                          isLoading: _todosExpanded,
                          placeholderChild: Column(children: List.generate(3, (i) => _skeletonVisitaItem(key: ValueKey('sk_all_$i')))),
                          child: const SizedBox.shrink(),
                        ),
                        _animatedExpansionCard(
                          key: const ValueKey('sec_finalizadas'),
                          title: 'Visitas Finalizadas',
                          icon: Icons.check_circle_outline,
                          iconColor: _kText,
                          expanded: _finExpanded,
                          onChanged: (v) => setState(() => _finExpanded = v),
                          isLoading: _finExpanded,
                          placeholderChild: Column(children: List.generate(3, (i) => _skeletonVisitaItem(key: ValueKey('sk_fin_$i')))),
                          child: const SizedBox.shrink(),
                        ),
                      ],
                    );
                  }

                  if (snapshot.hasError) {
                    return _errorBox('Erro: ${snapshot.error}');
                  }

                  final all = snapshot.data ?? [];

                  bool matchesTextoRua(Map<String, dynamic> c) {
                    if (_query.isEmpty) return true;
                    final any = c['endereco'];
                    final rua = ((any is String) ? any : (any?.toString() ?? '')).toLowerCase();
                    return rua.contains(_query.toLowerCase());
                  }
                  final base = all.where((c) => matchesTextoRua(c) && _matchChipsRua(c)).toList();

                  _ruasTodas
                    ..clear()
                    ..addAll(
                      base.map((c) => (c['endereco'] ?? '').toString().trim())
                          .where((s) => s.isNotEmpty),
                    );

                  final agora = DateTime.now();
                  final hojeIni = DateTime(agora.year, agora.month, agora.day, 0, 0, 0);

                  bool isPassado(Map<String, dynamic> c) {
                    final ds = c['data_visita']?.toString();
                    if (ds == null || ds.isEmpty) return false;
                    try {
                      DateTime d = DateTime.parse(ds).toLocal();
                      final hs = c['hora_visita']?.toString();
                      if (hs != null && hs.isNotEmpty) {
                        final p = hs.split(':');
                        final h = int.tryParse(p[0]) ?? 0;
                        final m = p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0;
                        final s = p.length > 2 ? int.tryParse(p[2]) ?? 0 : 0;
                        d = DateTime(d.year, d.month, d.day, h, m, s);
                      } else {
                        d = DateTime(d.year, d.month, d.day, 0, 0, 0);
                      }
                      return d.isBefore(hojeIni);
                    } catch (_) {
                      return false;
                    }
                  }

                  _cacheProximas ??= base.where((c) => !isPassado(c)).toList();
                  _cacheFinalizados ??= base.where(isPassado).toList();

                  final vmsProx = _cacheProximas!.map(_toVM).toList();
                  final vmsFin = _cacheFinalizados!.map(_toVM).toList();

                  final countProx = vmsProx.length;
                  final countFin = vmsFin.length;

                  return Column(
                    children: [
                      _animatedExpansionCard(
                        key: const ValueKey('sec_proximas'),
                        title: 'Próximas Visitas',
                        subtitle: '$countProx agendadas',
                        icon: Icons.event_available_outlined,
                        iconColor: _kSuccess,
                        expanded: _proxExpanded,
                        onChanged: (v) => setState(() => _proxExpanded = v),
                        placeholderChild: Column(children: List.generate(2, (i) => _skeletonVisitaItem(key: ValueKey('ph_prox_$i')))),
                        child: _proxExpanded
                            ? (countProx == 0
                                ? _emptyBox(
                                    icon: Icons.calendar_today_outlined,
                                    title: 'Nenhuma visita agendada',
                                    subtitle: _query.isEmpty && (_ruaSelecionada == null || _ruaSelecionada!.isEmpty)
                                        ? 'Cadastre clientes para agendar visitas'
                                        : 'Nenhum resultado encontrado')
                                : _buildVisitasVMList(vmsProx))
                            : const SizedBox.shrink(),
                      ),
                      _buildTodasVisitasSection(),
                      _animatedExpansionCard(
                        key: const ValueKey('sec_finalizadas'),
                        title: 'Visitas Finalizadas',
                        subtitle: '$countFin concluídas',
                        icon: Icons.check_circle_outline,
                        iconColor: _kText,
                        expanded: _finExpanded,
                        onChanged: (v) => setState(() => _finExpanded = v),
                        placeholderChild: Column(children: List.generate(2, (i) => _skeletonVisitaItem(key: ValueKey('ph_fin_$i')))),
                        child: _finExpanded
                            ? (countFin == 0
                                ? _emptyBox(
                                    icon: Icons.check_circle_outline,
                                    title: 'Nenhuma visita finalizada',
                                    subtitle: _query.isEmpty && (_ruaSelecionada == null || _ruaSelecionada!.isEmpty)
                                        ? 'Visitas concluídas aparecerão aqui'
                                        : 'Nenhum resultado encontrado')
                                : _buildVisitasVMList(vmsFin, mostrarRota: false))
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

class _AnimatedSizeExpansionCard extends StatefulWidget {
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

  const _AnimatedSizeExpansionCard({
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
  State<_AnimatedSizeExpansionCard> createState() => _AnimatedSizeExpansionCardState();
}

class _AnimatedSizeExpansionCardState extends State<_AnimatedSizeExpansionCard>
    with TickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _turns;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  late bool _expandedLocal;
  DateTime? _lastTap;
  bool _showRealChild = false;

  @override
  void initState() {
    super.initState();
    _expandedLocal = widget.expanded;
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _turns = Tween<double>(begin: 0.0, end: 0.5).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    if (_expandedLocal) _ctrl.value = 1.0;

    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);
    if (_expandedLocal) {
      _fadeCtrl.value = 1.0;
      _showRealChild = true;
    }
  }

  @override
  void didUpdateWidget(covariant _AnimatedSizeExpansionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded != _expandedLocal) {
      _toggle(explicit: widget.expanded);
    }
  }

  void _toggle({bool? explicit}) {
    final now = DateTime.now();
    if (_lastTap != null && now.difference(_lastTap!) < const Duration(milliseconds: 350)) return;
    _lastTap = now;

    setState(() {
      _expandedLocal = explicit ?? !_expandedLocal;
      if (_expandedLocal) {
        _showRealChild = false;
        _ctrl.forward();
        _fadeCtrl.forward(from: 0);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _showRealChild = true);
        });
      } else {
        _ctrl.reverse();
        _fadeCtrl.reverse(from: 1);
      }
      widget.onChanged(_expandedLocal);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = _showRealChild ? widget.child : (widget.placeholderChild ?? const SizedBox(height: 80));

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _toggle,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    if (widget.icon != null) ...[
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: (widget.iconColor ?? _kPrimary).withOpacity(.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(widget.icon, size: 18, color: widget.iconColor ?? _kPrimary),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _kTitle)),
                          if (widget.subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(widget.subtitle!, style: const TextStyle(fontSize: 12.5, color: _kText)),
                          ],
                        ],
                      ),
                    ),
                    if (widget.isLoading) ...[
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: _kMuted),
                      ),
                      const SizedBox(width: 8),
                    ],
                    RotationTransition(
                      turns: _turns,
                      child: const Icon(Icons.keyboard_arrow_down, color: _kMuted, size: 22),
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
              constraints: _expandedLocal ? const BoxConstraints() : const BoxConstraints(maxHeight: 0.0),
              child: FadeTransition(opacity: _fadeAnim, child: child),
            ),
          ),
        ],
      ),
    );
  }
}
