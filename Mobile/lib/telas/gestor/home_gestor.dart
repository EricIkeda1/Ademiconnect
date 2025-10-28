import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/lead_card.dart' as widgets;
import 'components/editar.dart' as comps;
import 'components/gestor_navbar.dart';
import 'components/gestor_header_row.dart';
import 'components/menu_inferior.dart';

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
      final uids = batch
          .map((e) => e['consUid'])
          .where((e) => e != null)
          .toSet()
          .cast<String>()
          .toList();
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

  Future<void> _refresh() async => _carregarLeads(initial: true);

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
      child: Scaffold(
        appBar: const GestorNavbar(),
        body: Column(
          children: [
            if (_tab == 0)
              Container(
                color: branco,
                child: GestorHeaderRow(
                  total: _ids.length,
                  onAvisos: () {},
                ),
              ),
            if (_tab == 0) const SizedBox(height: 6),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _tab = i),
                children: [
                  _tabLeads(),
                  const Center(child: Text('Consultores')),
                  const Center(child: Text('Endereços')),
                  const Center(child: Text('Exportar')),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: MenuInferior(
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
    );
  }

  Widget _tabLeads() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_erro != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_erro!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _refresh, child: const Text('Tentar novamente')),
          ],
        ),
      );
    }
    final total = _ids.length;
    final mostrarLimite = !_expandirTodos && total > 10;
    final itemCount = mostrarLimite ? 11 : _leads.length;
    return RefreshIndicator(
      onRefresh: () async {
        _expandirTodos = false;
        await _refresh();
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200 &&
              !_loading &&
              _hasMore &&
              !_loadingMore) {
            _carregarLeads();
          }
          return false;
        },
        child: ListView.separated(
          key: ValueKey('tab_leads_${_expandirTodos ? 'all' : 'top10'}'),
          padding: const EdgeInsets.only(top: 0, bottom: 80),
          itemCount: itemCount,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (context, idx) {
            if (mostrarLimite) {
              if (idx < 10) {
                final c = _leads[idx];
                return widgets.LeadCard(
                  nome: c['nome'] as String,
                  telefone: c['tel'] as String,
                  endereco: c['end'] as String,
                  consultor: (c['cons'] as String?) ?? '',
                  observacao: c['obs'] as String,
                  dias: (c['dias'] as int?) ?? 0,
                  urgente: (c['urgente'] as bool?) ?? false,
                  alerta: (c['alerta'] as bool?) ?? false,
                  onEditar: () => _abrirEditar(c, idx),
                  onTransferir: () => _abrirTransferir(c),
                );
              }
              if (idx == 10) {
                return _CardVerMais(
                  restante: total - 10,
                  onTap: () => setState(() => _expandirTodos = true),
                );
              }
            }
            final c = _leads[idx];
            return widgets.LeadCard(
              nome: c['nome'] as String,
              telefone: c['tel'] as String,
              endereco: c['end'] as String,
              consultor: (c['cons'] as String?) ?? '',
              observacao: c['obs'] as String,
              dias: (c['dias'] as int?) ?? 0,
              urgente: (c['urgente'] as bool?) ?? false,
              alerta: (c['alerta'] as bool?) ?? false,
              onEditar: () => _abrirEditar(c, idx),
              onTransferir: () => _abrirTransferir(c),
            );
          },
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
      });
      try {
        await _sb
            .from('clientes')
            .update({
              'nome': result['nome'],
              'telefone': result['telefone'],
              'endereco': result['endereco'],
              'bairro': result['bairro'],
              'observacoes': result['observacoes'],
            })
            .eq('id', _leads[index]['id']);
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
    }
  }
}

class _CardVerMais extends StatelessWidget {
  final int restante;
  final VoidCallback onTap;
  const _CardVerMais({required this.restante, required this.onTap});

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
                Expanded(
                  child: Text(
                    'Ver mais ($restante)',
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: texto),
                  ),
                ),
                const Icon(Icons.expand_more, color: texto),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClienteMini {
  final dynamic id;
  final String? nome;
  final String? telefone;
  _ClienteMini({required this.id, this.nome, this.telefone});
}

class TransferirLeadDialog extends StatefulWidget {
  final _ClienteMini lead;
  final String consultorAtualNome;
  final Future<void> Function(String novoUid) onConfirmar;
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
  final _sb = Supabase.instance.client;
  String? _novoUid;
  bool _carregando = false;
  List<Map<String, dynamic>> _consultores = [];

  @override
  void initState() {
    super.initState();
    _carregarConsultores();
  }

  Future<void> _carregarConsultores() async {
    try {
      final rows = await _sb.from('consultores').select('uid, nome');
      setState(() {
        _consultores = List<Map<String, dynamic>>.from(rows);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao carregar consultores')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Transferir Lead'),
      content: _consultores.isEmpty
          ? const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()))
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Lead: ${widget.lead.nome ?? ''}'),
                const SizedBox(height: 12),
                Text('Consultor atual: ${widget.consultorAtualNome}'),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Novo consultor',
                    border: OutlineInputBorder(),
                  ),
                  value: _novoUid,
                  onChanged: (v) => setState(() => _novoUid = v),
                  items: _consultores.map<DropdownMenuItem<String>>((c) {
                    return DropdownMenuItem<String>(
                      value: c['uid'] as String,
                      child: Text(c['nome'] ?? ''),
                    );
                  }).toList(),
                ),
              ],
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _carregando || _novoUid == null
              ? null
              : () async {
                  setState(() => _carregando = true);
                  try {
                    await widget.onConfirmar(_novoUid!);
                    if (mounted) Navigator.pop(context, true);
                  } finally {
                    if (mounted) setState(() => _carregando = false);
                  }
                },
          child: _carregando
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Transferir'),
        ),
      ],
    );
  }
}
