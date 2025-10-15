import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get _currentUser {
    try {
      return _auth.currentUser;
    } catch (e) {
      print('Erro ao obter currentUser: $e');
      return null;
    }
  }

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

  Stream<QuerySnapshot> get _meusClientesStream {
    final user = _currentUser;
    if (user == null) {
      return const Stream<QuerySnapshot>.empty();
    }
    
    return _firestore
        .collection('clientes')
        .where('consultorUid', isEqualTo: user.uid)
        .snapshots();
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

  Widget _buildVisitaItem(DocumentSnapshot doc) {
    final cs = Theme.of(context).colorScheme;
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    final endereco = data['endereco'] ?? 'Endereço não informado';
    final estabelecimento = data['estabelecimento'] ?? 'Estabelecimento não informado';
    final dataVisitaStr = data['dataVisita']?.toString();
    final cidade = data['cidade'] ?? '';
    final estado = data['estado'] ?? '';
    
    final dataFormatada = _formatarDataVisita(dataVisitaStr);
    final statusInfo = _determinarStatus(dataVisitaStr);

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
                    statusInfo['texto'],
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
                
                Text(
                  '$endereco, $cidade - $estado',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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

  String _formatarDataVisita(String? dataVisitaStr) {
    if (dataVisitaStr == null || dataVisitaStr.isEmpty) return 'Data não informada';
    
    try {
      final dataVisita = DateTime.parse(dataVisitaStr);
      
      final hoje = DateTime.now();
      final amanha = DateTime(hoje.year, hoje.month, hoje.day + 1);
      
      if (dataVisita.year == hoje.year && dataVisita.month == hoje.month && dataVisita.day == hoje.day) {
        return 'Hoje às ${DateFormat('HH:mm', 'pt_BR').format(dataVisita)}';
      } else if (dataVisita.year == amanha.year && dataVisita.month == amanha.month && dataVisita.day == amanha.day) {
        return 'Amanhã às ${DateFormat('HH:mm', 'pt_BR').format(dataVisita)}';
      } else {
        final format = dataVisita.year == hoje.year
            ? 'EEE, d MMMM' 
            : 'EEE, d MMMM y';
        
        return '${_capitalize(DateFormat(format, 'pt_BR').format(dataVisita))} às ${DateFormat('HH:mm', 'pt_BR').format(dataVisita)}';
      }
    } catch (e) {
      return 'Data inválida';
    }
  }

  Map<String, dynamic> _determinarStatus(String? dataVisitaStr) {
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
      final dataVisita = DateTime.parse(dataVisitaStr);
      final hoje = DateTime.now();
      final hojeInicio = DateTime(hoje.year, hoje.month, hoje.day);
      final hojeFim = DateTime(hoje.year, hoje.month, hoje.day, 23, 59, 59);
      
      if (dataVisita.isAfter(hojeInicio) && dataVisita.isBefore(hojeFim)) {
        return {
          'icone': Icons.flag_outlined,
          'texto': 'HOJE',
          'corFundo': Colors.black,
          'corTexto': Colors.white,
        };
      } else if (dataVisita.isBefore(hoje)) {
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
    } catch (e) {
      return {
        'icone': Icons.event_note_outlined,
        'texto': 'AGENDADO',
        'corFundo': const Color(0x3328A745),
        'corTexto': Colors.green,
      };
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
          SliverToBoxAdapter(
            child: _buildHeader(),
          ),

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

          // REMOVIDO: Seção "Rua de Trabalho - Hoje" foi movida para home_consultor.dart

          SliverToBoxAdapter(
            child: StreamBuilder<QuerySnapshot>(
              stream: _meusClientesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildCard(
                    title: 'Próximas Visitas',
                    child: Column(
                      children: List.generate(3, (index) => Container(
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
                      )),
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
                              'Erro ao carregar visitas',
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

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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

                final clientes = snapshot.data!.docs;
                final clientesFiltrados = _query.isEmpty
                    ? clientes
                    : clientes.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final estabelecimento = data['estabelecimento']?.toString().toLowerCase() ?? '';
                        final endereco = data['endereco']?.toString().toLowerCase() ?? '';
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
                    children: clientesFiltrados.map(_buildVisitaItem).toList(),
                  ),
                );
              },
            ),
          ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 20),
          ),
        ],
      ),
    );
  }
}