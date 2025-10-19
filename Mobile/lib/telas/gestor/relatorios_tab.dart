import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class RelatoriosTab extends StatefulWidget {
  const RelatoriosTab({super.key});

  @override
  State<RelatoriosTab> createState() => _RelatoriosTabState();
}

class _RelatoriosTabState extends State<RelatoriosTab> {
  final List<String> _consultoresIds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    final gestorId = Supabase.instance.client.auth.currentSession?.user.id;
    if (gestorId == null) return;

    setState(() => _isLoading = true);

    try {
      final consultores = await Supabase.instance.client
          .from('consultores')
          .select('id')
          .eq('gestor_id', gestorId);

      setState(() {
        _consultoresIds
          ..clear()
          ..addAll((consultores as List).map((c) => (c as Map<String, dynamic>)['id'].toString()));
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Erro ao carregar dados: $error');
      setState(() => _isLoading = false);
    }
  }

  String _iniciais(String nome) {
    final parts = nome.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return "??";
    final first = parts.first;
    final second = parts.length > 1 ? parts.last : "";
    return (first[0] + (second.isNotEmpty ? second[0] : first.length > 1 ? first[1] : '')).toUpperCase();
  }

  DateTime? _parseData(dynamic data) {
    if (data == null) return null;
    if (data is String && data.isNotEmpty) {
      try {
        final p = data.split('-'); 
        return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
      } catch (_) {}
    }
    return null;
  }

  Widget _buildHeader() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.analytics_rounded, color: cs.onPrimaryContainer, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Relatórios',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      )),
              const SizedBox(height: 4),
              Text('Visão geral das atividades da sua equipe',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: const Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Carregando relatórios...'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final DateTime inicioMes = DateTime(now.year, now.month, 1);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _carregarDados,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            if (_isLoading)
              SliverToBoxAdapter(child: _buildLoadingState())
            else
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(Icons.assignment_ind_rounded, color: Theme.of(context).colorScheme.primary, size: 24),
                              const SizedBox(width: 12),
                              Text('Desempenho dos Consultores',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      )),
                            ]),
                            const SizedBox(height: 8),
                            Text('Visitas totais e no mês por consultor',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    )),
                            const SizedBox(height: 20),
                            _consultoresIds.isEmpty
                                ? _buildEmptyConsultoresState()
                                : FutureBuilder<List<Widget>>(
                                    future: _buildConsultoresStats(inicioMes),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState == ConnectionState.waiting) {
                                        return const Center(child: CircularProgressIndicator());
                                      }
                                      if (snapshot.hasError) {
                                        return _buildErrorState('Erro ao carregar consultores');
                                      }
                                      return Column(children: snapshot.data ?? []);
                                    },
                                  ),
                          ],
                        ),
                      ),
                    ),

                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(Icons.access_time_rounded, color: Theme.of(context).colorScheme.primary, size: 24),
                              const SizedBox(width: 12),
                              Text('Atividade Recente',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      )),
                            ]),
                            const SizedBox(height: 8),
                            Text('Últimas visitas registradas pela sua equipe',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    )),
                            const SizedBox(height: 20),
                            _consultoresIds.isEmpty
                                ? _buildEmptyAtividadesState()
                                : FutureBuilder<List<Widget>>(
                                    future: _buildAtividadesRecentes(),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState == ConnectionState.waiting) {
                                        return const Center(child: CircularProgressIndicator());
                                      }
                                      if (snapshot.hasError) {
                                        return _buildErrorState('Erro ao carregar atividades');
                                      }
                                      return Column(children: snapshot.data ?? []);
                                    },
                                  ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyConsultoresState() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.people_outline_rounded, size: 48, color: cs.onSurface.withOpacity(0.4)),
          const SizedBox(height: 12),
          Text('Nenhum consultor cadastrado',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurface.withOpacity(0.6))),
          const SizedBox(height: 8),
          Text('Cadastre consultores para ver os relatórios',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurface.withOpacity(0.4))),
        ],
      ),
    );
  }

  Widget _buildEmptyAtividadesState() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.assignment_outlined, size: 48, color: cs.onSurface.withOpacity(0.4)),
          const SizedBox(height: 12),
          Text('Nenhum registro recente',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurface.withOpacity(0.6))),
          const SizedBox(height: 8),
          Text('Os registros da sua equipe aparecerão aqui',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurface.withOpacity(0.4))),
        ],
      ),
    );
  }

  Widget _buildErrorState(String mensagem) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(Icons.error_outline_rounded, color: cs.error, size: 48),
          const SizedBox(height: 12),
          Text(mensagem, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.error)),
        ],
      ),
    );
  }

  Future<List<Widget>> _buildConsultoresStats(DateTime inicioMes) async {
    final List<Widget> stats = [];

    for (final consultorId in _consultoresIds) {
      try {
        final consultor = await Supabase.instance.client
            .from('consultores')
            .select('nome')
            .eq('id', consultorId)
            .single();

        final nome = (consultor['nome'] as String?) ?? 'Sem nome';

        final clientes = await Supabase.instance.client
            .from('clientes')
            .select('id, data_visita')
            .eq('consultor_uid_t', consultorId);

        final List<dynamic> clientesList = clientes as List;

        final int total = clientesList.length;
        final int mes = clientesList.where((cliente) {
          final dv = cliente['data_visita'] as String?;
          final DateTime? data = _parseData(dv);
          return data != null && !data.isBefore(inicioMes);
        }).length;

        stats.add(
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      _iniciais(nome),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(nome, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text('$total visitas totais',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            )),
                  ]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('$mes este mês',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      )),
                ),
              ],
            ),
          ),
        );
      } catch (error) {
        debugPrint('Erro ao carregar stats do consultor $consultorId: $error');
      }
    }

    return stats;
  }

  Future<List<Widget>> _buildAtividadesRecentes() async {
    final List<Widget> atividades = [];

    try {
      if (_consultoresIds.isEmpty) return atividades;

      final lista = '(${_consultoresIds.join(',')})'; 
      final clientes = await Supabase.instance.client
          .from('clientes')
          .select('nome, bairro, data_visita')
          .filter('consultor_uid_t', 'in', lista)
          .order('data_visita', ascending: false)
          .limit(10);

      final List<dynamic> clientesList = clientes as List;

      for (final cliente in clientesList) {
        final nomeCliente = (cliente['nome'] as String?) ?? 'Cliente';
        final bairro = (cliente['bairro'] as String?) ?? 'sem bairro';
        final dv = cliente['data_visita'] as String?;
        final DateTime? data = _parseData(dv);
        final dataFormatada = data != null ? DateFormat('dd/MM').format(data) : 'Data inválida';

        atividades.add(
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.person_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(nomeCliente,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(bairro,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            )),
                  ]),
                ),
                const SizedBox(width: 12),
                Text(
                  dataFormatada,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (error) {
      debugPrint('Erro ao carregar atividades: $error');
    }

    return atividades;
  }
}
