import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MinhasVisitasPage extends StatefulWidget {
  const MinhasVisitasPage({super.key});

  @override
  State<MinhasVisitasPage> createState() => _MinhasVisitasPageState();
}

class _MinhasVisitasPageState extends State<MinhasVisitasPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  final SupabaseClient _client = Supabase.instance.client;

  List<_Consultor> _consultores = [];
  String _query = '';
  bool _isLoading = true;

  final Map<String, List<_RuaVisita>> _ruasPorConsultor = {};
  final Map<String, bool> _loadingRuas = {};

  @override
  void initState() {
    super.initState();
    _carregarConsultores();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregarConsultores() async {
    setState(() => _isLoading = true);
    try {
      final res = await _client
          .from('consultores')
          .select('id, nome, ativo')
          .eq('ativo', true)
          .order('nome'); 

      final list = <_Consultor>[];
      if (res is List) {
        for (final c in res) {
          final id = c['id'] as String?;
          final nome = c['nome'] as String?;
          if (id != null && nome != null) {
            list.add(_Consultor(id: id, nome: nome));
          }
        }
      }
      setState(() {
        _consultores = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      setState(() => _isLoading = false);
    }
  }

  Future<void> _carregarRuasDoConsultor(String consultorId) async {
    if (_loadingRuas[consultorId] == true) return;
    _loadingRuas[consultorId] = true;
    setState(() {});
    try {
      final now = DateTime.now();
      final start = now.subtract(const Duration(days: 30));
      final end = now.add(const Duration(days: 60));
      final startStr = DateTime(start.year, start.month, start.day).toIso8601String().substring(0, 10);
      final endStr = DateTime(end.year, end.month, end.day).toIso8601String().substring(0, 10);

      final visitas = await _client
          .from('clientes')
          .select('endereco, bairro, cidade, estado, data_visita')
          .eq('consultor_uid_t', consultorId) 
          .gte('data_visita', startStr)     
          .lte('data_visita', endStr)
          .order('data_visita');           

      final ruas = <_RuaVisita>[];
      if (visitas is List) {
        for (final v in visitas) {
          final rua = (v['endereco'] as String?)?.trim() ?? '';
          if (rua.isEmpty) continue;
          final bairro = (v['bairro'] as String?) ?? '';
          final cidade = (v['cidade'] as String?) ?? '';
          final estado = (v['estado'] as String?) ?? '';
          final dataStr = v['data_visita'] as String?;
          DateTime? data;
          if (dataStr != null && dataStr.isNotEmpty) {
            try {
              final p = dataStr.split('-');
              data = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
            } catch (_) {}
          }
          ruas.add(_RuaVisita(
            rua: rua,
            local: [bairro, cidade, estado].where((s) => s.isNotEmpty).join(' - '),
            data: data,
          ));
        }
      }
      _ruasPorConsultor[consultorId] = ruas;
    } finally {
      _loadingRuas[consultorId] = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final consultoresFiltrados = _query.isEmpty
        ? _consultores
        : _consultores.where((c) => c.nome.toLowerCase().contains(_query.toLowerCase())).toList();

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _carregarConsultores,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: _SearchBar(controller: _searchCtrl, hint: 'Pesquisar consultor...'),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    sliver: SliverList.separated(
                      itemCount: consultoresFiltrados.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, index) {
                        final c = consultoresFiltrados[index];
                        final isLoading = _loadingRuas[c.id] == true;
                        final ruas = _ruasPorConsultor[c.id];

                        return Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 2,
                          child: ExpansionTile(
                            key: ValueKey('consultor_${c.id}'),
                            leading: CircleAvatar(child: Text(_iniciais(c.nome))),
                            title: Text(c.nome, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              ruas == null
                                  ? 'Toque para ver ruas programadas'
                                  : '${ruas.length} rua${ruas.length == 1 ? '' : 's'} encontradas',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            onExpansionChanged: (open) {
                              if (open) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  _carregarRuasDoConsultor(c.id);
                                });
                              }
                            },
                            children: [
                              if (isLoading)
                                const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(child: CircularProgressIndicator()),
                                )
                              else if (ruas == null)
                                const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text('Carregando...'),
                                )
                              else if (ruas.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text('Nenhuma rua programada no período'),
                                )
                              else
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                  child: _RuasDoConsultor(ruas: ruas),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String _iniciais(String nome) {
    final parts = nome.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return "??";
    final first = parts.first;
    final second = parts.length > 1 ? parts.last : "";
    return (first[0] + (second.isNotEmpty ? second[0] : first.length > 1 ? first[1] : '')).toUpperCase();
  }
}

class _RuasDoConsultor extends StatelessWidget {
  final List<_RuaVisita> ruas;
  const _RuasDoConsultor({required this.ruas});

  @override
  Widget build(BuildContext context) {
    if (ruas.length <= 8) {
      return Column(children: ruas.map(_tileRua).toList()); 
    }
    return SizedBox(
      height: 320,
      child: ListView.separated(
        itemCount: ruas.length,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(), 
        itemBuilder: (_, i) => _tileRua(ruas[i]),
        separatorBuilder: (_, __) => const Divider(height: 8, thickness: 0),
      ),
    );
  }

  Widget _tileRua(_RuaVisita r) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.place_outlined),
      title: Text(r.rua),
      subtitle: r.local.isNotEmpty ? Text(r.local) : null,
      trailing: r.data != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${r.data!.day.toString().padLeft(2, '0')}/${r.data!.month.toString().padLeft(2, '0')}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
            )
          : null,
    );
  }
}

class _Consultor {
  final String id;
  final String nome;
  _Consultor({required this.id, required this.nome});
}

class _RuaVisita {
  final String rua;
  final String local;
  final DateTime? data;
  _RuaVisita({required this.rua, required this.local, required this.data});
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  const _SearchBar({required this.controller, this.hint = 'Pesquisar...'});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => controller.clear(),
                tooltip: 'Limpar',
              ),
        filled: true,
        fillColor: const Color(0xFFF7F7F7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black12),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      ),
    );
  }
}
