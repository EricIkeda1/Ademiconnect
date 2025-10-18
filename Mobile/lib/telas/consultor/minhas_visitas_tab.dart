// lib/telas/consultor/minhas_visitas.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class MinhasVisitasTab extends StatefulWidget {
  const MinhasVisitasTab({super.key});

  @override
  State<MinhasVisitasTab> createState() => _MinhasVisitasTabState();
}

class _MinhasVisitasTabState extends State<MinhasVisitasTab> {
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

  // ORDENAR POR MAIS RECENTES (data desc, hora desc)
  Stream<List<Map<String, dynamic>>> get _meusClientesStream {
    final user = _client.auth.currentSession?.user;
    if (user == null) {
      return const Stream<List<Map<String, dynamic>>>.empty();
    }

    return _client
        .from('clientes')
        .select('*')
        .eq('consultor_uid_t', user.id)
        .order('data_visita', ascending: false) // datas mais novas primeiro
        .order('hora_visita', ascending: false) // em empate, hora mais nova primeiro
        .asStream();
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
        const SnackBar(
          content: Text('Não foi possível abrir o Google Maps'),
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
              Icons.calendar_today_rounded,
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
                  'Minhas Visitas',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Gerencie seu cronograma de visitas',
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
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(title),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildVisitaItem(Map<String, dynamic> cliente) {
    final cs = Theme.of(context).colorScheme;

    final endereco = (cliente['endereco'] as String?)?.trim();
    final estabelecimento = (cliente['estabelecimento'] as String?)?.trim() ?? 'Estabelecimento não informado';

    final dataVisitaStr = cliente['data_visita'] as String?;
    final horaVisitaStr = cliente['hora_visita'] as String?; // TIME ex: 14:30:00
    final cidade = (cliente['cidade'] as String?)?.trim() ?? '';
    final estado = (cliente['estado'] as String?)?.trim() ?? '';

    final dataFormatada = _formatarDataVisita(dataVisitaStr, horaVisitaStr);
    final statusInfo = _determinarStatus(dataVisitaStr, horaVisitaStr: horaVisitaStr);

    final enderecoCompleto = [
      if ((endereco ?? '').isNotEmpty) endereco,
      if (cidade.isNotEmpty || estado.isNotEmpty) '$cidade - $estado',
    ].where((e) => (e ?? '').isNotEmpty).join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cs.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              statusInfo['icone'],
              size: 20,
              color: cs.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusInfo['corFundo'],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusInfo['texto'] as String,
                    style: TextStyle(
                      color: statusInfo['corTexto'],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  estabelecimento,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (enderecoCompleto.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _abrirNoGoogleMaps(enderecoCompleto);
                    },
                    child: Text(
                      enderecoCompleto,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: cs.primary,
                            decoration: TextDecoration.underline,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  dataFormatada,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant.withOpacity(0.7),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Combina data + hora, normaliza para local, e classifica corretamente HOJE/REALIZADA/AGENDADO
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
      // Parse e normalização para fuso local
      DateTime data = DateTime.parse(dataVisitaStr).toLocal(); // normaliza para local

      // Combina a hora se existir; senão, usa 23:59 para não antecipar "REALIZADA"
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

      final ehHoje = (data.isAfter(hojeInicio) && data.isBefore(hojeFim)) ||
          data.isAtSameMomentAs(hojeInicio) ||
          data.isAtSameMomentAs(hojeFim);

      if (ehHoje) {
        return {
          'icone': Icons.flag_outlined,
          'texto': 'HOJE',
          'corFundo': Colors.black,
          'corTexto': Colors.white,
        };
      } else if (data.isBefore(hojeInicio)) {
        return {
          'icone': Icons.check_circle_outlined,
          'texto': 'REALIZADA',
          'corFundo': cs.primaryContainer,
          'corTexto': cs.onPrimaryContainer,
        };
      } else {
        return {
          'icone': Icons.event_note_outlined,
          'texto': 'AGENDADO',
          'corFundo': const Color(0x3328A745),
          'corTexto': Colors.green,
        };
      }
    } catch (_) {
      return {
        'icone': Icons.event_note_outlined,
        'texto': 'AGENDADO',
        'corFundo': const Color(0x3328A745),
        'corTexto': Colors.green,
      };
    }
  }

  // Formata combinando a hora real; usa toLocal para coerência de fuso
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(
            child: _buildCard(
              title: 'Pesquisar Visitas',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _searchCtrl,
                    textInputAction: TextInputAction.search,
                    decoration: _obterDecoracaoCampo(
                      'Estabelecimento ou endereço',
                      hint: 'Digite para pesquisar visitas...',
                      suffixIcon: _query.isEmpty
                          ? const Icon(Icons.search)
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: _searchCtrl.clear,
                              tooltip: 'Limpar',
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _meusClientesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildCard(
                    title: 'Próximas Visitas',
                    child: Column(
                      children: List.generate(
                        3,
                        (index) => Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceVariant,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 80,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.surfaceVariant,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      width: double.infinity,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.surfaceVariant,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return _buildCard(
                    title: 'Próximas Visitas',
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Erro ao carregar visitas: ${snapshot.error}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildCard(
                    title: 'Próximas Visitas',
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 48,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Nenhuma visita agendada',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Cadastre clientes para ver as visitas aqui',
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final clientes = snapshot.data!;
                final clientesFiltrados = _query.isEmpty
                    ? clientes
                    : clientes.where((cliente) {
                        final estabelecimento = (cliente['estabelecimento']?.toString().toLowerCase() ?? '');
                        final endereco = (cliente['endereco']?.toString().toLowerCase() ?? '');
                        final query = _query.toLowerCase();
                        return estabelecimento.contains(query) || endereco.contains(query);
                      }).toList();

                if (clientesFiltrados.isEmpty) {
                  return _buildCard(
                    title: 'Próximas Visitas',
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.search_off_outlined,
                            size: 48,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Nenhuma visita encontrada',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tente ajustar os termos da pesquisa',
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return _buildCard(
                  title: 'Próximas Visitas (${clientesFiltrados.length})',
                  child: Column(
                    children: clientesFiltrados.map((cliente) => _buildVisitaItem(cliente)).toList(),
                  ),
                );
              },
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }
}
