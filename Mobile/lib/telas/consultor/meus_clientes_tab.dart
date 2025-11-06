import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

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

  bool _showSearch = false;

  Timer? _debounceSearch;

  final Map<String, String> _abbr = const {
    'Avenida': 'Av.',
    'Rua': 'R.',
    'Alameda': 'Al.',
    'Travessa': 'Tv.',
    'Rodovia': 'Rod.',
    'Estrada': 'Est.',
    'Praça': 'Pç.',
    'Largo': 'Lg.',
    'Via': 'Via',
  };
  final List<String> _tiposLogradouro = const [
    'Rua','Avenida','Alameda','Travessa','Rodovia','Estrada','Praça','Via','Largo'
  ];

  final List<Map<String, String>> _statusOptions = const [
    {'label': 'Conexão', 'value': 'conexao'},
    {'label': 'Negociação', 'value': 'negociacao'},
    {'label': 'Fechada', 'value': 'fechada'},
  ];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      _debounceSearch?.cancel();
      _debounceSearch = Timer(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        setState(() {
          _query = _searchCtrl.text.trim();
        });
      });
    });
  }

  @override
  void dispose() {
    _debounceSearch?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Stream<List<Map<String, dynamic>>> get _meusClientesStream {
    final user = _client.auth.currentSession?.user;
    if (user == null) return const Stream<List<Map<String, dynamic>>>.empty();
    return _client
        .from('clientes')
        .select('*')
        .eq('consultor_uid_t', user.id)
        .order('data_visita', ascending: true, nullsFirst: false)
        .asStream();
  }

  InputDecoration _decoracaoCampo(BuildContext context, String label, {String? hint, Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      suffixIcon: suffixIcon,
      isDense: true,
    );
  }

  String _statusLabel(String? v) {
    switch ((v ?? '').toLowerCase()) {
      case 'conexao': return 'Conexão';
      case 'negociacao': return 'Negociação';
      case 'fechada': return 'Fechada';
      default: return '—';
    }
  }

  Color _statusColor(String? v) {
    switch ((v ?? '').toLowerCase()) {
      case 'conexao': return Colors.blue;
      case 'negociacao': return Colors.orange;
      case 'fechada': return Colors.red; 
      default: return Colors.grey;
    }
  }

  int _pesoStatus(String? s) {
    switch ((s ?? '').toLowerCase()) {
      case 'conexao': return 0;
      case 'negociacao': return 1;
      case 'fechada': return 2;
      default: return 3;
    }
  }

  DateTime? _parseVisita(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v.toLocal();
    if (v is String) return DateTime.tryParse(v)?.toLocal();
    if (v is Map && v['value'] is String) return DateTime.tryParse(v['value'])?.toLocal();
    return null;
  }

  int _compareCliente(Map<String, dynamic> a, Map<String, dynamic> b) {
    final pa = _pesoStatus(a['status_negociacao']?.toString());
    final pb = _pesoStatus(b['status_negociacao']?.toString());
    if (pa != pb) return pa.compareTo(pb);

    final DateTime? da = _parseVisita(a['data_visita']);
    final DateTime? db = _parseVisita(b['data_visita']);
    int cat(DateTime? d) {
      if (d == null) return 3;
      final now = DateTime.now();
      final h = DateTime(now.year, now.month, now.day);
      final dh = DateTime(d.year, d.month, d.day);
      if (dh == h) return 0;
      if (dh.isAfter(h)) return 1;
      return 2;
    }
    final ca = cat(da), cb = cat(db);
    if (ca != cb) return ca.compareTo(cb);
    if (da != null && db != null) {
      final cmp = da.compareTo(db);
      if (cmp != 0) return cmp;
    } else if (da == null && db != null) {
      return 1;
    } else if (da != null && db == null) {
      return -1;
    }

    final sa = (a['estabelecimento'] ?? a['nome'] ?? '').toString().toLowerCase();
    final sb = (b['estabelecimento'] ?? b['nome'] ?? '').toString().toLowerCase();
    return sa.compareTo(sb);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          FocusScope.of(context).unfocus();
          if (_showSearch) setState(() => _showSearch = false);
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: TextField(
                  controller: _searchCtrl,
                  textInputAction: TextInputAction.search,
                  decoration: _decoracaoCampo(
                    context,
                    'Buscar clientes',
                    hint: 'Digite nome, endereço, bairro, cidade ou status...',
                    suffixIcon: _query.isEmpty
                        ? const Icon(Icons.search)
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              _debounceSearch?.cancel();
                              setState(() {
                                _query = '';
                                _showSearch = false;
                              });
                              FocusScope.of(context).unfocus();
                            },
                            tooltip: 'Limpar',
                          ),
                  ),
                  onTap: () => setState(() => _showSearch = true), 
                  onSubmitted: (_) {
                    setState(() => _showSearch = false); 
                    FocusScope.of(context).unfocus();
                  },
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
                final q = _query.toLowerCase();

                List<Map<String, dynamic>> clientesFiltrados;
                if (_query.isEmpty) {
                  clientesFiltrados = [...clientes];
                } else {
                  String s(Object? x) => (x ?? '').toString().toLowerCase();
                  clientesFiltrados = clientes.where((c) {
                    final estabelecimento = s(c['estabelecimento'].toString().isNotEmpty ? c['estabelecimento'] : c['nome']);
                    final logradouro = s(c['logradouro']);
                    final endereco = s(c['endereco']);
                    final numero = s(c['numero']);
                    final bairro = s(c['bairro']);
                    final cidade = s(c['cidade']);
                    final status = s(c['status_negociacao']);
                    final valor = s(c['valor_proposta']);
                    return estabelecimento.contains(q) ||
                           (logradouro + ' ' + endereco).contains(q) ||
                           numero.contains(q) ||
                           bairro.contains(q) ||
                           cidade.contains(q) ||
                           status.contains(q) ||
                           valor.contains(q);
                  }).toList();
                }

                clientesFiltrados.sort(_compareCliente);

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

  Widget _buildClienteItem(Map<String, dynamic> c) {
    final String titulo = (c['estabelecimento'] ?? c['nome'] ?? 'Cliente').toString().trim();

    final String tipoAbrev = (c['logradouro'] ?? '').toString().trim();
    final String nomeVia = (c['endereco'] ?? '').toString().trim();
    final String numero = (c['numero'] ?? '').toString().trim();
    final String complemento = (c['complemento'] ?? '').toString().trim();
    final String bairro = (c['bairro'] ?? '').toString().trim();

    final String linhaEndereco = [
      if (tipoAbrev.isNotEmpty) tipoAbrev,
      if (nomeVia.isNotEmpty) nomeVia,
      if (numero.isNotEmpty) numero,
      if (complemento.isNotEmpty) '($complemento)',
      if (bairro.isNotEmpty) '- $bairro',
    ].join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();

    final String cidade = (c['cidade'] ?? '').toString().trim();
    final String estado = (c['estado'] ?? '').toString().trim().toUpperCase();
    final String linhaCidade = [cidade, estado].where((e) => e.isNotEmpty).join(' - ');

    final DateTime? dataVisita = _parseVisita(c['data_visita']);
    final now = DateTime.now();
    final bool visitaHoje = dataVisita != null &&
        dataVisita.year == now.year && dataVisita.month == now.month && dataVisita.day == now.day;
    final bool visitaPassada = dataVisita != null && dataVisita.isBefore(DateTime(now.year, now.month, now.day));

    String dataFormatada = 'Data não informada';
    if (dataVisita != null) {
      dataFormatada = 'Próxima visita: ${DateFormat('dd/MM/yyyy HH:mm').format(dataVisita)}';
    }

    final String statusTec = (c['status_negociacao'] ?? '').toString();
    final String statusLabel = _statusLabel(statusTec);
    final Color statusColor = _statusColor(statusTec);
    final num? valorProposta = c['valor_proposta'] is num
        ? c['valor_proposta'] as num
        : num.tryParse((c['valor_proposta'] ?? '').toString());
    final String valorFmt = valorProposta != null
        ? NumberFormat.simpleCurrency(locale: 'pt_BR').format(valorProposta)
        : '—';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => _editarCliente(c),
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
                    Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                    const SizedBox(height: 4),
                    if (linhaEndereco.isNotEmpty)
                      Text(linhaEndereco, style: Theme.of(context).textTheme.bodySmall),
                    if (linhaCidade.isNotEmpty)
                      Text(linhaCidade, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Chip(
                          label: Text(statusLabel),
                          backgroundColor: statusColor.withOpacity(0.1),
                          labelStyle: TextStyle(color: statusColor, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Proposta: $valorFmt',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
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
                      content: Text('Tem certeza que deseja excluir $titulo?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir', style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  );
                  if (confirmar == true) {
                    try {
                      await _client.from('clientes').delete().eq('id', c['id']);
                      widget.onClienteRemovido();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Cliente excluído com sucesso'), backgroundColor: Colors.green),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erro ao excluir cliente: $e'), backgroundColor: Colors.red),
                        );
                      }
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

  Future<void> _editarCliente(Map<String, dynamic> c) async {
    final formKey = GlobalKey<FormState>();

    final statusTec = (c['status_negociacao'] ?? '').toString();
    final valorProposta = (c['valor_proposta'] as num?)?.toString() ?? '';
    final bairro = (c['bairro'] ?? '').toString();
    final cidade = (c['cidade'] ?? '').toString();
    final estado = (c['estado'] ?? '').toString();
    final numero = (c['numero'] ?? '').toString();
    final complemento = (c['complemento'] ?? '').toString();
    final observacoes = (c['observacoes'] ?? '').toString();
    final tipoInicial = _abbr.entries
        .firstWhere(
          (e) => (c['logradouro'] ?? '').toString().trim().toLowerCase() == e.value.toLowerCase(),
          orElse: () => const MapEntry('', ''),
        )
        .key;
    final nomeViaInicial = (c['endereco'] ?? '').toString().trim();

    String? _tipoLogradouroEd = tipoInicial.isEmpty ? null : tipoInicial;
    final nomeViaCtrl = TextEditingController(text: nomeViaInicial);
    final numeroCtrl = TextEditingController(text: numero);
    final bairroCtrl = TextEditingController(text: bairro);
    final cidadeCtrl = TextEditingController(text: cidade);
    final estadoCtrl = TextEditingController(text: estado);
    final complementoCtrl = TextEditingController(text: complemento);
    final valorCtrl = TextEditingController(text: valorProposta);
    final observacoesCtrl = TextEditingController(text: observacoes);
    String? _statusTecEd = statusTec.isEmpty ? null : statusTec;

    String montarLogradouroAbrev(String? tipoCheio) => _abbr[tipoCheio ?? ''] ?? (tipoCheio ?? '');

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
            child: Form(
              key: formKey,
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
                          child: Icon(Icons.edit_location_alt_outlined, color: Theme.of(context).colorScheme.onPrimaryContainer),
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

                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: _statusTecEd,
                            items: _statusOptions
                                .map((s) => DropdownMenuItem<String>(value: s['value']!, child: Text(s['label']!)))
                                .toList(),
                            onChanged: (v) => _statusTecEd = v,
                            decoration: _decoracaoCampo(context, 'Status'),
                            validator: (v) => v == null || v.isEmpty ? 'Status é obrigatório' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: valorCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: _decoracaoCampo(context, 'Valor da proposta', hint: 'Ex: 1500,00'),
                            validator: (v) {
                              final raw = (v ?? '').trim();
                              if (raw.isEmpty) return null;
                              final norm = raw.replaceAll('.', '').replaceAll(',', '.');
                              final parsed = num.tryParse(norm);
                              if (parsed == null) return 'Valor inválido';
                              if (parsed < 0) return 'Valor não pode ser negativo';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: _tiposLogradouro.contains(_tipoLogradouroEd) ? _tipoLogradouroEd : null,
                            items: _tiposLogradouro.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                            selectedItemBuilder: (context) {
                              return _tiposLogradouro.map((e) {
                                final abreviado = _abbr[e] ?? e;
                                return Align(alignment: Alignment.centerLeft, child: Text(abreviado, overflow: TextOverflow.ellipsis));
                              }).toList();
                            },
                            onChanged: (v) => setState(() => _tipoLogradouroEd = v),
                            decoration: _decoracaoCampo(context, 'Tipo'),
                            validator: (v) => v == null || v.isEmpty ? 'Tipo é obrigatório' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 4,
                          child: TextFormField(
                            controller: nomeViaCtrl,
                            decoration: _decoracaoCampo(context, 'Nome da via', hint: 'Ex: Tiradentes'),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Nome da via é obrigatório' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: numeroCtrl,
                            decoration: _decoracaoCampo(context, 'Número', hint: '123'),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Número é obrigatório' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: bairroCtrl,
                            decoration: _decoracaoCampo(context, 'Bairro', hint: 'Jardim ...'),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Bairro é obrigatório' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: cidadeCtrl,
                            decoration: _decoracaoCampo(context, 'Cidade', hint: 'Londrina'),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Cidade é obrigatório' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 90,
                          child: TextFormField(
                            controller: estadoCtrl,
                            textCapitalization: TextCapitalization.characters,
                            decoration: _decoracaoCampo(context, 'UF', hint: 'PR'),
                            validator: (v) {
                              final x = v?.trim().toUpperCase() ?? '';
                              if (x.isEmpty) return 'UF é obrigatório';
                              if (x.length != 2) return 'UF deve ter 2 letras';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: complementoCtrl,
                      decoration: _decoracaoCampo(context, 'Complemento', hint: 'Ap, bloco, casa, sala'),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: observacoesCtrl,
                      maxLines: 3,
                      decoration: _decoracaoCampo(context, 'Observações', hint: 'Notas sobre a negociação'),
                    ),

                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () async {
                          if (!(formKey.currentState?.validate() ?? false)) return;

                          num? valor;
                          final raw = valorCtrl.text.trim();
                          if (raw.isNotEmpty) {
                            final norm = raw.replaceAll('.', '').replaceAll(',', '.');
                            valor = num.tryParse(norm);
                          }

                          final nomeViaPuro = nomeViaCtrl.text.trim();
                          if (_tipoLogradouroEd == null || _tipoLogradouroEd!.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Selecione o Tipo (logradouro).'), backgroundColor: Colors.red),
                            );
                            return;
                          }
                          if (nomeViaPuro.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Informe o Nome da via.'), backgroundColor: Colors.red),
                            );
                            return;
                          }

                          final logradouroAbrev = montarLogradouroAbrev(_tipoLogradouroEd);

                          try {
                            await _client.from('clientes').update({
                              'status_negociacao': _statusTecEd,
                              'valor_proposta': valor,
                              'logradouro': logradouroAbrev,
                              'endereco'  : nomeViaPuro,
                              'numero': numeroCtrl.text.trim(),
                              'bairro': bairroCtrl.text.trim(),
                              'cidade': cidadeCtrl.text.trim(),
                              'estado': estadoCtrl.text.trim().toUpperCase(),
                              'complemento': complementoCtrl.text.trim().isNotEmpty ? complementoCtrl.text.trim() : null,
                              'observacoes': observacoesCtrl.text.trim().isNotEmpty ? observacoesCtrl.text.trim() : null,
                            }).eq('id', c['id']);

                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Cliente atualizado com sucesso'), backgroundColor: Colors.green),
                              );
                              setState(() {});
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Salvar alterações'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
