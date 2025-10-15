import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/cliente.dart';
import '../../services/consultor_service.dart';

class TodosClientesTab extends StatefulWidget {
  const TodosClientesTab({super.key});

  @override
  State<TodosClientesTab> createState() => _TodosClientesTabState();
}

class _TodosClientesTabState extends State<TodosClientesTab> {
  final _consultorService = ConsultorService();
  bool _isLoading = true;
  List<Cliente> _clientes = [];
  Map<String, String> _consultoresDoGestor = {};
  final Map<String, bool> _expandedStates = {};

  @override
  void initState() {
    super.initState();
    _loadClientes();
  }

  Future<void> _loadClientes() async {
    final gestorUid = FirebaseAuth.instance.currentUser?.uid;
    if (gestorUid == null) return;

    setState(() => _isLoading = true);

    final consultores = await _consultorService.getConsultoresByGestor(gestorUid);
    _consultoresDoGestor.clear();
    for (var c in consultores) {
      _consultoresDoGestor[c.uid] = c.nome;
      _expandedStates[c.nome] = false;
    }

    if (_consultoresDoGestor.isNotEmpty) {
      final snapshot = await FirebaseFirestore.instance
          .collection('clientes')
          .where('consultorUid', whereIn: _consultoresDoGestor.keys.toList())
          .get();

      _clientes = snapshot.docs.map((doc) => Cliente.fromFirestore(doc)).toList();
    } else {
      _clientes = [];
    }

    setState(() => _isLoading = false);
  }

  void _toggleExpansion(String consultorNome) {
    setState(() {
      _expandedStates[consultorNome] = !(_expandedStates[consultorNome] ?? false);
    });
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
              Icons.people_outline_rounded,
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
                  'Todos os Clientes',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Visualize todos os clientes cadastrados pela sua equipe',
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

  Widget _buildEmptyState() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum cliente cadastrado',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Seus consultores ainda não cadastraram clientes',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
            Text('Carregando clientes...'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, List<Cliente>> clientesPorConsultor = {};
    for (var c in _clientes) {
      final nome = _consultoresDoGestor[c.consultorUid] ?? 'Consultor não encontrado';
      clientesPorConsultor.putIfAbsent(nome, () => []).add(c);
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadClientes,
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
            else if (_clientes.isEmpty)
              SliverToBoxAdapter(
                child: _buildEmptyState(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final entry = clientesPorConsultor.entries.toList()[index];
                      return _buildConsultorCard(entry.key, entry.value);
                    },
                    childCount: clientesPorConsultor.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsultorCard(String consultor, List<Cliente> clientes) {
    final isExpanded = _expandedStates[consultor] ?? false;
    final clientesRecentes = clientes.where((c) => 
      c.dataVisita.isAfter(DateTime.now().subtract(const Duration(days: 7)))
    ).length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: ExpansionTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              _iniciais(consultor),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ),
        title: Text(
          consultor,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${clientes.length} cliente${clientes.length == 1 ? '' : 's'} • $clientesRecentes recentes',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        trailing: Icon(
          isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: clientes.map((cliente) => _buildClienteTile(cliente)).toList(),
            ),
          ),
        ],
        onExpansionChanged: (expanded) => _toggleExpansion(consultor),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildClienteTile(Cliente c) {
    final bool recente = c.dataVisita.isAfter(DateTime.now().subtract(const Duration(days: 7)));
    final dataFormatada = "${c.dataVisita.day.toString().padLeft(2, '0')}/"
        "${c.dataVisita.month.toString().padLeft(2, '0')}/"
        "${c.dataVisita.year}";

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: recente 
                ? Colors.green.withOpacity(0.1)
                : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.business_rounded,
            size: 20,
            color: recente 
                ? Colors.green.shade700
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        title: Text(
          c.estabelecimento,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  '${c.cidade} - ${c.estado}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: recente 
                ? Colors.green.withOpacity(0.1)
                : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: recente 
                  ? Colors.green.withOpacity(0.3)
                  : Theme.of(context).colorScheme.outline.withOpacity(0.3),
            ),
          ),
          child: Text(
            dataFormatada,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: recente 
                  ? Colors.green.shade700
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  String _iniciais(String nome) {
    final parts = nome.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return "??";
    final first = parts.first;
    final second = parts.length > 1 ? parts.last : "";
    return (first[0] + (second.isNotEmpty ? second[0] : first.length > 1 ? first[1] : ''))
        .toUpperCase();
  }
}