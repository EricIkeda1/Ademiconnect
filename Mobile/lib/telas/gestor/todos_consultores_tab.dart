import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ConsultorResumo {
  final String id;   
  final String uid;  
  final String nome;
  final bool ativo;
  ConsultorResumo({required this.id, required this.uid, required this.nome, required this.ativo});
}

class TodosConsultoresTab extends StatefulWidget {
  const TodosConsultoresTab({super.key});

  @override
  State<TodosConsultoresTab> createState() => _TodosConsultoresTabState();
}

class _TodosConsultoresTabState extends State<TodosConsultoresTab> {
  final SupabaseClient _client = Supabase.instance.client;
  bool _isLoading = true;
  List<ConsultorResumo> _consultores = [];
  final Map<String, bool> _expandedStates = {};

  @override
  void initState() {
    super.initState();
    _loadConsultores();
  }

  Future<void> _loadConsultores() async {
    final gestorId = _client.auth.currentSession?.user.id;
    if (gestorId == null) return;

    setState(() => _isLoading = true);
    try {
      final data = await _client
          .from('consultores')
          .select('id, uid, nome, ativo')
          .eq('gestor_id', gestorId)
          .order('nome', ascending: true);

      final list = <ConsultorResumo>[];
      if (data is List) {
        for (final row in data) {
          final id = row['id']?.toString();
          final uid = row['uid']?.toString();
          final nome = row['nome']?.toString() ?? 'Sem nome';
          final ativo = (row['ativo'] is bool) ? row['ativo'] as bool : true;
          if (id != null && uid != null) {
            list.add(ConsultorResumo(id: id, uid: uid, nome: nome, ativo: ativo));
            _expandedStates.putIfAbsent(id, () => false);
          }
        }
      }

      setState(() => _consultores = list);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao carregar consultores: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleExpansion(String consultorId) {
    setState(() {
      _expandedStates[consultorId] = !(_expandedStates[consultorId] ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadConsultores,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            if (_isLoading)
              SliverToBoxAdapter(child: _buildLoadingState())
            else if (_consultores.isEmpty)
              SliverToBoxAdapter(child: _buildEmptyState())
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildConsultorCard(_consultores[index]),
                    childCount: _consultores.length,
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
            alignment: Alignment.center,
            decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.group_outlined, color: cs.onPrimaryContainer, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Todos os Consultores',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      )),
              const SizedBox(height: 4),
              Text('Gerencie perfis, exclusões e transferência de clientes',
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
            Icon(Icons.group_outlined, size: 64, color: cs.onSurface.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text('Nenhum consultor encontrado',
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
            Text('Carregando consultores...'),
          ],
        ),
      ),
    );
  }

  Widget _buildConsultorCard(ConsultorResumo c) {
    final cs = Theme.of(context).colorScheme;
    final isExpanded = _expandedStates[c.id] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: ExpansionTile(
        leading: _consultorAvatar(context, c.nome),
        title: Text(c.nome, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(c.ativo ? 'Ativo' : 'Inativo',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        ),
        trailing: Icon(isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: cs.onSurfaceVariant),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: EdgeInsets.zero,
        onExpansionChanged: (_) => _toggleExpansion(c.id),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                _adminActionTile(
                  icon: Icons.edit_outlined,
                  label: 'Editar perfil e dados',
                  subtitle: 'Atualize nome, status e informações do consultor',
                  onTap: () => _onEditarConsultor(c),
                ),
                const SizedBox(height: 8),
                _adminActionTile(
                  icon: Icons.swap_horiz_rounded,
                  label: 'Transferir clientes',
                  subtitle: 'Transfira todos os clientes para outro consultor',
                  onTap: () => _onTransferirClientes(c),
                ),
                const SizedBox(height: 8),
                _adminActionTile(
                  icon: Icons.delete_outline_rounded,
                  label: 'Apagar consultor',
                  subtitle: 'Remove o consultor (prefira transferir clientes antes)',
                  danger: true,
                  onTap: () => _onApagarConsultor(c),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _adminActionTile({
    required IconData icon,
    required String label,
    String? subtitle,
    bool danger = false,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    final color = danger ? cs.error : cs.primary;
    final bg = danger ? cs.errorContainer.withOpacity(0.08) : cs.primaryContainer.withOpacity(0.10);
    final ico = danger ? cs.error : cs.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: (danger ? cs.error.withOpacity(0.25) : cs.outline.withOpacity(0.25))),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: ico.withOpacity(0.10), borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: Icon(icon, size: 22, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(subtitle, style: TextStyle(color: cs.onSurfaceVariant)),
                    ),
                ]),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
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

  Future<void> _onEditarConsultor(ConsultorResumo c) async {
    final nomeCtrl = TextEditingController(text: c.nome);
    bool ativo = c.ativo;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar consultor'),
        content: StatefulBuilder(
          builder: (ctx, setS) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nomeCtrl, decoration: const InputDecoration(labelText: 'Nome')),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ativo'),
                value: ativo,
                onChanged: (v) => setS(() => ativo = v),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton.icon(onPressed: () => Navigator.pop(ctx, true), icon: const Icon(Icons.save_outlined), label: const Text('Salvar')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await _client.from('consultores').update({
        'nome': nomeCtrl.text.trim(),
        'ativo': ativo,
      }).eq('id', c.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Consultor atualizado com sucesso.')));
      await _loadConsultores();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao atualizar consultor: $e')));
    }
  }

  Future<void> _onApagarConsultor(ConsultorResumo c) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apagar consultor'),
        content: Text('Tem certeza que deseja apagar ${c.nome}? Esta ação não poderá ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_outline_rounded),
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            label: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      await _client.from('consultores').delete().eq('id', c.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Consultor removido.')));
      await _loadConsultores();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao remover consultor: $e')));
    }
  }

  Future<void> _onTransferirClientes(ConsultorResumo origem) async {
    final destinos = _consultores.where((x) => x.id != origem.id).toList();
    if (destinos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não há outro consultor para transferir clientes.')));
      return;
    }
    ConsultorResumo? destinoSel;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Transferir clientes'),
        content: StatefulBuilder(
          builder: (ctx, setS) => DropdownButtonFormField<ConsultorResumo>(
            value: destinoSel,
            items: destinos.map((d) => DropdownMenuItem(value: d, child: Text(d.nome))).toList(),
            onChanged: (v) => setS(() => destinoSel = v),
            decoration: const InputDecoration(labelText: 'Transferir para'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton.icon(
            onPressed: destinoSel == null ? null : () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.swap_horiz_rounded),
            label: const Text('Transferir'),
          ),
        ],
      ),
    );

    if (ok != true || destinoSel == null) return;
    final ConsultorResumo destino = destinoSel!;

    try {
      await _client
          .from('clientes')
          .update({'consultor_uid_t': destino.uid})
          .eq('consultor_uid_t', origem.uid);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Clientes transferidos de ${origem.nome} para ${destino.nome}.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao transferir clientes: $e')));
    }
  }

  String _iniciais(String nome) {
    final parts = nome.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return "??";
    final first = parts.first;
    final second = parts.length > 1 ? parts.last : "";
    return (first[0] + (second.isNotEmpty ? second[0] : (first.length > 1 ? first[1] : ''))).toUpperCase();
  }
}
