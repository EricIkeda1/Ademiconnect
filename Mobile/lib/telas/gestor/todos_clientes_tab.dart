import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ademicon_app/services/consultor_service.dart';
import 'package:ademicon_app/models/cliente.dart';

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
    final gestorId = Supabase.instance.client.auth.currentSession?.user.id;
    if (gestorId == null) return;

    setState(() => _isLoading = true);

    try {
      final consultores = await _consultorService.getConsultoresByGestor(gestorId);
      _consultoresDoGestor
        ..clear()
        ..addEntries(consultores.map((c) => MapEntry(c.uid, c.nome)));
      for (final c in consultores) {
        _expandedStates.putIfAbsent(c.nome, () => false);
      }

      if (_consultoresDoGestor.isNotEmpty) {
        final uids = _consultoresDoGestor.keys.toList();
        debugPrint('UIDs consultores do gestor: $uids'); 

        final baseQuery = Supabase.instance.client
            .from('clientes')
            .select('id, estabelecimento, cidade, estado, data_visita, consultor_uid_t');

        PostgrestFilterBuilder<List<Map<String, dynamic>>> q;
        try {
          q = baseQuery.inFilter('consultor_uid_t', uids); 
        } catch (_) {
          final lista = '(${uids.join(',')})'; 
          q = baseQuery.filter('consultor_uid_t', 'in', lista);
        }

        final response = await q.order('data_visita', ascending: true);

        _clientes = (response as List)
            .map((row) => Cliente.fromMap(row as Map<String, dynamic>))
            .toList();

        debugPrint('Total clientes retornados: ${_clientes.length}'); 
      } else {
        _clientes = [];
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar clientes: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _toggleExpansion(String consultorNome) {
    setState(() {
      _expandedStates[consultorNome] = !(_expandedStates[consultorNome] ?? false);
    });
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
            SliverToBoxAdapter(child: _buildHeader()),
            if (_isLoading)
              SliverToBoxAdapter(child: _buildLoadingState())
            else if (_clientes.isEmpty)
              SliverToBoxAdapter(child: _buildEmptyState())
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
            child: Icon(Icons.people_outline_rounded, color: cs.onPrimaryContainer, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Todos os Clientes',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      )),
              const SizedBox(height: 4),
              Text('Visualize todos os clientes cadastrados pela sua equipe',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final cs = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.people_outline_rounded, size: 64, color: cs.onSurface.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text('Nenhum cliente encontrado',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: cs.onSurface.withOpacity(0.7))),
            const SizedBox(height: 8),
            Text('Verifique os consultores do gestor e as permissões de leitura (RLS).',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurface.withOpacity(0.5))),
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

  Widget _buildConsultorCard(String consultor, List<Cliente> clientes) {
    final isExpanded = _expandedStates[consultor] ?? false;
    final clientesRecentes =
        clientes.where((c) => c.dataVisita.isAfter(DateTime.now().subtract(const Duration(days: 7)))).length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: ExpansionTile(
        leading: _consultorAvatar(context, consultor),
        title: Text(consultor, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${clientes.length} cliente${clientes.length == 1 ? '' : 's'} • $clientesRecentes recentes',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
        trailing: Icon(
          isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: clientes.map((c) => _buildClienteTile(c)).toList()),
          ),
        ],
        onExpansionChanged: (_) => _toggleExpansion(consultor),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _consultorAvatar(BuildContext context, String nome) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(12)),
      child: Center(
        child: Text(
          _iniciais(nome),
          style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildClienteTile(Cliente c) {
    final bool recente = c.dataVisita.isAfter(DateTime.now().subtract(const Duration(days: 7)));
    final dataFormatada =
        "${c.dataVisita.day.toString().padLeft(2, '0')}/${c.dataVisita.month.toString().padLeft(2, '0')}/${c.dataVisita.year}";

    final cs = Theme.of(context).colorScheme;
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
            color: recente ? Colors.green.withOpacity(0.1) : cs.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.business_rounded, size: 20, color: recente ? Colors.green.shade700 : cs.onSurfaceVariant),
        ),
        title: Text(c.estabelecimento, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Icon(Icons.location_on_outlined, size: 14, color: cs.onSurfaceVariant),
              const SizedBox(width: 4),
              Text('${c.cidade} - ${c.estado}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: recente ? Colors.green.withOpacity(0.1) : cs.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: recente ? Colors.green.withOpacity(0.3) : cs.outline.withOpacity(0.3)),
          ),
          child: Text(
            dataFormatada,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: recente ? Colors.green.shade700 : cs.onSurfaceVariant,
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
    return (first[0] + (second.isNotEmpty ? second[0] : first.length > 1 ? first[1] : '')).toUpperCase();
  }
}
