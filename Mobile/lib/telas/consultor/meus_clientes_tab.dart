import '../../models/cliente.dart';
import '../../services/cliente_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MeusClientesTab extends StatefulWidget {
  final VoidCallback? onClienteRemovido;

  const MeusClientesTab({super.key, this.onClienteRemovido});

  @override
  State<MeusClientesTab> createState() => _MeusClientesTabState();
}

class _MeusClientesTabState extends State<MeusClientesTab> {
  final ClienteService _clienteService = ClienteService();
  final List<Cliente> _clientes = [];
  String _termoBusca = '';
  String? _meuUid;
  bool _isLoading = true;
  final Map<String, bool> _expandedStates = {};

  @override
  void initState() {
    super.initState();
    _meuUid = FirebaseAuth.instance.currentUser?.uid;
    _carregarClientes();
  }

  Future<void> _carregarClientes() async {
    if (_meuUid == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      await _clienteService.loadClientes();
      setState(() {
        _clientes.clear();
        _clientes.addAll(
          _clienteService.clientes.where((c) => c.consultorUid == _meuUid).toList(),
        );
        for (var cliente in _clientes) {
          _expandedStates[cliente.id] = false;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar clientes: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _atualizarListaClientes() async {
    await _carregarClientes();
  }

  Future<void> _reordenarClientes(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;

    setState(() {
      final Cliente item = _clientes.removeAt(oldIndex);
      _clientes.insert(newIndex, item);
    });

    await _salvarOrdemClientes();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ordem dos clientes atualizada!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _salvarOrdemClientes() async {
    for (final cliente in _clientes) {
      await _clienteService.saveCliente(cliente);
    }
  }

  Future<void> _confirmarExclusaoCliente(Cliente cliente) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Cliente'),
        content: Text('Tem certeza que deseja excluir ${cliente.estabelecimento}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Excluir',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _clienteService.removeCliente(cliente.id);
        _expandedStates.remove(cliente.id);
        await _atualizarListaClientes();
        widget.onClienteRemovido?.call();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cliente excluído com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir cliente: $e'),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      }
    }
  }

  void _toggleExpansion(String clienteId) {
    setState(() {
      _expandedStates[clienteId] = !(_expandedStates[clienteId] ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final clientesFiltrados = _clientes.where((c) {
      final textoBusca =
          '${c.estabelecimento} ${c.estado} ${c.cidade} ${c.endereco} ${c.nomeCliente ?? ''} ${c.telefone ?? ''}'
              .toLowerCase();
      return textoBusca.contains(_termoBusca.toLowerCase());
    }).toList();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _atualizarListaClientes,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
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
                        Icons.people_rounded,
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
                            'Meus Clientes',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Gerencie e organize seus clientes',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        decoration: InputDecoration(
                          prefixIcon: Icon(
                            Icons.search_rounded, 
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          suffixIcon: _termoBusca.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.clear_rounded, 
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                  onPressed: () => setState(() => _termoBusca = ''),
                                )
                              : null,
                          hintText: 'Buscar por estabelecimento, cidade, cliente...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                        ),
                        onChanged: (v) => setState(() => _termoBusca = v),
                      ),
                      const SizedBox(height: 20),

                      if (!_isLoading && _clientes.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.tonalIcon(
                              onPressed: _atualizarListaClientes,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Atualizar Lista'),
                            ),
                          ),
                        ),

                      if (_isLoading)
                        _buildLoadingState()
                      else if (clientesFiltrados.isEmpty)
                        _buildEmptyState()
                      else
                        _buildClientesList(clientesFiltrados),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.people_outline_rounded,
                size: 40,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _termoBusca.isEmpty 
                  ? 'Nenhum cliente cadastrado'
                  : 'Nenhum cliente encontrado',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
              textAlign: TextAlign.center,
            ),
            if (_termoBusca.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Adicione seu primeiro cliente para começar',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Carregando clientes...'),
          ],
        ),
      ),
    );
  }

  Widget _buildClientesList(List<Cliente> clientesFiltrados) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Contador e instrução
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${clientesFiltrados.length} cliente${clientesFiltrados.length == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if (clientesFiltrados.length > 1)
                Row(
                  children: [
                    Icon(
                      Icons.drag_handle,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Arraste para reordenar',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        
        Container(
          height: MediaQuery.of(context).size.height * 0.5, 
          child: ReorderableListView.builder(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: clientesFiltrados.length,
            onReorder: _reordenarClientes,
            itemBuilder: (context, index) {
              final c = clientesFiltrados[index];
              final dataHoraFormatada = DateFormat('dd/MM/yyyy HH:mm').format(c.dataVisita);
              final isExpanded = _expandedStates[c.id] ?? false;

              return Card(
                key: Key(c.id),
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 1,
                child: ExpansionTile(
                  key: Key('${c.id}_tile'),
                  initiallyExpanded: isExpanded,
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.drag_handle,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    c.estabelecimento,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: !isExpanded ? _buildPreviewInfo(c, context) : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        onPressed: () => _confirmarExclusaoCliente(c),
                        tooltip: 'Excluir cliente',
                      ),
                      Icon(
                        isExpanded 
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildDetailedInfo(c, dataHoraFormatada, context),
                    ),
                  ],
                  onExpansionChanged: (expanded) {
                    Future.delayed(const Duration(milliseconds: 100), () {
                      if (mounted) {
                        _toggleExpansion(c.id);
                      }
                    });
                  },
                  tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                  childrenPadding: EdgeInsets.zero,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewInfo(Cliente c, BuildContext context) {
    return Column(
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
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${c.cidade} - ${c.estado}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          c.endereco,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.8),
              ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildDetailedInfo(Cliente c, String dataHoraFormatada, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow(
          icon: Icons.location_on_outlined,
          title: 'Localização',
          content: '${c.cidade} - ${c.estado}',
          context: context,
        ),
        _buildInfoRow(
          icon: Icons.place_outlined,
          title: 'Endereço',
          content: c.endereco,
          context: context,
        ),
        
        const SizedBox(height: 12),
        
        if (c.nomeCliente != null)
          _buildInfoRow(
            icon: Icons.person_outline,
            title: 'Cliente',
            content: c.nomeCliente!,
            context: context,
          ),
        
        if (c.telefone != null)
          _buildInfoRow(
            icon: Icons.phone_outlined,
            title: 'Telefone',
            content: c.telefone!,
            context: context,
          ),
        
        const SizedBox(height: 12),
        
        _buildInfoRow(
          icon: Icons.calendar_today_outlined,
          title: 'Data da Visita',
          content: dataHoraFormatada,
          context: context,
        ),
        
        if (c.observacoes != null && c.observacoes!.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.note_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Observações',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            c.observacoes!,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String content,
    required BuildContext context,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}