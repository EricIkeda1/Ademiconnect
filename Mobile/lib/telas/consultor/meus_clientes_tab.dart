import '../../models/cliente.dart';
import '../../services/cliente_service.dart';
import 'package:flutter/material.dart';

class MeusClientesTab extends StatefulWidget {
  final VoidCallback? onClienteRemovido;

  const MeusClientesTab({super.key, this.onClienteRemovido});

  @override
  State<MeusClientesTab> createState() => _MeusClientesTabState();
}

class _MeusClientesTabState extends State<MeusClientesTab> {
  final ClienteService _clienteService = ClienteService();
  final List<Cliente> _clientes = [];
  String _q = '';

  @override
  void initState() {
    super.initState();
    _loadClientes();
  }

  Future<void> _loadClientes() async {
    await _clienteService.loadClientes();
    setState(() {
      _clientes.clear();
      _clientes.addAll(_clienteService.clientes);
    });
  }

  Future<void> _refreshClientes() async {
    await _loadClientes();
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    
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

  @override
  Widget build(BuildContext context) {
    final filtrados = _clientes.where((c) {
      final hay = '${c.estabelecimento} ${c.endereco} ${c.nomeCliente ?? ''}'.toLowerCase();
      return hay.contains(_q.toLowerCase());
    }).toList();

    return RefreshIndicator(
      onRefresh: _refreshClientes,
      child: Card.outlined(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, 
            children: [
              const Text('Meus Clientes', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Buscar por nome de estabelecimento, endereço ou cliente...',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _q = v),
              ),
              const SizedBox(height: 12),
              
              if (filtrados.isEmpty)
                const Expanded(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('Nenhum cliente cadastrado ainda.'),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ReorderableListView.builder(
                    itemCount: filtrados.length,
                    onReorder: _onReorder,
                    itemBuilder: (context, index) {
                      final c = filtrados[index];
                      final data = '${c.dataVisita.day.toString().padLeft(2, '0')}/${c.dataVisita.month.toString().padLeft(2, '0')}/${c.dataVisita.year}';
                      
                      return Column(
                        key: Key(c.id),
                        children: [
                          ListTile(
                            leading: const Icon(Icons.drag_handle, color: Colors.grey),
                            title: Text(c.estabelecimento),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.endereco),
                                if (c.nomeCliente != null) Text('Cliente: ${c.nomeCliente}'),
                                if (c.telefone != null) Text('Telefone: ${c.telefone}'),
                                if (c.observacoes != null) Text('Obs: ${c.observacoes}'),
                                Text('Data: $data'),
                              ],
                            ),
                            isThreeLine: true,
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _confirmarExclusao(c),
                            ),
                          ),
                          const Divider(height: 0),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmarExclusao(Cliente cliente) async {
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
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _clienteService.removeCliente(cliente.id);
        await _refreshClientes();
        widget.onClienteRemovido?.call(); 

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cliente excluído com sucesso!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao excluir cliente: $e')),
          );
        }
      }
    }
  }
}
