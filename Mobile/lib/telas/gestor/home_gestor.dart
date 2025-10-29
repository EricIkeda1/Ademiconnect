import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/lead_card.dart' as widgets;
import 'components/editar.dart' as comps;
import 'components/gestor_navbar.dart';
import 'components/gestor_header_row.dart';
import 'components/menu_inferior.dart';
import 'telas/lista_consultor.dart';

class HomeGestor extends StatefulWidget {
  const HomeGestor({super.key});
  @override
  State<HomeGestor> createState() => _HomeGestorState();
}

class _HomeGestorState extends State<HomeGestor> {
  static const Color branco = Color(0xFFFFFFFF);
  static const Color fundoApp = Color(0xFFF7F7F7);
  static const Color preto09 = Color(0xFF231F20);
  static const Color borda = Color(0xFFDFDFDF);
  static const Color cinzaPlaceholder = Color(0xFF9FA3A9);

  int _tab = 0;
  late final PageController _pageController = PageController(initialPage: _tab);

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

  @override
  void initState() {
    super.initState();
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

  Future<void> _carregarTotalDb() async {
    try {
      final res = await _sb.rpc('get_clientes_total');
      final total = (res is int)
          ? res
          : (res is num)
              ? res.toInt()
              : 0;
      setState(() => _totalDb = total);
    } catch (_) {
      try {
        final rows = await _sb.from('clientes').select('id');
        setState(() => _totalDb = rows.length);
      } catch (__){}
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
      final end = start + _pageSize - 1;

      final rows = await _sb
          .from('clientes')
          .select('id, nome, endereco, bairro, telefone, data_visita, observacoes, consultor_uid_t')
          .order('data_visita', ascending: false, nullsFirst: true)
          .range(start, end);

      final batch = <Map<String, dynamic>>[];
      for (final r in rows) {
        final id = r['id'];
        if (_ids.contains(id)) continue;
        _ids.add(id);
        batch.add({
          'id': id,
          'nome': r['nome'] ?? '',
          'tel': r['telefone'] ?? '',
          'end': r['endereco'] ?? '',
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
        for (final c in consRows) {
          final uid = c['uid'] as String?;
          final nome = c['nome'] as String?;
          if (uid != null && nome != null) map[uid] = nome;
        }
        for (final e in batch) {
          final uid = e['consUid'] as String?;
          e['cons'] = uid != null ? (map[uid] ?? '') : '';
        }
      }

      setState(() {
        _leads.addAll(batch);
        _page += 1;
        _hasMore = rows.length == _pageSize;
        _loading = false;
        _loadingMore = false;
        _aplicarFiltro();
      });
    } catch (e) {
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: borda, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFED1C24), width: 1.2),
            ),
          ),
        ),
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
                    pageCount: 4,
                    child: Column(
                      children: [
                        if (_tab == 0)
                          Container(
                            color: branco,
                            child: Column(
                              children: [
                                GestorHeaderRow(
                                  total: _query.isEmpty ? _totalDb : _filteredLeads.length,
                                  onAvisos: () {},
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
                                leads: _query.isEmpty ? _leads : _filteredLeads,
                                idsCount: _query.isEmpty ? _totalDb : _filteredLeads.length,
                                hasMore: _hasMore,
                                loadingMore: _loadingMore,
                                expandirTodos: _expandirTodos,
                                onRefresh: _refresh,
                                onCarregarMais: _carregarLeads,
                                onEditar: _abrirEditar,
                                onTransferir: _abrirTransferir,
                                setExpandirTodos: (v) => setState(() => _expandirTodos = v),
                              ),
                              Navigator(
                                key: _consultoresNavKey,
                                onGenerateRoute: (settings) =>
                                    MaterialPageRoute(builder: (_) => const ConsultoresRoot()),
                              ),
                              Navigator(
                                key: _enderecosNavKey,
                                onGenerateRoute: (_) =>
                                    MaterialPageRoute(builder: (_) => const Center(child: Text('Endereços'))),
                              ),
                              Navigator(
                                key: _exportarNavKey,
                                onGenerateRoute: (_) =>
                                    MaterialPageRoute(builder: (_) => const Center(child: Text('Exportar'))),
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
      setState(() {
        _leads[index] = {
          ..._leads[index],
          'nome': result['nome'],
          'tel': result['telefone'],
          'end': result['endereco'],
          'bairro': result['bairro'],
          'dias': result['diasPAP'],
          'obs': result['observacoes'],
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

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => TransferirLeadDialog(
        lead: _ClienteMini(id: c['id'], nome: c['nome'], telefone: c['tel']),
        consultorAtualNome: consultorAtualNome,
        onConfirmar: (novoUid) async {
          await _sb.from('clientes').update({'consultor_uid_t': novoUid}).eq('id', c['id']);
          setState(() {
            c['consUid'] = novoUid;
          });
        },
      ),
    );

    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lead transferido com sucesso')),
      );
      _carregarTotalDb();
    }
  }
}

class TransferirLeadDialog extends StatefulWidget {
  final _ClienteMini lead;
  final String consultorAtualNome;
  final Future<void> Function(String consultorUid) onConfirmar;

  const TransferirLeadDialog({
    super.key,
    required this.lead,
    required this.consultorAtualNome,
    required this.onConfirmar,
  });

  @override
  State<TransferirLeadDialog> createState() => _TransferirLeadDialogState();
}

class _TransferirLeadDialogState extends State<TransferirLeadDialog> {
  final _formKey = GlobalKey<FormState>();
  final _sb = Supabase.instance.client;

  bool _loading = true;
  bool _sending = false;
  String? _erro;
  List<Map<String, dynamic>> _consultores = [];
  String? _selecionado;

  @override
  void initState() {
    super.initState();
    _loadConsultores();
  }

  Future<void> _loadConsultores() async {
    setState(() => _loading = true);
    try {
      final rows = await _sb.from('consultores').select('uid, nome');
      setState(() {
        _consultores = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _erro = 'Erro ao carregar consultores';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Transferir Lead'),
      content: _loading
          ? const Center(child: CircularProgressIndicator())
          : _erro != null
              ? Text(_erro!)
              : Form(
                  key: _formKey,
                  child: DropdownButtonFormField<String>(
                    value: _selecionado,
                    items: _consultores
                        .map(
                          (c) => DropdownMenuItem(
                            value: c['uid'] as String,
                            child: Text(c['nome'] as String),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selecionado = v),
                    decoration: const InputDecoration(labelText: 'Novo Consultor'),
                  ),
                ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: _selecionado == null || _sending
              ? null
              : () async {
                  setState(() => _sending = true);
                  await widget.onConfirmar(_selecionado!);
                  if (mounted) Navigator.of(context).pop(true);
                },
          child: const Text('Confirmar'),
        ),
      ],
    );
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

class _ClienteMini {
  final dynamic id;
  final String? nome;
  final String? telefone;
  const _ClienteMini({required this.id, this.nome, this.telefone});
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
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: texto),
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
