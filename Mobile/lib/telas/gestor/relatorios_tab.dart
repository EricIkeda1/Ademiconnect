import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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
    final gestorUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (gestorUid.isEmpty) return;

    try {
      // Carrega consultores do gestor
      final consultoresSnapshot = await FirebaseFirestore.instance
          .collection('consultores')
          .where('gestorId', isEqualTo: gestorUid)
          .get();

      setState(() {
        _consultoresIds.clear();
        _consultoresIds.addAll(consultoresSnapshot.docs.map((doc) => doc.id).toList());
        _isLoading = false;
      });
    } catch (e) {
      print('Erro ao carregar dados: $e');
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
    
    if (data is Timestamp) {
      return data.toDate();
    } else if (data is String) {
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
        final consultorDoc = await FirebaseFirestore.instance
            .collection('consultores')
            .doc(consultorId)
            .get();

        if (consultorDoc.exists) {
          final nome = consultorDoc.get('nome') as String? ?? 'Sem nome';

          // Busca clientes do consultor - usando 'consultorId'
          final clientesSnapshot = await FirebaseFirestore.instance
              .collection('clientes')
              .where('consultorId', isEqualTo: consultorId)
              .get();

          int total = clientesSnapshot.docs.length;
          int mes = clientesSnapshot.docs.where((doc) {
            final dataCadastro = doc.get('data_cadastro');
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
        }
      } catch (e) {
        print('Erro ao carregar stats do consultor $consultorId: $e');
      }
    }

    return stats;
  }

  Future<List<Widget>> _buildAtividadesRecentes() async {
    final List<Widget> atividades = [];

    try {
      // SOLUÇÃO ALTERNATIVA: Busca todos os clientes e filtra manualmente
      // Isso evita a necessidade de índice composto
      final clientesSnapshot = await FirebaseFirestore.instance
          .collection('clientes')
          .get();

      // Filtra apenas os clientes dos consultores do gestor
      final clientesFiltrados = clientesSnapshot.docs.where((doc) {
        final consultorId = doc.get('consultorId') as String?;
        return consultorId != null && _consultoresIds.contains(consultorId);
      }).toList();

      // Ordena manualmente por data_cadastro
      clientesFiltrados.sort((a, b) {
        final dataA = _parseData(a.get('data_cadastro'));
        final dataB = _parseData(b.get('data_cadastro'));
        if (dataA == null) return 1;
        if (dataB == null) return -1;
        return dataB.compareTo(dataA); // Ordem decrescente
      });

      // Pega os 10 mais recentes
      final clientesRecentes = clientesFiltrados.take(10).toList();

      for (final doc in clientesRecentes) {
        final nomeCliente = doc.get('nome') as String? ?? 'Cliente';
        final bairro = doc.get('bairro') as String? ?? 'sem bairro';
        final dataCadastro = doc.get('data_cadastro');
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
    } catch (e) {
      print('Erro ao carregar atividades: $e');
    }

    return atividades;
  }
}