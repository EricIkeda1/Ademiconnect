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
          SnackBar(content: Text('Erro ao carregar clientes: $e')),
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
        const SnackBar(content: Text('Ordem dos clientes atualizada!')),
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
            SnackBar(
              content: const Text('Cliente excluído com sucesso!'),
              backgroundColor: Colors.green.shade700,
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
          '${c.estabelecimento} ${c.estado} ${c.cidade} ${c.endereco} ${c.nomeCliente ?? ''}'
              .toLowerCase();
      return textoBusca.contains(_termoBusca.toLowerCase());
    }).toList();

    return RefreshIndicator(
      onRefresh: _atualizarListaClientes,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.people_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Meus Clientes',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              TextField(
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  hintText: 'Buscar por estabelecimento, estado, cidade, endereço ou cliente...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onChanged: (v) => setState(() => _termoBusca = v),
              ),
              const SizedBox(height: 16),

              if (_isLoading)
                const Expanded(
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
                )
              
              else if (clientesFiltrados.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline_rounded,
                          size: 64,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _termoBusca.isEmpty 
                              ? 'Nenhum cliente cadastrado por você ainda.'
                              : 'Nenhum cliente encontrado para a busca.',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                              ),
                          textAlign: TextAlign.center,
                        ),
                        if (_termoBusca.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Adicione seu primeiro cliente para começar.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                  ),
                )
              
              else
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          '${clientesFiltrados.length} cliente${clientesFiltrados.length == 1 ? '' : 's'} encontrado${clientesFiltrados.length == 1 ? '' : 's'}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                      
                      Expanded(
                        child: ReorderableListView.builder(
                          itemCount: clientesFiltrados.length,
                          onReorder: _reordenarClientes,
                          itemBuilder: (context, index) {
                            final c = clientesFiltrados[index];
                            final dataHoraFormatada =
                                DateFormat('dd/MM/yyyy HH:mm').format(c.dataVisita);
                            final isExpanded = _expandedStates[c.id] ?? false;

                            return Card(
                              key: Key(c.id),
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                              child: ExpansionTile(
                                key: Key('${c.id}_tile'),
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primaryContainer,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.drag_handle,
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                    size: 20,
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
                                onExpansionChanged: (expanded) => _toggleExpansion(c.id),
                                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                                childrenPadding: EdgeInsets.zero,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
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
              size: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                '${c.cidade} - ${c.estado}',
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          c.endereco,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
        
        const SizedBox(height: 8),
        
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
        
        const SizedBox(height: 8),
        
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
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.note_outlined,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Observações',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          c.observacoes!,
                          style: Theme.of(context).textTheme.bodyMedium,
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 2),
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