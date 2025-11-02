import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/lead_card.dart' as widgets;
import 'components/editar.dart' as comps;
import 'components/gestor_navbar.dart';
import 'components/gestor_header_row.dart';
import 'components/menu_inferior.dart';
import 'components/avisos.dart';
import 'telas/lista_consultor.dart';
import 'telas/enderecos.dart';
import 'telas/exportar.dart';
import 'telas/vendas.dart';

class HomeGestor extends StatefulWidget {
  const HomeGestor({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  State<HomeGestor> createState() => _HomeGestorState();
}

class _HomeGestorState extends State<HomeGestor> {
  static const Color branco = Color(0xFFFFFFFF);
  static const Color fundoApp = Color(0xFFF7F7F7);
  static const Color preto09 = Color(0xFF231F20);
  static const Color borda = Color(0xFFDFDFDF);
  static const Color cinzaPlaceholder = Color(0xFF9FA3A9);

  late int _tab;
  late final PageController _pageController;

  final GlobalKey<NavigatorState> _leadsNavKey = GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _consultoresNavKey = GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _enderecosNavKey = GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _exportarNavKey = GlobalKey<NavigatorState>();

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

  int _totalDb = 0;

  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  List<Map<String, dynamic>> _filteredLeads = [];

  String get _gestorId => _sb.auth.currentUser!.id;

  String _cleanTail(String s) => s.replaceFirst(RegExp(r',\s*$'), '').trimRight();
  String _cleanHead(String s) => s.replaceFirst(RegExp(r'^\s*,\s*'), '').trimLeft();

  String _fixCommaAfterTypeAtStart(String s) {
    final reDot = RegExp(r'^\s*(R\.|Av\.|Rod\.|Al\.|Trav\.)\s*,\s*', caseSensitive: false);
    final reFull = RegExp(r'^\s*(Rua|Avenida|Rodovia|Alameda|Travessa)\s*,\s*', caseSensitive: false);
    var out = s;
    out = out.replaceFirstMapped(reDot, (m) => '${m.group(1)} ');
    out = out.replaceFirstMapped(reFull, (m) => '${m.group(1)} ');
    return out;
  }

  String _removeCommaBeforeTypes(String s) {
    final pattern = RegExp(
      r',\s*(?=(R\.|Av\.|Rod\.|Al\.|Trav\.|Rua|Avenida|Rodovia|Alameda|Travessa)\b)',
      caseSensitive: false,
    );
    return s.replaceAll(pattern, ' ');
  }

  String _fmtEnderecoLead({
    required String logradouro,
    required String endereco,
    required String numero,
    required String complemento,
  }) {
    var l = _fixCommaAfterTypeAtStart(_cleanTail(logradouro));
    final e = _cleanTail(endereco);
    final n = numero.trim();
    final c = complemento.trim();

    final partes = <String>[];
    if (l.isNotEmpty) partes.add(l);
    if (e.isNotEmpty) partes.add(e);
    if (n.isNotEmpty) partes.add(n);
    if (c.isNotEmpty) partes.add(c);

    var out = partes.join(', ');
    out = _cleanHead(out);
    out = _cleanTail(out);
    out = _removeCommaBeforeTypes(out);
    out = out.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    return out;
  }

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    _pageController = PageController(initialPage: _tab);

    _searchCtrl.addListener(() {
      setState(() {
        _query = _searchCtrl.text.trim();
        _aplicarFiltro();
      });
    });
    _carregarTotalDb();
    _carregarLeads(initial: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _aplicarFiltro() {
    if (_query.isEmpty) {
      _filteredLeads = List<Map<String, dynamic>>.from(_leads);
      return;
    }
    final q = _query.toLowerCase();
    _filteredLeads = _leads.where((e) {
      final nomeLead = (e['nome'] as String?)?.toLowerCase() ?? '';
      final nomeCons = (e['cons'] as String?)?.toLowerCase() ?? '';
      return nomeLead.contains(q) || nomeCons.contains(q);
    }).toList();
  }

  Future<List<String>> _uidsConsultoresDoMeuTime() async {
    final rows =
        await _sb.from('consultores').select('uid').eq('gestor_id', _gestorId);
    return (rows as List)
        .map((r) => r['uid'] as String?)
        .whereType<String>()
        .toList();
  }

  Future<void> _carregarTotalDb() async {
    try {
      final consUids = await _uidsConsultoresDoMeuTime();
      if (consUids.isEmpty) {
        setState(() => _totalDb = 0);
        return;
      }
      final rows = await _sb
          .from('clientes')
          .select('id')
          .inFilter('consultor_uid_t', consUids);
      setState(() => _totalDb = (rows as List).length);
    } catch (_) {
      setState(() => _totalDb = 0);
    }
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

      final start = _page * _pageSize;

      final consUids = await _uidsConsultoresDoMeuTime();
      if (consUids.isEmpty) {
        setState(() {
          _hasMore = false;
          _loading = false;
          _loadingMore = false;
          _aplicarFiltro();
        });
        return;
      }

      final rowsAll = await _sb
          .from('clientes')
          .select('''
            id,
            nome,
            endereco,
            logradouro,
            numero,
            complemento,
            bairro,
            telefone,
            data_visita,
            observacoes,
            consultor_uid_t
          ''')
          .inFilter('consultor_uid_t', consUids)
          .order('data_visita', ascending: false, nullsFirst: true);

      final all = (rowsAll as List).cast<Map<String, dynamic>>();
      final slice = all.skip(start).take(_pageSize).toList();

      String _pickLogradouro(Map<String, dynamic> m) {
        final cands = [
          m['logradouro'],
          m['rua'],          
          m['via'],
          m['end_logradouro'],
        ];
        for (final v in cands) {
          final s = (v ?? '').toString().trim();
          if (s.isNotEmpty) return s;
        }
        return '';
      }

      final batch = <Map<String, dynamic>>[];
      for (final r in slice) {
        final id = r['id'];
        if (_ids.contains(id)) continue;
        _ids.add(id);

        final enderecoDb = (r['endereco'] ?? '').toString().trim();
        final logradouro = _pickLogradouro(r);
        final numero = (r['numero'] ?? '').toString().trim();
        final complemento = (r['complemento'] ?? '').toString().trim();

        final endFmt = enderecoDb.isNotEmpty
            ? _fmtEnderecoLead(
                logradouro: '',
                endereco: enderecoDb,
                numero: numero,
                complemento: complemento,
              )
            : _fmtEnderecoLead(
                logradouro: logradouro,
                endereco: '',
                numero: numero,
                complemento: complemento,
              );

        batch.add({
          'id': id,
          'nome': (r['nome'] ?? '').toString(),
          'tel': (r['telefone'] ?? '').toString(),
          'end': endFmt,
          'bairro': (r['bairro'] ?? '').toString(),
          'consUid': r['consultor_uid_t'],
          'cons': '',
          'obs': (r['observacoes'] ?? '').toString(),
          'dias': _calcDias(r['data_visita']),
          'urgente': _isUrgente(r['data_visita']),
          'alerta': _isAlerta(r['data_visita']),
        });
      }

      final uids = batch
          .map((e) => e['consUid'])
          .where((e) => e != null)
          .toSet()
          .cast<String>()
          .toList();
      final nomeMap = <String, String>{};
      if (uids.isNotEmpty) {
        final consRowsUid = await _sb
            .from('consultores')
            .select('uid, nome')
            .inFilter('uid', uids);
        for (final c in (consRowsUid as List)) {
          final uid = c['uid'] as String?;
          final nome = c['nome'] as String?;
          if (uid != null && nome != null) nomeMap[uid] = nome;
        }
      }
      for (final e in batch) {
        final uid = e['consUid'] as String?;
        e['cons'] = uid != null ? (nomeMap[uid] ?? '') : '';
      }

      final totalAll = all.length;
      final nextStart = (_page + 1) * _pageSize;
      final hasMore = nextStart < totalAll;

      setState(() {
        _leads.addAll(batch);
        _page += 1;
        _hasMore = hasMore;
        _loading = false;
        _loadingMore = false;
        _aplicarFiltro();
      });
    } catch (e) {
      print('Erro carregarLeads: $e');
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

  Future<void> _refresh() async {
    _searchCtrl.clear();
    await Future.wait([
      _carregarTotalDb(),
      _carregarLeads(initial: true),
    ]);
  }

  Future<bool> _onWillPop() async {
    final currentKey = <GlobalKey<NavigatorState>>[
      _leadsNavKey,
      _consultoresNavKey,
      _enderecosNavKey,
      _exportarNavKey,
    ][_tab];

    if (currentKey.currentState?.canPop() == true) {
      currentKey.currentState!.pop();
      return false;
    }
    return true;
  }

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

  Widget _buildSearchBar() {
    return Container(
      color: branco,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      child: SizedBox(
        height: 44,
        child: TextField(
          controller: _searchCtrl,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Pesquisar por lead ou consultor...',
            hintStyle: const TextStyle(color: cinzaPlaceholder, fontSize: 14),
            prefixIcon: const Icon(Icons.search, color: cinzaPlaceholder),
            filled: true,
            fillColor: const Color(0xFFF3F4F6),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: borda, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFFED1C24), width: 1.2),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _abrirAvisosMock() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: const AvisosSheetMock(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: fundoApp,
        appBarTheme: const AppBarTheme(
          backgroundColor: branco,
          foregroundColor: preto09,
          elevation: 0,
        ),
      ),
      child: WillPopScope(
        onWillPop: _onWillPop,
        child: Scaffold(
          appBar: const GestorNavbar(),
          body: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 84),
                  child: _withGlobalSwipe(
                    pageCount: 5,
                    child: Column(
                      children: [
                        if (_tab == 0)
                          Container(
                            color: branco,
                            child: Column(
                              children: [
                                GestorHeaderRow(
                                  total: _query.isEmpty
                                      ? _totalDb
                                      : _filteredLeads.length,
                                  onAvisos: _abrirAvisosMock, 
                                ),
                                _buildSearchBar(),
                              ],
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
                                leads: _query.isEmpty
                                    ? _leads
                                    : _filteredLeads,
                                idsCount: _query.isEmpty
                                    ? _totalDb
                                    : _filteredLeads.length,
                                hasMore: _hasMore,
                                loadingMore: _loadingMore,
                                expandirTodos: _expandirTodos,
                                onRefresh: _refresh,
                                onCarregarMais: _carregarLeads,
                                onEditar: _abrirEditar,
                                onTransferir: _abrirTransferir,
                                setExpandirTodos: (v) =>
                                    setState(() => _expandirTodos = v),
                              ),
                              const VendasPage(),
                              Navigator(
                                key: _consultoresNavKey,
                                onGenerateRoute: (settings) =>
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const ConsultoresRoot()),
                              ),
                              Navigator(
                                key: _enderecosNavKey,
                                onGenerateRoute: (_) => MaterialPageRoute(
                                    builder: (_) => const EnderecosPage()),
                              ),
                              Navigator(
                                key: _exportarNavKey,
                                onGenerateRoute: (_) => MaterialPageRoute(
                                    builder: (_) => const ExportarPage()),
                              ),
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
                    _pageController.animateToPage(
                      i,
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                    );
                    setState(() => _tab = i);
                  },
                ),
              ),
            ],
          ),
          floatingActionButton: null,
        ),
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
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
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
      setState(() {
        _leads[index] = {
          ..._leads[index],
          'nome': result['nome'],
          'telefone': result['telefone'],
          'end': result['endereco'],
          'bairro': result['bairro'],
          'dias': result['diasPAP'],
          'observacoes': result['observacoes'],
        };
        _aplicarFiltro();
      });

      try {
        await _sb.from('clientes').update({
          'nome': result['nome'],
          'telefone': result['telefone'],
          'endereco': result['endereco'],
          'bairro': result['bairro'],
          'observacoes': result['observacoes'],
        }).eq('id', _leads[index]['id']);
      } catch (_) {}
    }
  }

  Future<void> _abrirTransferir(Map<String, dynamic> c) async {
    final consultorAtualNome = (c['cons'] as String?) ?? '-';

    final ok = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,  
      barrierLabel: 'Transferir Lead',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (ctx, a1, a2) {
        return TLTransferirLeadDialog(
          lead: TLCliente(id: c['id'], nome: c['nome'], telefone: c['tel']),
          consultorAtualNome: consultorAtualNome,
          onConfirmar: (novoUid) async {
            await _sb
                .from('clientes')
                .update({'consultor_uid_t': novoUid}).eq('id', c['id']);
            setState(() {
              c['consUid'] = novoUid;
            });
          },
        );
      },
      transitionBuilder: (ctx, anim, _, child) {
        final curved =
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween(begin: 0.98, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );

    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lead transferido com sucesso')),
      );
      _carregarTotalDb();
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
            ElevatedButton(
                onPressed: onRefresh, child: const Text('Tentar novamente')),
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
          if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200 &&
              hasMore &&
              !loadingMore) {
            onCarregarMais(initial: false);
          }
          return false;
        },
        child: ListView.separated(
          key: ValueKey('tab_leads_${expandirTodos ? 'all' : 'top10'}'),
          padding: const EdgeInsets.only(top: 0, bottom: 80),
          itemCount: itemCount,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (context, idx) {
            if (mostrarLimite) {
              if (idx < 10) {
                final c = leads[idx];
                return widgets.LeadCard(
                  nome: c['nome'] as String,
                  telefone: c['tel'] as String,
                  endereco: c['end'] as String,
                  consultor: (c['cons'] as String?) ?? '',
                  observacao: c['obs'] as String,
                  dias: (c['dias'] as int?) ?? 0,
                  urgente: (c['urgente'] as bool?) ?? false,
                  alerta: (c['alerta'] as bool?) ?? false,
                  onEditar: () => onEditar(c, idx),
                  onTransferir: () => onTransferir(c),
                );
              }
              if (idx == 10) {
                return _CardVerMais(
                  restante: total - 10,
                  onTap: () => setExpandirTodos(true),
                );
              }
            }

            final c = leads[idx];
            return widgets.LeadCard(
              nome: c['nome'] as String,
              telefone: c['tel'] as String,
              endereco: c['end'] as String,
              consultor: (c['cons'] as String?) ?? '',
              observacao: c['obs'] as String,
              dias: (c['dias'] as int?) ?? 0,
              urgente: (c['urgente'] as bool?) ?? false,
              alerta: (c['alerta'] as bool?) ?? false,
              onEditar: () => onEditar(c, idx),
              onTransferir: () => onTransferir(c),
            );
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
              children: [
                const Expanded(
                  child: Text(
                    'Ver mais',
                    style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: texto),
                  ),
                ),
                Text('($restante)', style: const TextStyle(color: texto)),
                const SizedBox(width: 8),
                const Icon(Icons.expand_more, color: texto),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TLCliente {
  final dynamic id;
  final String? nome;
  final String? telefone;
  TLCliente({required this.id, this.nome, this.telefone});
}

class TLTransferirLeadDialog extends StatefulWidget {
  final TLCliente lead;
  final String consultorAtualNome;
  final Future<void> Function(String consultorUid) onConfirmar;

  const TLTransferirLeadDialog({
    super.key,
    required this.lead,
    required this.consultorAtualNome,
    required this.onConfirmar,
  });

  @override
  State<TLTransferirLeadDialog> createState() => _TLTransferirLeadDialogState();
}

class _TLTransferirLeadDialogState extends State<TLTransferirLeadDialog>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _sb = Supabase.instance.client;

  bool _loading = true;
  bool _sending = false;
  String? _erro;
  List<Map<String, dynamic>> _consultores = [];
  String? _selecionado;

  static const branco = Color(0xFFFFFFFF);
  static const texto = Color(0xFF231F20);
  static const vermelho = Color(0xFFEA3124);
  static const bordaCinza = Color(0xFFE8E8E8);

  static const double kMaxWidth = 520;
  static const double kMinBodyHeight = 220;
  static const EdgeInsets kInsetPadding =
      EdgeInsets.symmetric(horizontal: 28, vertical: 24);

  @override
  void initState() {
    super.initState();
    _carregarConsultores();
  }

  Future<void> _carregarConsultores() async {
    try {
      final rows = await _sb
          .from('consultores')
          .select('uid, nome')
          .eq('ativo', true)
          .order('nome');
      setState(() {
        _consultores = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _erro = 'Erro ao carregar consultores';
        _loading = false;
      });
    }
  }

  Future<void> _confirmar() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = _selecionado;
    if (uid == null) return;

    setState(() => _sending = true);
    try {
      await widget.onConfirmar(uid);
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: kInsetPadding,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kMaxWidth),
          child: Material(
            color: branco,
            elevation: 6,
            shadowColor: Colors.black26,
            borderRadius: BorderRadius.circular(14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(0, 12, 0, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: const Color(0x1AEA3124),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.sync_alt_rounded,
                                color: vermelho, size: 16),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Transferir Lead',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: texto,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: texto, size: 20),
                            onPressed: () => Navigator.of(context).pop(),
                            tooltip: 'Fechar',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: branco,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: bordaCinza, width: 1),
                      ),
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.lead.nome ?? '-',
                              style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: texto)),
                          const SizedBox(height: 4),
                          if ((widget.lead.telefone ?? '').isNotEmpty)
                            Text(widget.lead.telefone!,
                                style: const TextStyle(
                                    fontSize: 13.5, color: texto)),
                          const SizedBox(height: 4),
                          Text('Consultor atual: ${widget.consultorAtualNome}',
                              style: const TextStyle(
                                  fontSize: 13, color: Color(0xFF6B6B6E))),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Transferir para',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: texto,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: DropdownButtonFormField<String>(
                        value: _selecionado,
                        isExpanded: true,
                        icon: const Icon(Icons.expand_more,
                            color: Color(0xFF6B6B6E)),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 11),
                          fillColor: branco,
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: bordaCinza, width: 1),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: bordaCinza, width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: vermelho, width: 1.2),
                          ),
                        ),
                        hint: const Text('Selecione o consultor',
                            style: TextStyle(color: Color(0xFF9A9AA0))),
                        items: _consultores
                            .map((c) => DropdownMenuItem<String>(
                                  value: c['uid'] as String,
                                  child: Text(c['nome'] as String),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _selecionado = v),
                        validator: (v) =>
                            v == null ? 'Selecione um consultor' : null,
                      ),
                    ),

                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: _TLGradientConfirmButton(
                          enabled: !_sending && _selecionado != null,
                          onPressed: _sending || _selecionado == null
                              ? null
                              : _confirmar,
                          child: _sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.sync_alt_rounded,
                                        size: 18, color: Colors.white),
                                    SizedBox(width: 8),
                                    Text(
                                      'Confirmar Transferência',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TLGradientConfirmButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final bool enabled;
  const _TLGradientConfirmButton({
    required this.onPressed,
    required this.child,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final enabledGradient = const LinearGradient(
      colors: [
        Color(0xFFF15A24),
        Color(0xFFEA3124),
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );

    final disabledColor = const Color(0xFFEEC5C2);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: enabled ? enabledGradient : null,
        color: enabled ? null : disabledColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white70,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: EdgeInsets.zero,
        ),
        child: child,
      ),
    );
  }
}
