import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

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
        .eq('consultor_uid_t', user.id)
        .order('data_visita', ascending: true)
        .asStream();
  }

  Future<void> _abrirNoGoogleMaps(String endereco) async {
    final encodedEndereco = Uri.encodeComponent(endereco);
    final url = 'https://www.google.com/maps/search/?api=1&query=$encodedEndereco';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o Google Maps'), backgroundColor: Colors.red),
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
        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
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
            child: Icon(Icons.people_outline_rounded, color: Theme.of(context).colorScheme.onPrimaryContainer, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Meus Clientes',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      )),
              const SizedBox(height: 4),
              Text('Gerencie sua lista de clientes',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ]),
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
          Icon(Icons.people_outline_rounded, size: 64, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text('Nenhum cliente cadastrado', style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 8),
          Text('Cadastre seus primeiros clientes',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
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
                      : IconButton(icon: const Icon(Icons.clear), onPressed: _searchCtrl.clear, tooltip: 'Limpar'),
                ),
              ),
            ),
          ),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _meusClientesStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
              }
              if (snapshot.hasError) {
                return SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(16), child: Text('Erro: ${snapshot.error}')));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(16), child: _buildEmptyState()));
              }

              final clientes = snapshot.data!;
              final clientesFiltrados = _query.isEmpty
                  ? clientes
                  : clientes.where((cliente) {
                      final estabelecimento = (cliente['estabelecimento']?.toString().toLowerCase() ?? '');
                      final endereco = (cliente['endereco']?.toString().toLowerCase() ?? '');
                      final bairro = (cliente['bairro']?.toString().toLowerCase() ?? '');
                      final cidade = (cliente['cidade']?.toString().toLowerCase() ?? '');
                      final q = _query.toLowerCase();
                      return estabelecimento.contains(q) || endereco.contains(q) || bairro.contains(q) || cidade.contains(q);
                    }).toList();

              if (clientesFiltrados.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(Icons.search_off_outlined, size: 48, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                        const SizedBox(height: 16),
                        Text('Nenhum cliente encontrado', style: Theme.of(context).textTheme.bodyLarge),
                      ],
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildClienteItem(clientesFiltrados[index]),
                  childCount: clientesFiltrados.length,
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
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
        onTap: () => _mostrarDetalhesCliente(cliente), 
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
                    Text(estabelecimento, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(endereco, style: Theme.of(context).textTheme.bodySmall),
                    Text(cidade, style: Theme.of(context).textTheme.bodySmall),
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
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir', style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  );

                  if (confirmar == true) {
                    try {
                      await _client.from('clientes').delete().eq('id', cliente['id']);
                      widget.onClienteRemovido();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Cliente excluído com sucesso'), backgroundColor: Colors.green),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Erro ao excluir cliente: $e'), backgroundColor: Colors.red),
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

  Future<void> _mostrarDetalhesCliente(Map<String, dynamic> c) async {
    final enderecoCompleto = [
      c['endereco'] ?? '',
      c['bairro'] ?? '',
      c['cidade'] ?? '',
      c['estado'] ?? ''
    ].where((s) => (s as String).toString().trim().isNotEmpty).join(', ');

    final String? dataVisitaStr = c['data_visita'] as String?;
    final DateTime? dataVisita = dataVisitaStr != null ? DateTime.tryParse(dataVisitaStr) : null;
    final String dataFormatada = dataVisita != null ? DateFormat('dd/MM/yyyy').format(dataVisita) : 'Não informada';

    final String? horaVisitaStr = c['hora_visita']?.toString();
    final String horaFormatada = (horaVisitaStr != null && horaVisitaStr.isNotEmpty) ? horaVisitaStr.substring(0, 5) : 'Não informada';

    final String responsavel = (c['responsavel'] ?? 'Não informado').toString();
    final String telefone = (c['telefone'] ?? 'Não informado').toString();
    final String cep = (c['cep'] ?? 'Não informado').toString();
    final String observacoes = (c['observacoes'] ?? '').toString().trim();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              top: 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, 
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.business_rounded, color: Theme.of(context).colorScheme.onPrimaryContainer),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          c['estabelecimento'] ?? c['nome'] ?? 'Cliente',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context), tooltip: 'Fechar')
                    ],
                  ),
                  const SizedBox(height: 16),
                  _linhaInfo(Icons.person_outline, 'Responsável', responsavel),
                  const SizedBox(height: 8),
                  _linhaInfo(Icons.phone_outlined, 'Telefone', telefone),
                  const SizedBox(height: 8),
                  _linhaInfo(Icons.location_on_outlined, 'Endereço', enderecoCompleto.isEmpty ? 'Não informado' : enderecoCompleto),
                  const SizedBox(height: 8),
                  _linhaInfo(Icons.markunread_mailbox_outlined, 'CEP', cep),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _linhaInfo(Icons.event_outlined, 'Data da visita', dataFormatada)),
                      const SizedBox(width: 12),
                      Expanded(child: _linhaInfo(Icons.schedule_outlined, 'Hora da visita', horaFormatada)),
                    ],
                  ),
                  if (observacoes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Observações',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            )),
                    const SizedBox(height: 4),
                    Text(observacoes, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: enderecoCompleto.isEmpty ? null : () => _abrirNoGoogleMaps(enderecoCompleto),
                          icon: const Icon(Icons.map_outlined),
                          label: const Text('Abrir no Maps'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('OK'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _linhaInfo(IconData icone, String titulo, String valor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icone, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titulo, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 2),
            Text(valor, style: Theme.of(context).textTheme.bodyMedium),
          ]),
        ),
      ],
    );
  }
}
