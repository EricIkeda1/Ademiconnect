import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

// Renomeado para MeusClientesTab já que está no arquivo meus_clientes_tab.dart
class MeusClientesTab extends StatefulWidget {
  final Function onClienteRemovido;

  const MeusClientesTab({super.key, required this.onClienteRemovido});

  @override
  State<MeusClientesTab> createState() => _MeusClientesTabState();
}

class _MeusClientesTabState extends State<MeusClientesTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  final SupabaseClient _client = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text.trim()));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Stream<List<Map<String, dynamic>>> get _meusClientesStream {
    final user = _client.auth.currentSession?.user;
    if (user == null) {
      return const Stream<List<Map<String, dynamic>>>.empty();
    }

    return _client
        .from('clientes')
        .select('*')
        .eq('consultor_uid', user.id)
        .order('data_visita', ascending: true)
        .asStream();
  }

  Future<void> _abrirNoGPS(String endereco) async {
    final encodedEndereco = Uri.encodeComponent(endereco);

    final urls = {
      'Google Maps': 'https://www.google.com/maps/search/?api=1&query=$encodedEndereco',
      'Waze': 'https://waze.com/ul?q=$encodedEndereco&navigate=yes',
      'Apple Maps': 'https://maps.apple.com/?q=$encodedEndereco',
    };

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abrir no GPS'),
        content: const Text('Escolha o aplicativo de navegação:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ...urls.entries.map((entry) => TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _launchUrl(entry.value);
                },
                child: Text(entry.key),
              )).toList(),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível abrir o aplicativo'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  InputDecoration _obterDecoracaoCampo(
    String label, {
    String? hint,
    Widget? suffixIcon,
    bool isObrigatorio = false,
  }) {
    return InputDecoration(
      labelText: '$label${isObrigatorio ? ' *' : ''}',
      hintText: hint,
      filled: true,
      fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 2,
        ),
      ),
      suffixIcon: suffixIcon,
      labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
      hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6),
          ),
    );
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
                  'Meus Clientes',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Gerencie sua lista de clientes',
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
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
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Cadastre seus primeiros clientes',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _buildHeader(),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: TextField(
                controller: _searchCtrl,
                textInputAction: TextInputAction.search,
                decoration: _obterDecoracaoCampo(
                  'Buscar clientes',
                  hint: 'Digite para pesquisar...',
                  suffixIcon: _query.isEmpty
                      ? const Icon(Icons.search)
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: _searchCtrl.clear,
                          tooltip: 'Limpar',
                        ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _meusClientesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Erro: ${snapshot.error}'),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildEmptyState(),
                  );
                }

                final clientes = snapshot.data!;
                final clientesFiltrados = _query.isEmpty
                    ? clientes
                    : clientes.where((cliente) {
                        final estabelecimento = (cliente['estabelecimento']?.toString().toLowerCase() ?? '');
                        final endereco = (cliente['endereco']?.toString().toLowerCase() ?? '');
                        final bairro = (cliente['bairro']?.toString().toLowerCase() ?? '');
                        final cidade = (cliente['cidade']?.toString().toLowerCase() ?? '');
                        final query = _query.toLowerCase();
                        return estabelecimento.contains(query) ||
                            endereco.contains(query) ||
                            bairro.contains(query) ||
                            cidade.contains(query);
                      }).toList();

                if (clientesFiltrados.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(
                          Icons.search_off_outlined,
                          size: 48,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Nenhum cliente encontrado',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final cliente = clientesFiltrados[index];
                      return _buildClienteItem(cliente);
                    },
                    childCount: clientesFiltrados.length,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClienteItem(Map<String, dynamic> cliente) {
    final String estabelecimento = cliente['estabelecimento'] ?? 'Cliente';
    final String endereco = '${cliente['endereco'] ?? ''}, ${cliente['bairro'] ?? ''}';
    final String cidade = '${cliente['cidade'] ?? ''} - ${cliente['estado'] ?? ''}';
    final String? dataVisitaStr = cliente['data_visita'] as String?;
    final DateTime? dataVisita = dataVisitaStr != null ? DateTime.tryParse(dataVisitaStr) : null;

    final bool visitaPassada = dataVisita != null && dataVisita.isBefore(DateTime.now());
    final bool visitaHoje = dataVisita != null &&
        dataVisita.year == DateTime.now().year &&
        dataVisita.month == DateTime.now().month &&
        dataVisita.day == DateTime.now().day;

    String dataFormatada = 'Data não informada';
    if (dataVisita != null) {
      final formatter = DateFormat('dd/MM/yyyy');
      dataFormatada = 'Próxima visita: ${formatter.format(dataVisita)}';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () {
          // Adicione ação de clique se necessário
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: visitaPassada
                      ? Colors.grey.shade200
                      : visitaHoje
                          ? Colors.red.shade50
                          : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  visitaPassada ? Icons.check_circle : visitaHoje ? Icons.flag : Icons.schedule,
                  color: visitaPassada ? Colors.grey : visitaHoje ? Colors.red : Colors.blue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      estabelecimento,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      endereco,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      cidade,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      dataFormatada,
                      style: TextStyle(
                        fontSize: 12,
                        color: dataVisita == null
                            ? Colors.grey
                            : visitaPassada
                                ? Colors.grey
                                : visitaHoje
                                    ? Colors.red
                                    : Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () async {
                  final confirmar = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Confirmar exclusão'),
                      content: Text('Tem certeza que deseja excluir $estabelecimento?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancelar'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Excluir', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );

                  if (confirmar == true) {
                    try {
                      await _client.from('clientes').delete().eq('id', cliente['id']);

                      widget.onClienteRemovido();

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Cliente excluído com sucesso'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Erro ao excluir cliente: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
