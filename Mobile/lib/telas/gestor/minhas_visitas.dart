import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:collection/collection.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  final SupabaseClient _client = Supabase.instance.client;

  List<_ConsultorStatus> _consultores = [];
  List<_VisitaProg> _visitas = [];
  String _query = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarDados();
    _searchCtrl.addListener(() {
      setState(() {
        _query = _searchCtrl.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregarDados() async {
    setState(() => _isLoading = true);

    try {
      // 🔹 Consultores ativos
      final consultoresRes = await _client
          .from('consultores')
          .select('id, nome, ativo')
          .eq('ativo', true)
          .order('nome');

      // 🔹 Visitas dos próximos 30 dias
      final now = DateTime.now();
      final thirtyDays = now.add(const Duration(days: 30));

      final visitasRes = await _client
          .from('clientes')
          .select('id, nome, endereco, dataVisita, consultor_uid')
          .gte('dataVisita', now.toIso8601String())
          .lte('dataVisita', thirtyDays.toIso8601String())
          .order('dataVisita')
          .limit(10);

      // Cria mapa de consultores por ID para busca rápida
      final Map<String, String> consultorMap = {};
      if (consultoresRes is List) {
        for (var c in consultoresRes) {
          final id = c['id'] as String?;
          final nome = c['nome'] as String?;
          if (id != null && nome != null) {
            consultorMap[id] = nome;
          }
        }
      }

      setState(() {
        _consultores = (consultoresRes as List)
            .map((c) => _ConsultorStatus(
                  nome: (c['nome'] as String?) ?? 'Consultor',
                  status: 'Trabalhando hoje',
                  local: 'Em campo',
                ))
            .toList();

        _visitas = (visitasRes as List)
            .map((v) {
              final dataStr = v['dataVisita'] as String?;
              final data = dataStr != null ? DateTime.parse(dataStr) : DateTime.now();
              final consultorUid = v['consultor_uid'] as String?;
              final nomeConsultor = consultorUid != null ? consultorMap[consultorUid] : null;

              return _VisitaProg(
                titulo: (v['endereco'] as String?) ?? 'Sem endereço',
                consultor: nomeConsultor ?? 'Consultor',
                data: '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}',
              );
            })
            .toList();

        _isLoading = false;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar dados: $error')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  List<_VisitaProg> get _visitasFiltradas {
    if (_query.isEmpty) return _visitas;
    final q = _query.toLowerCase();
    return _visitas.where((v) => v.titulo.toLowerCase().contains(q)).toList();
  }

  bool get _ruaJaProgramada {
    if (_query.isEmpty) return false;
    final q = _query.toLowerCase();
    return _visitas.any((v) => v.titulo.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _SearchBar(
                  controller: _searchCtrl,
                  hint: 'Pesquisar nome da rua...',
                ),
                const SizedBox(height: 12),

                if (_query.isNotEmpty)
                  _DisponibilidadeChip(disponivel: !_ruaJaProgramada),

                const SizedBox(height: 16),

                _Section(
                  title: "Status dos Consultores",
                  subtitle: "Situação atual de trabalho de cada consultor",
                  child: Column(
                    children: _consultores
                        .map((c) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _ConsultorStatusTile(
                                nome: c.nome,
                                status: c.status,
                                local: c.local,
                              ),
                            ))
                        .toList(),
                  ),
                ),

                const SizedBox(height: 16),

                _Section(
                  title: "Visitas Programadas",
                  subtitle: _query.isEmpty
                      ? "Próximas visitas programadas"
                      : "Resultados para: $_query",
                  child: Column(
                    children: _visitasFiltradas
                        .map((v) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _VisitaTile(
                                titulo: v.titulo,
                                consultor: v.consultor,
                                data: v.data,
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          );
  }
}

// ====== MODELOS ======
class _ConsultorStatus {
  final String nome;
  final String status;
  final String local;
  const _ConsultorStatus({
    required this.nome,
    required this.status,
    required this.local,
  });
}

class _VisitaProg {
  final String titulo;
  final String consultor;
  final String data;
  const _VisitaProg({
    required this.titulo,
    required this.consultor,
    required this.data,
  });
}

// ====== WIDGETS ======
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  const _SearchBar({required this.controller, this.hint = 'Pesquisar...'});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => controller.clear(),
                tooltip: 'Limpar',
              ),
        filled: true,
        fillColor: const Color(0xFFF7F7F7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black12),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      ),
      onSubmitted: (_) {},
    );
  }
}

class _DisponibilidadeChip extends StatelessWidget {
  final bool disponivel;
  const _DisponibilidadeChip({required this.disponivel});

  @override
  Widget build(BuildContext context) {
    final color = disponivel ? const Color(0xFF2E7D32) : const Color(0xFF6B7280);
    final bg = disponivel ? const Color(0xFFE8F5E9) : const Color(0xFFF3F4F6);
    final texto = disponivel ? 'Disponível' : 'Já programada';

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              disponivel ? Icons.check_circle : Icons.info_outline,
              color: color,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              texto,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  const _Section({required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Colors.black54, fontSize: 12)),
          const SizedBox(height: 12),
          child,
        ]),
      ),
    );
  }
}

class _ConsultorStatusTile extends StatelessWidget {
  final String nome;
  final String status;
  final String local;
  const _ConsultorStatusTile({required this.nome, required this.status, required this.local});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1FFF3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2F6E5)),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const CircleAvatar(child: Icon(Icons.person)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(nome, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.place, size: 16, color: Colors.green),
                  const SizedBox(width: 4),
                  Expanded(child: Text(local, style: const TextStyle(color: Colors.black54))),
                ],
              ),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFE9FFF0),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(status, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _VisitaTile extends StatelessWidget {
  final String titulo;
  final String consultor;
  final String data;
  const _VisitaTile({required this.titulo, required this.consultor, required this.data});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: const Color(0xFFF7F7F7),
      title: Text(titulo),
      subtitle: Text(consultor),
      trailing: Text(data, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}
