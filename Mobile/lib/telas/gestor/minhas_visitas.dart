import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class MinhasVisitasPage extends StatefulWidget {
  const MinhasVisitasPage({super.key});

  @override
  State<MinhasVisitasPage> createState() => _MinhasVisitasPageState();
}

class _MinhasVisitasPageState extends State<MinhasVisitasPage> with TickerProviderStateMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  final SupabaseClient _client = Supabase.instance.client;
  final _debouncer = _Debouncer(const Duration(milliseconds: 250));

  final Map<String, bool> _pastaExpandedPorConsultor = {};
  final Map<String, bool> _proxExpandedPorConsultor = {};
  final Map<String, bool> _finExpandedPorConsultor = {};

  List<Consultor> _consultores = [];
  bool _isLoading = true;
  String? _error;

  final Map<String, List<ClienteVisita>> _clientesPorConsultor = {};
  final Map<String, bool> _loadingClientes = {};

  @override
  void initState() {
    super.initState();
    _carregarConsultores();
    _searchCtrl.addListener(() {
      _debouncer.run(() {
        if (!mounted) return;
        setState(() => _query = _searchCtrl.text.trim());
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  Future<void> _carregarConsultores() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await _client
          .from('consultores')
          .select('id, uid, nome, ativo')
          .eq('ativo', true)
          .order('nome');

      final list = <Consultor>[];
      if (res is List) {
        for (final c in res) {
          final id = c['id']?.toString();
          final uid = c['uid']?.toString();
          final nome = c['nome']?.toString();
          if (id != null && uid != null && nome != null) {
            list.add(Consultor(id: id, uid: uid, nome: nome));
            _pastaExpandedPorConsultor[id] = false;
            _proxExpandedPorConsultor[id] = false;
            _finExpandedPorConsultor[id] = false;
          }
        }
      }
      setState(() {
        _consultores = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Falha ao carregar consultores: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _carregarClientesDoConsultor(Consultor consultor) async {
    final cacheKey = consultor.id;
    if (_loadingClientes[cacheKey] == true) return;
    _loadingClientes[cacheKey] = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });

    try {
      final clientes = await _client
          .from('clientes')
          .select('''
            *,
            consultores:nome
          ''')
          .eq('consultor_uid_t', consultor.uid)
          .order('data_visita', ascending: false)
          .order('hora_visita', ascending: false);

      final listaClientes = <ClienteVisita>[];
      if (clientes is List) {
        for (final c in clientes) {
          final estabelecimento = c['estabelecimento']?.toString().trim() ?? 'Estabelecimento não informado';
          final endereco = c['endereco']?.toString().trim() ?? '';
          final bairro = c['bairro']?.toString().trim() ?? '';
          final cidade = c['cidade']?.toString().trim() ?? '';
          final estado = c['estado']?.toString().trim() ?? '';
          final dataVisita = c['data_visita']?.toString();
          final horaVisita = c['hora_visita']?.toString();

          listaClientes.add(ClienteVisita(
            estabelecimento: estabelecimento,
            endereco: endereco,
            bairro: bairro,
            cidade: cidade,
            estado: estado,
            dataVisita: dataVisita,
            horaVisita: horaVisita,
          ));
        }
      }
      _clientesPorConsultor[cacheKey] = listaClientes;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar clientes de ${consultor.nome}: $e')),
        );
      }
      _clientesPorConsultor[cacheKey] = const <ClienteVisita>[];
    } finally {
      _loadingClientes[cacheKey] = false;
      if (mounted) setState(() {});
    }
  }

  List<Consultor> _filtrarConsultores() {
    if (_query.isEmpty) return _consultores;

    return _consultores.where((consultor) {
      if (consultor.nome.toLowerCase().contains(_query.toLowerCase())) {
        return true;
      }

      final clientes = _clientesPorConsultor[consultor.id];
      if (clientes != null) {
        return clientes.any((cliente) =>
            cliente.estabelecimento.toLowerCase().contains(_query.toLowerCase()));
      }

      return false;
    }).toList();
  }

  (List<ClienteVisita> proximas, List<ClienteVisita> finalizados) _separarClientesPorData(List<ClienteVisita> clientes) {
    final agora = DateTime.now();
    final hojeIni = DateTime(agora.year, agora.month, agora.day, 0, 0, 0);

    bool isPassado(ClienteVisita cliente) {
      final ds = cliente.dataVisita;
      if (ds == null || ds.isEmpty) return false;
      try {
        DateTime d = DateTime.parse(ds).toLocal();
        final hs = cliente.horaVisita;
        if (hs != null && hs.isNotEmpty) {
          final p = hs.split(':');
          final h = int.tryParse(p[0]) ?? 0;
          final m = p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0;
          final s = p.length > 2 ? int.tryParse(p[2]) ?? 0 : 0;
          d = DateTime(d.year, d.month, d.day, h, m, s);
        } else {
          d = DateTime(d.year, d.month, d.day, 0, 0, 0);
        }
        return d.isBefore(hojeIni);
      } catch (_) {
        return false;
      }
    }

    bool matchesCliente(ClienteVisita cliente) {
      if (_query.isEmpty) return true;
      return cliente.estabelecimento.toLowerCase().contains(_query.toLowerCase());
    }

    final clientesFiltrados = clientes.where(matchesCliente).toList();
    final List<ClienteVisita> proximas = clientesFiltrados.where((c) => !isPassado(c)).toList();
    final List<ClienteVisita> finalizados = clientesFiltrados.where(isPassado).toList();

    return (proximas, finalizados);
  }

  Future<void> _abrirNoGoogleMaps(String endereco) async {
    final encoded = Uri.encodeComponent(endereco);
    final url = 'https://www.google.com/maps/search/?api=1&query=$encoded';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
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
      labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6)),
    );
  }

Widget _buildHeader() {
  final cs = Theme.of(context).colorScheme;
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 20), 
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.calendar_today_rounded,
            color: cs.onPrimaryContainer,
            size: 28, 
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Visitas da Equipe',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Gerencie o cronograma de visitas por consultor',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  Widget _buildSectionTitle(String title, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildSectionTitle(title), child]),
      ),
    );
  }

  Widget _buildVisitaItem(ClienteVisita cliente) {
    final cs = Theme.of(context).colorScheme;

    final enderecoCompleto = [
      if (cliente.endereco.isNotEmpty) cliente.endereco,
      if (cliente.bairro.isNotEmpty || cliente.cidade.isNotEmpty || cliente.estado.isNotEmpty) 
        '${cliente.bairro} ${cliente.cidade} ${cliente.estado}'.trim(),
    ].where((e) => e.isNotEmpty).join(', ');

    final dataFormatada = _formatarDataVisita(cliente.dataVisita, cliente.horaVisita);
    final statusInfo = _determinarStatus(cliente.dataVisita, horaVisitaStr: cliente.horaVisita);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: cs.primaryContainer.withOpacity(0.3), borderRadius: BorderRadius.circular(10)),
            child: Icon(statusInfo['icone'], size: 20, color: cs.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: statusInfo['corFundo'], borderRadius: BorderRadius.circular(6)),
                child: Text(
                  statusInfo['texto'] as String,
                  style: TextStyle(color: statusInfo['corTexto'], fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                cliente.estabelecimento,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500, color: cs.onSurface),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              if (enderecoCompleto.isNotEmpty)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        enderecoCompleto,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              decoration: TextDecoration.none,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Abrir no Maps',
                      icon: const Icon(Icons.map_outlined, size: 20),
                      onPressed: enderecoCompleto.isEmpty ? null : () => _abrirNoGoogleMaps(enderecoCompleto),
                    ),
                  ],
                ),
              const SizedBox(height: 4),
              Text(
                dataFormatada,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant.withOpacity(0.7)),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _determinarStatus(String? dataVisitaStr, {String? horaVisitaStr}) {
    final cs = Theme.of(context).colorScheme;

    if (dataVisitaStr == null || dataVisitaStr.isEmpty) {
      return {
        'icone': Icons.event_note_outlined,
        'texto': 'AGENDADO',
        'corFundo': const Color(0x3328A745),
        'corTexto': Colors.green,
      };
    }

    try {
      DateTime data = DateTime.parse(dataVisitaStr).toLocal();
      if (horaVisitaStr != null && horaVisitaStr.isNotEmpty) {
        final p = horaVisitaStr.split(':');
        final h = int.tryParse(p[0]) ?? 0;
        final m = p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0;
        final s = p.length > 2 ? int.tryParse(p[2]) ?? 0 : 0;
        data = DateTime(data.year, data.month, data.day, h, m, s);
      } else {
        data = DateTime(data.year, data.month, data.day, 23, 59, 59);
      }

      final agora = DateTime.now();
      final hojeInicio = DateTime(agora.year, agora.month, agora.day, 0, 0, 0);
      final hojeFim = DateTime(agora.year, agora.month, agora.day, 23, 59, 59);

      final ehHoje = (data.isAfter(hojeInicio) && data.isBefore(hojeFim)) || data.isAtSameMomentAs(hojeInicio) || data.isAtSameMomentAs(hojeFim);

      if (ehHoje) {
        return {'icone': Icons.flag_outlined, 'texto': 'HOJE', 'corFundo': Colors.black, 'corTexto': Colors.white};
      } else if (data.isBefore(hojeInicio)) {
        return {
          'icone': Icons.check_circle_outlined,
          'texto': 'REALIZADA',
          'corFundo': cs.primaryContainer,
          'corTexto': cs.onPrimaryContainer,
        };
      } else {
        return {'icone': Icons.event_note_outlined, 'texto': 'AGENDADO', 'corFundo': const Color(0x3328A745), 'corTexto': Colors.green};
      }
    } catch (_) {
      return {'icone': Icons.event_note_outlined, 'texto': 'AGENDADO', 'corFundo': const Color(0x3328A745), 'corTexto': Colors.green};
    }
  }

  String _formatarDataVisita(String? dataVisitaStr, String? horaVisitaStr) {
    if (dataVisitaStr == null || dataVisitaStr.isEmpty) return 'Data não informada';
    try {
      DateTime data = DateTime.parse(dataVisitaStr).toLocal();
      if (horaVisitaStr != null && horaVisitaStr.isNotEmpty) {
        final p = horaVisitaStr.split(':');
        final h = int.tryParse(p[0]) ?? 0;
        final m = p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0;
        final s = p.length > 2 ? int.tryParse(p[2]) ?? 0 : 0;
        data = DateTime(data.year, data.month, data.day, h, m, s);
      }

      final hoje = DateTime.now();
      final amanha = DateTime(hoje.year, hoje.month, hoje.day + 1);
      final horaExibida = DateFormat('HH:mm').format(data);

      if (data.year == hoje.year && data.month == hoje.month && data.day == hoje.day) {
        return 'Hoje às $horaExibida';
      } else if (data.year == amanha.year && data.month == amanha.month && data.day == amanha.day) {
        return 'Amanhã às $horaExibida';
      } else {
        final format = data.year == hoje.year ? 'EEE, d MMMM' : 'EEE, d MMMM y';
        return '${_capitalize(DateFormat(format, 'pt_BR').format(data))} às $horaExibida';
      }
    } catch (_) {
      return 'Data inválida';
    }
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  Widget _buildConsultorCard(Consultor consultor) {
    final isLoading = _loadingClientes[consultor.id] == true;
    final clientes = _clientesPorConsultor[consultor.id];

    List<ClienteVisita> proximas = [];
    List<ClienteVisita> finalizados = [];

    if (clientes != null) {
      final resultado = _separarClientesPorData(clientes);
      proximas = resultado.$1;
      finalizados = resultado.$2;
    }

    final pastaExpanded = _pastaExpandedPorConsultor[consultor.id] ?? false;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: _AnimatedSizeExpansionCard(
          title: consultor.nome,
          expanded: pastaExpanded,
          onChanged: (v) async {
            _pastaExpandedPorConsultor[consultor.id] = v;
            setState(() {});

            if (v) {
              await _carregarClientesDoConsultor(consultor);
            }
          },
          vsync: this,
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.indigo.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _iniciais(consultor.nome),
                        style: const TextStyle(
                          color: Colors.indigo,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(consultor.nome, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                          Text(
                            clientes == null
                                ? 'Abrir para carregar clientes'
                                : '${proximas.length + finalizados.length} cliente${(proximas.length + finalizados.length) == 1 ? '' : 's'}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (isLoading)
                  const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
                else if (clientes == null)
                  _emptyBox(
                    context,
                    icon: Icons.folder_open,
                    title: 'Clientes não carregados',
                    subtitle: 'Abra a pasta do consultor para carregar os clientes',
                  )
                else if (clientes.isEmpty)
                  _emptyBox(
                    context,
                    icon: Icons.people_outline,
                    title: 'Nenhum cliente',
                    subtitle: 'Este consultor ainda não tem clientes cadastrados',
                  )
                else ...[
                  _animatedExpansionCard(
                    title: 'Próximas Visitas (${proximas.length})',
                    expanded: _proxExpandedPorConsultor[consultor.id] ?? false,
                    onChanged: (v) => setState(() => _proxExpandedPorConsultor[consultor.id] = v),
                    child: (_proxExpandedPorConsultor[consultor.id] ?? false)
                        ? (proximas.isEmpty
                            ? _emptyBox(
                                context,
                                icon: Icons.calendar_today_outlined,
                                title: 'Nenhuma visita agendada',
                                subtitle: _query.isEmpty ? 'Todas as visitas foram realizadas' : 'Sem resultados para "${_query}"',
                              )
                            : _buildVisitasList(proximas))
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 16),
                  _animatedExpansionCard(
                    title: 'Finalizados (${finalizados.length})',
                    expanded: _finExpandedPorConsultor[consultor.id] ?? false,
                    onChanged: (v) => setState(() => _finExpandedPorConsultor[consultor.id] = v),
                    child: (_finExpandedPorConsultor[consultor.id] ?? false)
                        ? (finalizados.isEmpty
                            ? _emptyBox(
                                context,
                                icon: Icons.check_circle_outline,
                                title: 'Nenhuma visita finalizada',
                                subtitle: _query.isEmpty ? 'As visitas concluídas aparecerão aqui' : 'Sem finalizados para "${_query}"',
                              )
                            : _buildVisitasList(finalizados))
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVisitasList(List<ClienteVisita> itens) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: itens.length,
      separatorBuilder: (_, __) => const SizedBox(height: 0),
      itemBuilder: (_, i) => _buildVisitaItem(itens[i]),
    );
  }

  Widget _animatedExpansionCard({
    required String title,
    required bool expanded,
    required ValueChanged<bool> onChanged,
    required Widget child,
  }) {
    return _AnimatedSizeExpansionCard(
      title: title,
      expanded: expanded,
      onChanged: onChanged,
      child: child,
      vsync: this,
    );
  }

  Widget _emptyBox(BuildContext context, {required IconData icon, required String title, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 8),
          Text(subtitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _cardContainer({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final consultoresFiltrados = _filtrarConsultores();
    final hasContent = !_isLoading && _error == null && consultoresFiltrados.isNotEmpty;

    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: Theme.of(context).colorScheme.background,
          child: CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverToBoxAdapter(child: _buildHeader()),
              
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: _cardContainer(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle('Pesquisar'),
                          TextField(
                            controller: _searchCtrl,
                            textInputAction: TextInputAction.search,
                            decoration: _obterDecoracaoCampo(
                              'Consultor ou cliente',
                              hint: 'Digite o nome do consultor ou cliente...',
                              suffixIcon: _query.isEmpty
                                  ? const Icon(Icons.search)
                                  : IconButton(icon: const Icon(Icons.clear), onPressed: _searchCtrl.clear, tooltip: 'Limpar'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              if (_isLoading)
                const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()))
              else if (_error != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: _cardContainer(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: _ErroState(mensagem: _error!, onRetry: _carregarConsultores),
                      ),
                    ),
                  ),
                )
              else if (!hasContent)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: _cardContainer(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: _emptyBox(
                          context,
                          icon: Icons.groups_2_rounded,
                          title: 'Nenhum consultor encontrado',
                          subtitle: _query.isEmpty 
                              ? 'Verifique os consultores ativos e as permissões (RLS).'
                              : 'Nenhum consultor ou cliente corresponde à pesquisa',
                        ),
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final consultor = consultoresFiltrados[index];
                      return _buildConsultorCard(consultor);
                    },
                    childCount: consultoresFiltrados.length,
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }

  String _iniciais(String nome) {
    final parts = nome.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '??';
    final first = parts.first;
    final second = parts.length > 1 ? parts.last : '';
    final a = first.isNotEmpty ? first[0] : '?';
    final b = second.isNotEmpty ? second[0] : (first.length > 1 ? first[1] : '');
    return (a + b).toUpperCase();
  }
}

class _AnimatedSizeExpansionCard extends StatefulWidget {
  final String title;
  final bool expanded;
  final ValueChanged<bool> onChanged;
  final Widget child;
  final TickerProvider vsync;

  const _AnimatedSizeExpansionCard({
    required this.title,
    required this.expanded,
    required this.onChanged,
    required this.child,
    required this.vsync,
  });

  @override
  State<_AnimatedSizeExpansionCard> createState() => _AnimatedSizeExpansionCardState();
}

class _AnimatedSizeExpansionCardState extends State<_AnimatedSizeExpansionCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _turns;
  late bool _expandedLocal;

  @override
  void initState() {
    super.initState();
    _expandedLocal = widget.expanded;
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
    _turns = Tween<double>(begin: 0.0, end: 0.5).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    if (_expandedLocal) _ctrl.value = 1.0;
  }

  @override
  void didUpdateWidget(covariant _AnimatedSizeExpansionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded != _expandedLocal) {
      _toggle(explicit: widget.expanded);
    }
  }

  void _toggle({bool? explicit}) {
    setState(() {
      _expandedLocal = explicit ?? !_expandedLocal;
      if (_expandedLocal) {
        _ctrl.forward();
      } else {
        _ctrl.reverse();
      }
      widget.onChanged(_expandedLocal);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.folder, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  RotationTransition(
                    turns: _turns,
                    child: const Icon(Icons.expand_more),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: _expandedLocal ? const BoxConstraints() : const BoxConstraints(maxHeight: 0.0),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: widget.child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class Consultor {
  final String id;   
  final String uid;  
  final String nome;
  Consultor({required this.id, required this.uid, required this.nome});
}

class ClienteVisita {
  final String estabelecimento;
  final String endereco;
  final String bairro;
  final String cidade;
  final String estado;
  final String? dataVisita;
  final String? horaVisita;

  ClienteVisita({
    required this.estabelecimento,
    required this.endereco,
    required this.bairro,
    required this.cidade,
    required this.estado,
    required this.dataVisita,
    required this.horaVisita,
  });
}

class _Debouncer {
  final Duration delay;
  Timer? _timer;
  _Debouncer(this.delay);
  void run(void Function() f) {
    _timer?.cancel();
    _timer = Timer(delay, f);
  }
  void dispose() => _timer?.cancel();
}

class _ErroState extends StatelessWidget {
  final String mensagem;
  final Future<void> Function() onRetry;

  const _ErroState({
    required this.mensagem,
    required this.onRetry,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              mensagem,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }
}
