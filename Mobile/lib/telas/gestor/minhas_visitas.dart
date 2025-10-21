import 'dart:async';
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
  final _debouncer = _Debouncer(const Duration(milliseconds: 250));

  List<_Consultor> _consultores = [];
  String _query = '';
  bool _isLoading = true;
  String? _error;

  final Map<String, List<_RuaVisita>> _ruasPorConsultor = {};
  final Map<String, bool> _loadingRuas = {};

  @override
  void initState() {
    super.initState();
    _carregarConsultores();
    _searchCtrl.addListener(() {
      _debouncer.run(() {
        if (!mounted) return;
        setState(() => _query = _searchCtrl.text.trim());
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  Future<void> _carregarConsultores() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await _client
          .from('consultores')
          .select('id, uid, nome, ativo')
          .eq('ativo', true)
          .order('nome');

      final list = <_Consultor>[];
      if (res is List) {
        for (final c in res) {
          final id = c['id']?.toString();
          final uid = c['uid']?.toString();
          final nome = c['nome']?.toString();
          if (id != null && uid != null && nome != null) {
            list.add(_Consultor(id: id, uid: uid, nome: nome));
          }
        }
      }
      setState(() {
        _consultores = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Falha ao carregar consultores: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _carregarRuasDoConsultor(_Consultor consultor) async {
    final cacheKey = consultor.id;
    if (_loadingRuas[cacheKey] == true) return;
    _loadingRuas[cacheKey] = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });

    try {
      final now = DateTime.now().toUtc();
      final start = DateTime.utc(now.year, now.month, now.day).subtract(const Duration(days: 30));
      final end = DateTime.utc(now.year, now.month, now.day).add(const Duration(days: 60));
      final startStr = _yyyyMmDd(start);
      final endStr = _yyyyMmDd(end);

      final visitas = await _client
          .from('clientes')
          .select('endereco, bairro, cidade, estado, data_visita, consultor_uid_t')
          .eq('consultor_uid_t', consultor.uid)
          .gte('data_visita', startStr)
          .lte('data_visita', endStr)
          .order('data_visita');

      final ruas = <_RuaVisita>[];
      if (visitas is List) {
        for (final v in visitas) {
          final rua = '${v['endereco'] ?? ''}'.trim();
          if (rua.isEmpty) continue;
          final bairro = '${v['bairro'] ?? ''}'.trim();
          final cidade = '${v['cidade'] ?? ''}'.trim();
          final estado = '${v['estado'] ?? ''}'.trim();
          final data = _parseDate(v['data_visita']);
          ruas.add(_RuaVisita(
            rua: rua,
            local: [bairro, cidade, estado].where((s) => s.isNotEmpty).join(' - '),
            data: data,
          ));
        }
      }
      _ruasPorConsultor[cacheKey] = ruas;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar ruas de ${consultor.nome}: $e')),
        );
      }
      _ruasPorConsultor[cacheKey] = const <_RuaVisita>[];
    } finally {
      _loadingRuas[cacheKey] = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final consultoresFiltrados = _query.isEmpty
        ? _consultores
        : _consultores.where((c) => c.nome.toLowerCase().contains(_query.toLowerCase())).toList();

    final hasContent = !_isLoading && _error == null && consultoresFiltrados.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      appBar: const _HeaderCardLike(
        icon: Icons.groups_2_rounded,
        title: 'Minhas Visitas',
        subtitle: 'Visualize as ruas programadas por consultor',
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErroState(mensagem: _error!, onRetry: _carregarConsultores)
              : hasContent
                  ? RefreshIndicator(
                      onRefresh: _carregarConsultores,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        itemCount: consultoresFiltrados.length + 1,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, index) {
                          if (index == 0) {
                            return _CardContainer(
                              child: _SearchBar(controller: _searchCtrl, hint: 'Pesquisar consultor...'),
                            );
                          }
                          final c = consultoresFiltrados[index - 1];
                          final isLoading = _loadingRuas[c.id] == true;
                          final ruas = _ruasPorConsultor[c.id];

                          return _CardContainer(
                            child: ExpansionTile(
                              key: ValueKey('consultor_${c.id}'),
                              leading: Container(
                                width: 40,
                                height: 40,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.indigo.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _iniciais(c.nome),
                                  style: const TextStyle(
                                    color: Colors.indigo,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              title: Text(c.nome, style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text(
                                ruas == null
                                    ? 'Toque para ver ruas programadas'
                                    : '${ruas.length} rua${ruas.length == 1 ? '' : 's'} encontradas',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                              onExpansionChanged: (open) {
                                if (open && ruas == null) {
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    if (mounted) _carregarRuasDoConsultor(c);
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
                                    child: _EmptyHint(
                                      icon: Icons.place_outlined,
                                      title: 'Nenhuma rua programada',
                                      subtitle: 'Ajuste o período ou confira o vínculo do consultor.',
                                    ),
                                  )
                                else
                                  _RuasDoConsultor(ruas: ruas),
                              ],
                            ),
                          );
                        },
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: _CardContainer(
                        child: const Padding(
                          padding: EdgeInsets.fromLTRB(16, 24, 16, 24),
                          child: _EmptyHint(
                            icon: Icons.groups_2_rounded,
                            title: 'Nenhum consultor encontrado',
                            subtitle: 'Verifique os consultores ativos e as permissões (RLS).',
                          ),
                        ),
                      ),
                    ),
    );
  }

  String _iniciais(String nome) {
    final parts = nome.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '??';
    final first = parts.first;
    final second = parts.length > 1 ? parts.last : '';
    final a = first.isNotEmpty ? first[0] : '?';
    final b = second.isNotEmpty ? second[0] : (first.length > 1 ? first[1] : '');
    return (a + b).toUpperCase();
  }

  static String _yyyyMmDd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) {
      try {
        if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v)) {
          final p = v.split('-');
          return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
        }
        return DateTime.tryParse(v);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}

class _HeaderCardLike extends StatelessWidget implements PreferredSizeWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _HeaderCardLike({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Size get preferredSize => const Size.fromHeight(84);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      backgroundColor: const Color(0xFFF7F7F9),
      foregroundColor: Colors.black87,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.only(left: 16, top: 12, bottom: 12, right: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.indigo.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.indigo, size: 24),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CardContainer extends StatelessWidget {
  final Widget child;
  const _CardContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyHint({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 48, color: Colors.black38),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black54),
        ),
      ],
    );
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
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: ruas.length,
      itemBuilder: (_, i) => _tileRua(ruas[i]),
      separatorBuilder: (_, __) => const Divider(height: 8, thickness: 0),
    );
  }

  Widget _tileRua(_RuaVisita r) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Container(
        width: 40, 
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12), 
        ),
        child: const Icon(Icons.place_rounded, color: Colors.green, size: 22),
      ),
      title: Text(r.rua),
      subtitle: r.local.isNotEmpty ? Text(r.local) : null,
      trailing: r.data != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.indigo.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${r.data!.day.toString().padLeft(2, '0')}/${r.data!.month.toString().padLeft(2, '0')}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
            )
          : null,
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  const _SearchBar({required this.controller, this.hint = 'Pesquisar...'});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (_, value, __) {
        return TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => controller.clear(),
                    tooltip: 'Limpar',
                  ),
            filled: true,
            fillColor: const Color(0xFFF4F5F7),
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
      },
    );
  }
}

class _Consultor {
  final String id;   
  final String uid;  
  final String nome;
  _Consultor({required this.id, required this.uid, required this.nome});
}

class _RuaVisita {
  final String rua;
  final String local;
  final DateTime? data;
  _RuaVisita({required this.rua, required this.local, required this.data});
}

class _Debouncer {
  final Duration delay;
  Timer? _timer;
  _Debouncer(this.delay);
  void run(void Function() f) {
    _timer?.cancel();
    _timer = Timer(delay, f);
  }
  void dispose() => _timer?.cancel();
}

class _ErroState extends StatelessWidget {
  final String mensagem;
  final Future<void> Function() onRetry;

  const _ErroState({
    required this.mensagem,
    required this.onRetry,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: _CardContainer(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
              const SizedBox(height: 12),
              const Text(
                'Ocorreu um erro',
                style: TextStyle(fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(mensagem, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
