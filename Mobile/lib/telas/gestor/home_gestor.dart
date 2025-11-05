import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/lead_card.dart' as widgets;
import 'components/gestor_navbar.dart';
import 'components/gestor_header_row.dart';
import 'components/menu_inferior.dart';
import 'components/avisos.dart';
import 'components/editar.dart' as comps;
import 'components/transferir_lead_dialog.dart';
import 'telas/lista_consultor.dart';
import 'telas/enderecos.dart';
import 'telas/exportar.dart';
import 'telas/vendas.dart';

class HomeGestor extends StatefulWidget {
  const HomeGestor({super.key});
  @override
  State<HomeGestor> createState() => _HomeGestorState();
}

class _HomeGestorState extends State<HomeGestor> {
  static const Color branco = Color(0xFFFFFFFF);
  static const Color fundoApp = Color(0xFFF7F7F7);
  static const Color preto09 = Color(0xFF231F20);

  int _tab = 0;
  late final PageController _pageController = PageController(initialPage: _tab);

  final _sb = Supabase.instance.client;

  bool _loading = true;
  String? _erro;
  final List<Map<String, dynamic>> _leads = [];
  final Set<dynamic> _ids = {};
  int _page = 0;
  final int _pageSize = 25;
  bool _hasMore = true;
  bool _loadingMore = false;
  bool _expandirTodos = false;

  String _query = '';

  List<Map<String, dynamic>> get _leadsFiltrados {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _leads;
    bool contains(dynamic v) => (v ?? '').toString().toLowerCase().contains(q);
    return _leads.where((c) {
      return contains(c['nome']) ||
          contains(c['tel']) ||
          contains(c['end']) ||
          contains(c['bairro']) ||
          contains(c['estab']) ||
          contains(c['cons']) ||
          contains(c['obs']);
    }).toList();
  }

  String _cleanTail(String s) => s.replaceFirst(RegExp(r',\s*$'), '').trimRight();
  String _cleanHead(String s) => s.replaceFirst(RegExp(r'^\s*,\s*'), '').trimLeft();

  String _removeCommaAfterTypeAtStart(String s) {
    if (s.isEmpty) return s;
    s = s.replaceFirstMapped(RegExp(r'^\s*(Av|R|Rod|Al|Trav)\.\s*,\s*', caseSensitive: false),
        (m) => '${m.group(1)}. ');
    s = s.replaceFirstMapped(RegExp(r'^\s*(Avenida|Rua|Rodovia|Alameda|Travessa)\s*,\s*', caseSensitive: false),
        (m) => '${m.group(1)} ');
    return s.replaceAll(RegExp(r'\s{2,}'), ' ').trimLeft();
  }

  String _removeCommaBeforeTypesAnywhere(String s) {
    return s.replaceAll(
      RegExp(r',\s*(?=(Av\.|R\.|Rod\.|Al\.|Trav\.|Avenida|Rua|Rodovia|Alameda|Travessa)\b)', caseSensitive: false),
      ' ',
    );
  }

  String _fmtEnderecoLead({
    required String logradouro,
    required String endereco,
    required String numero,
    String cidade = '',
  }) {
    var l = _removeCommaAfterTypeAtStart(_cleanTail(logradouro));
    var e = _cleanTail(endereco);
    final n = numero.trim();
    final c = cidade.trim();

    String primeiraParte;
    if (l.isNotEmpty && e.isNotEmpty && RegExp(r'\.\s*$', caseSensitive: false).hasMatch(l)) {
      primeiraParte = '$l ${e.trim()}';
    } else if (l.isNotEmpty && e.isNotEmpty) {
      primeiraParte = '$l, ${e.trim()}';
    } else {
      primeiraParte = (l + ' ' + e).trim();
    }

    String corpo = primeiraParte;
    if (n.isNotEmpty) corpo = '$corpo, $n';

    String out = corpo;
    if (c.isNotEmpty) out = '$c. $corpo';

    out = _removeCommaBeforeTypesAnywhere(out);
    out = _cleanHead(out);
    out = _cleanTail(out);
    out = out.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    return out;
  }

  @override
  void initState() {
    super.initState();
    _carregarLeads(initial: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<List<String>> _uidsConsultoresDoMeuTime() async {
    final uidGestor = _sb.auth.currentUser?.id;
    if (uidGestor == null) return [];
    final rows = await _sb
        .from('consultores')
        .select('uid')
        .eq('gestor_id', uidGestor)
        .eq('ativo', true);
    if (rows is! List) return [];
    return rows.map((r) => (r['uid'] ?? '').toString()).where((s) => s.isNotEmpty).toList();
  }

  Future<void> _carregarLeads({bool initial = false}) async {
    if (initial) {
      setState(() {
        _loading = true;
        _erro = null;
        _leads.clear();
        _ids.clear();
        _page = 0;
        _hasMore = true;
        _loadingMore = false;
        _expandirTodos = false;
      });
    }
    if (!_hasMore || _loadingMore) return;

    try {
      setState(() => _loadingMore = true);

      final consUids = await _uidsConsultoresDoMeuTime();
      if (consUids.isEmpty) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _loadingMore = false;
          _hasMore = false;
        });
        return;
      }

      final start = _page * _pageSize;
      final end = start + _pageSize - 1;

      final rows = await _sb
          .from('clientes')
          .select(
              'id, nome, telefone, logradouro, endereco, numero, bairro, cidade, estabelecimento, data_visita, observacoes, consultor_uid_t')
          .inFilter('consultor_uid_t', consUids)
          .order('data_visita', ascending: false, nullsFirst: true)
          .range(start, end);

      final batch = <Map<String, dynamic>>[];
      for (final r in (rows as List)) {
        final id = r['id'];
        if (_ids.contains(id)) continue;
        _ids.add(id);

        final endFmt = _fmtEnderecoLead(
          logradouro: (r['logradouro'] ?? '').toString(),
          endereco: (r['endereco'] ?? '').toString(),
          numero: (r['numero'] ?? '').toString(),
          cidade: (r['cidade'] ?? '').toString(),
        );

        batch.add({
          'id': id,
          'nome': r['nome'] ?? '',
          'tel': r['telefone'] ?? '',
          'end': endFmt,
          'estab': (r['estabelecimento'] ?? '').toString().trim(),
          'bairro': r['bairro'] ?? '',
          'consUid': r['consultor_uid_t'],
          'cons': '',
          'obs': r['observacoes'] ?? '',
          'dias': _calcDias(r['data_visita']),
          'urgente': _isUrgente(r['data_visita']),
          'alerta': _isAlerta(r['data_visita']),
        });
      }

      final uids = batch.map((e) => e['consUid']).where((e) => e != null).toSet().cast<String>().toList();
      if (uids.isNotEmpty) {
        final consRows = await _sb.from('consultores').select('uid, nome').inFilter('uid', uids);
        final map = <String, String>{};
        for (final c in (consRows as List)) {
          final uid = c['uid'] as String?;
          final nome = c['nome'] as String?;
          if (uid != null && nome != null) map[uid] = nome;
        }
        for (final e in batch) {
          final uid = e['consUid'] as String?;
          e['cons'] = uid != null ? (map[uid] ?? '') : '';
        }
      }

      if (!mounted) return;
      setState(() {
        _leads.addAll(batch);
        _page += 1;
        _hasMore = (rows as List).length == _pageSize;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = 'Erro ao carregar leads';
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  int _calcDias(dynamic dataVisita) {
    if (dataVisita == null) return 0;
    try {
      final dt = DateTime.parse(dataVisita.toString());
      return DateTime.now().difference(dt).inDays.abs();
    } catch (_) {
      return 0;
    }
  }

  bool _isUrgente(dynamic dataVisita) {
    if (dataVisita == null) return false;
    try {
      final dt = DateTime.parse(dataVisita.toString());
      final now = DateTime.now();
      return dt.year == now.year && dt.month == now.month && dt.day == now.day;
    } catch (_) {
      return false;
    }
  }

  bool _isAlerta(dynamic dataVisita) => _calcDias(dataVisita) > 60;

  Future<void> _refresh() async => _carregarLeads(initial: true);

  Widget _withGlobalSwipe({required Widget child, required int pageCount}) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (details) async {
        final vx = details.velocity.pixelsPerSecond.dx;
        final current = _pageController.page ?? _tab.toDouble();
        int target = current.round();

        if (vx.abs() >= 450) {
          if (vx < 0) target = (current.floor() + 1);
          if (vx > 0) target = (current.ceil() - 1);
        }
        target = target.clamp(0, pageCount - 1);
        await _pageController.animateToPage(
          target,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalGeral = _ids.length;
    final totalFiltro = _leadsFiltrados.length;

    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: fundoApp,
        appBarTheme: const AppBarTheme(
          backgroundColor: branco,
          foregroundColor: preto09,
          elevation: 0,
        ),
      ),
      child: Scaffold(
        appBar: const GestorNavbar(),
        body: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 84),
                child: _withGlobalSwipe(
                  pageCount: 4,
                  child: Column(
                    children: [
                      if (_tab == 0)
                        Container(
                          color: branco,
                          child: GestorHeaderRow(
                            totalGeral: totalGeral,
                            totalFiltro: totalFiltro,
                            onAvisos: () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.white,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                              ),
                              builder: (ctx) => const AvisosSheetMock(),
                            ),
                            query: _query,
                            onQueryChanged: (value) => setState(() {
                              _query = value;
                              _expandirTodos = true;
                            }),
                            onClearQuery: () => setState(() {
                              _query = '';
                              _expandirTodos = false;
                            }),
                          ),
                        ),
                      if (_tab == 0) const SizedBox(height: 6),
                      Expanded(
                        child: PageView(
                          controller: _pageController,
                          onPageChanged: (i) => setState(() => _tab = i),
                          children: [
                            _LeadsTab(
                              loading: _loading,
                              erro: _erro,
                              leads: _leadsFiltrados,
                              idsCount: _leadsFiltrados.length,
                              hasMore: _hasMore,
                              loadingMore: _loadingMore,
                              expandirTodos: _expandirTodos || _query.isNotEmpty,
                              onRefresh: _refresh,
                              onCarregarMais: _carregarLeads,
                              onEditar: _abrirEditar,
                              onTransferir: _abrirTransferir,
                              setExpandirTodos: (v) => setState(() => _expandirTodos = v),
                            ),
                            const VendasPage(),
                            Navigator(onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => const ConsultoresRoot())),
                            Navigator(onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => const EnderecosPage())),
                            Navigator(onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => const ExportarPage())),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: MenuInferior(
                index: _tab,
                controller: _pageController,
                onChanged: (i) {
                  _pageController.animateToPage(i, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
                  setState(() => _tab = i);
                },
              ),
            ),
          ],
        ),
        floatingActionButton: null,
      ),
    );
  }

  Future<void> _abrirEditar(Map<String, dynamic> lead, int index) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          minChildSize: 0.6,
          maxChildSize: 0.95,
          builder: (_, scrollController) {
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: SingleChildScrollView(
                controller: scrollController,
                child: comps.EditarLeadSheet(
                  nome: lead['nome'] as String,
                  telefone: lead['tel'] as String,
                  endereco: lead['end'] as String,
                  bairro: (lead['bairro'] as String?) ?? '',
                  diasPAP: (lead['dias'] as int?) ?? 0,
                  observacoes: (lead['obs'] as String?) ?? '',
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      final novoEnd = _fmtEnderecoLead(
        logradouro: result['logradouro'] ?? '',
        endereco: result['endereco'] ?? '',
        numero: result['numero'] ?? '',
        cidade: result['cidade'] ?? '',
      );
      setState(() {
        _leads[index] = {
          ..._leads[index],
          'nome': result['nome'],
          'tel': result['telefone'],
          'end': novoEnd,
          'bairro': result['bairro'],
          'dias': result['diasPAP'],
          'obs': result['observacoes'],
          'estab': result['estabelecimento'] ?? _leads[index]['estab'],
        };
      });

      try {
        await _sb.from('clientes').update({
          'nome': result['nome'],
          'telefone': result['telefone'],
          'logradouro': result['logradouro'],
          'endereco': result['endereco'],
          'numero': result['numero'],
          'bairro': result['bairro'],
          'cidade': result['cidade'],
          'estabelecimento': result['estabelecimento'],
          'observacoes': result['observacoes'],
        }).eq('id', _leads[index]['id']).select();
      } catch (_) {}
    }
  }

  Future<void> _abrirTransferir(Map<String, dynamic> c) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => TLTransferirLeadDialog(
        lead: TLCliente(id: c['id'], nome: c['nome'], telefone: c['tel']),
        consultorAtualNome: (c['cons'] as String?) ?? '-',
        onConfirmar: (novoUid) async {
          final res = await _sb.from('clientes').update({'consultor_uid_t': novoUid}).eq('id', c['id']).select();
          if (res == null || res is! List || res.isEmpty) {
            throw Exception('Sem permissão para transferir este lead (RLS/escopo).');
          }
          if (!mounted) return;
          setState(() => c['consUid'] = novoUid);
        },
      ),
    );
    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lead transferido com sucesso')));
    }
  }
}

class _LeadsTab extends StatelessWidget {
  final bool loading;
  final String? erro;
  final List<Map<String, dynamic>> leads;
  final int idsCount;
  final bool hasMore;
  final bool loadingMore;
  final bool expandirTodos;
  final Future<void> Function() onRefresh;
  final Future<void> Function({bool initial}) onCarregarMais;
  final void Function(Map<String, dynamic>, int) onEditar;
  final void Function(Map<String, dynamic>) onTransferir;
  final void Function(bool) setExpandirTodos;

  const _LeadsTab({
    super.key,
    required this.loading,
    required this.erro,
    required this.leads,
    required this.idsCount,
    required this.hasMore,
    required this.loadingMore,
    required this.expandirTodos,
    required this.onRefresh,
    required this.onCarregarMais,
    required this.onEditar,
    required this.onTransferir,
    required this.setExpandirTodos,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (erro != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(erro!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRefresh, child: const Text('Tentar novamente')),
          ],
        ),
      );
    }

    final total = idsCount;
    final mostrarLimite = !expandirTodos && total > 10;
    final itemCount = mostrarLimite ? 11 : leads.length;

    return RefreshIndicator(
      onRefresh: () async {
        setExpandirTodos(false);
        await onRefresh();
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200 && hasMore && !loadingMore) {
            onCarregarMais(initial: false);
          }
          return false;
        },
        child: ListView.separated(
          key: ValueKey('tab_leads_${expandirTodos ? 'all' : 'top10'}'),
          padding: const EdgeInsets.only(top: 0, bottom: 80),
          // sem header "resultado(s)"
          itemCount: (itemCount == 0 ? 0 : itemCount),
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (context, idx) {
            if (itemCount == 0) {
              return const SizedBox.shrink();
            }

            final renderCard = (Map<String, dynamic> c) => widgets.LeadCard(
                  nome: c['nome'] as String,
                  telefone: c['tel'] as String,
                  endereco: c['end'] as String,
                  estabelecimento: (c['estab'] as String?) ?? '',
                  consultor: (c['cons'] as String?) ?? '',
                  observacao: c['obs'] as String,
                  dias: (c['dias'] as int?) ?? 0,
                  urgente: (c['urgente'] as bool?) ?? false,
                  alerta: (c['alerta'] as bool?) ?? false,
                  onEditar: () => onEditar(c, idx),
                  onTransferir: () => onTransferir(c),
                );

            if (mostrarLimite) {
              if (idx < 10) {
                final c = leads[idx];
                return renderCard(c);
              }
              if (idx == 10) {
                return _CardVerMais(restante: total - 10, onTap: () => setExpandirTodos(true));
              }
            }

            final c = leads[idx];
            return renderCard(c);
          },
        ),
      ),
    );
  }
}

class _CardVerMais extends StatelessWidget {
  final int restante;
  final VoidCallback onTap;
  const _CardVerMais({super.key, required this.restante, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const branco = Color(0xFFFFFFFF);
    const texto = Color(0xFF231F20);
    const borda = Color(0xFFDFDFDF);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        color: branco,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borda, width: 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: const [
                Expanded(
                  child: Text('Ver mais', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: texto)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
