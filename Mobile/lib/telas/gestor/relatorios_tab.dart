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
      // 1. Busca consultores do gestor
      // Correção: use 'gestor_id' (snake_case) em vez de 'gestorId'
      final consultores = await Supabase.instance.client
          .from('consultores')
          .select('id')
          .eq('gestor_id', gestorId); // Correção: campo em snake_case

      setState(() {
        _consultoresIds.clear();
        _consultoresIds.addAll((consultores as List)
            .map((c) => (c as Map<String, dynamic>)['id'].toString()));
        _isLoading = false;
      });
    } catch (error) {
      print('Erro ao carregar dados: $error');
      setState(() => _isLoading = false);
    }
  }

  String _iniciais(String nome) {
    final parts = nome.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return "??";
    final first = parts.first;
    final second = parts.length > 1 ? parts.last : "";
    return (first[0] + (second.isNotEmpty ? second[0] : first.length > 1 ? first[1] : ''))
        .toUpperCase();
  }

  DateTime? _parseData(dynamic data) {
    if (data == null) return null;

    if (data is String) {
      try {
        return DateTime.parse(data);
      } catch (e) {
        print('Erro ao parse data: $data, erro: $e');
        return null;
      }
    }
    return null;
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.analytics_rounded,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Relatórios',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Visão geral das atividades da sua equipe',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
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
            // Header
            SliverToBoxAdapter(
              child: _buildHeader(),
            ),

            // Conteúdo
            if (_isLoading)
              SliverToBoxAdapter(
                child: _buildLoadingState(),
              )
            else
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    // Card de Desempenho dos Consultores
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.assignment_ind_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Desempenho dos Consultores',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Número total e deste mês por consultor',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
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

                    // Card de Atividade Recente
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Atividade Recente',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Últimos cadastros feitos pela sua equipe',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(
            Icons.people_outline_rounded,
            size: 48,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
          ),
          const SizedBox(height: 12),
          Text(
            'Nenhum consultor cadastrado',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Cadastre consultores para ver os relatórios',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyAtividadesState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
          ),
          const SizedBox(height: 12),
          Text(
            'Nenhum cadastro recente',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Os cadastros da sua equipe aparecerão aqui',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String mensagem) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: Theme.of(context).colorScheme.error,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            mensagem,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<List<Widget>> _buildConsultoresStats(DateTime inicioMes) async {
    final List<Widget> stats = [];

    for (final consultorId in _consultoresIds) {
      try {
        // Busca dados do consultor
        // Correção: use 'nome' (snake_case) em vez de 'nome'
        final consultor = await Supabase.instance.client
            .from('consultores')
            .select('nome')
            .eq('id', consultorId)
            .single();

        final nome = (consultor['nome'] as String?) ?? 'Sem nome';

        // Busca clientes do consultor
        // Correção: use 'consultor_uid' (snake_case) em vez de 'consultorUid'
        final clientes = await Supabase.instance.client
            .from('clientes')
            .select('*')
            .eq('consultor_uid', consultorId); // Correção: campo em snake_case

        final List<dynamic> clientesList = clientes as List;

        int total = clientesList.length;
        int mes = clientesList.where((cliente) {
          // Correção: use 'data_cadastro' (snake_case) em vez de 'dataCadastro'
          final dataCadastro = cliente['data_cadastro'] as String?;
          final DateTime? data = _parseData(dataCadastro);
          return data != null && data.isAfter(inicioMes);
        }).length;

        stats.add(
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              ),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nome,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$total cadastros totais',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$mes este mês',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } catch (error) {
        print('Erro ao carregar stats do consultor $consultorId: $error');
      }
    }

    return stats;
  }

  Future<List<Widget>> _buildAtividadesRecentes() async {
    final List<Widget> atividades = [];

    try {
      // Busca clientes dos consultores do gestor, ordenados por data_cadastro
      // Correções:
      // 1. Use 'contains' no lugar de 'in_'
      // 2. Use 'consultor_uid' (snake_case) em vez de 'consultorUid'
      // 3. Use 'data_cadastro' (snake_case) em vez de 'dataCadastro'
      final clientes = await Supabase.instance.client
          .from('clientes')
          .select('*')
          .contains('consultor_uid', _consultoresIds) // Correção: contains em vez de in_
          .order('data_cadastro', ascending: false) // Correção: campo em snake_case
          .limit(10);

      final List<dynamic> clientesList = clientes as List;

      for (final cliente in clientesList) {
        final nomeCliente = (cliente['nome'] as String?) ?? 'Cliente';
        final bairro = (cliente['bairro'] as String?) ?? 'sem bairro';
        // Correção: use 'data_cadastro' (snake_case) em vez de 'dataCadastro'
        final dataCadastro = cliente['data_cadastro'] as String?;
        final DateTime? data = _parseData(dataCadastro);
        final dataFormatada = data != null
            ? DateFormat('dd/MM HH:mm').format(data)
            : 'Data inválida';

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
                  child: Icon(
                    Icons.person_rounded,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nomeCliente,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        bairro,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
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
      print('Erro ao carregar atividades: $error');
    }

    return atividades;
  }
}
