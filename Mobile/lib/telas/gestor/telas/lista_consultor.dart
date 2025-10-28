import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cadastrar_consultor.dart';

const _brandRed = Color(0xFFEA3124);
const _bg = Color(0xFFF6F6F8);
const _textPrimary = Color(0xFF222222);

class ConsultoresRoot extends StatefulWidget {
  final VoidCallback? onCadastrar;
  const ConsultoresRoot({super.key, this.onCadastrar});

  @override
  State<ConsultoresRoot> createState() => _ConsultoresRootState();
}

class _ConsultoresRootState extends State<ConsultoresRoot> {
  static const _pageSize = 10;

  final _client = Supabase.instance.client;

  final List<_ConsultorView> _consultores = [];
  int _visibleCount = 0; 
  int _totalCount = 0;   
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchFirstPage();
  }

  Future<void> _fetchFirstPage() async {
    setState(() {
      _consultores.clear();
      _visibleCount = 0;
      _totalCount = 0;
      _loading = true;
      _error = null;
    });
    try {
      await Future.wait([_fetchTotalCount(), _fetchPage()]);
    } catch (e) {
      setState(() => _error = 'Erro ao carregar: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchTotalCount() async {
    final total = await _client.from('consultores').count(CountOption.exact);
    setState(() => _totalCount = total);
  }

  Future<void> _fetchPage() async {
    final start = _visibleCount;
    final end = _visibleCount + _pageSize - 1;

    final dynamic result = await _client
        .from('consultores')
        .select('id, uid, nome, email, telefone, matricula')
        .order('nome', ascending: true)
        .range(start, end);

    final List<dynamic> raw = result as List<dynamic>;
    final rows = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();

    final mapped = rows.map((r) => _ConsultorView(
          r['id'].toString(),
          (r['nome'] as String?) ?? '',
          (r['matricula'] as String?) ?? '',
          (r['telefone'] as String?) ?? '',
          (r['email'] as String?) ?? '',
        ));

    setState(() {
      _consultores.addAll(mapped);
      _visibleCount = _consultores.length;
    });
  }

  Future<void> _fetchMore() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _fetchPage();
    } catch (e) {
      setState(() => _error = 'Erro ao carregar mais: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCadastrarConsultor() async {
    if (widget.onCadastrar != null) {
      widget.onCadastrar!.call();
      return;
    }
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CadastrarConsultorPage()),
    );
    if (ok == true) {
      await _fetchFirstPage(); 
    }
  }

  @override
  Widget build(BuildContext context) {
    final showLoadMore = _visibleCount < _totalCount;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchFirstPage,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(Icons.group, color: _brandRed, size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      'Consultores',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _brandRed,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$_totalCount consultores',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Gerencie a equipe de consultores',
                  style: TextStyle(color: Colors.black54, fontSize: 14),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _openCadastrarConsultor,
                    icon: const Icon(Icons.person_add_alt_1, color: Colors.white, size: 22),
                    label: const Text(
                      'Cadastrar Novo Consultor',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brandRed,
                      elevation: 3,
                      shadowColor: const Color(0x33000000),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),

                if (_loading && _visibleCount == 0)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(),
                    ),
                  ),

                ..._consultores.map(
                  (c) => _ConsultorCard(
                    c: c,
                    onEditar: _openCadastrarConsultor,
                    onApagar: () async {
                      try {
                        await _client.from('consultores').delete().eq('id', c.id);
                        setState(() {
                          _consultores.removeWhere((x) => x.id == c.id);
                          _totalCount = (_totalCount - 1).clamp(0, 1 << 31);
                          _visibleCount = _consultores.length;
                        });
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Falha ao apagar: $e')),
                        );
                      }
                    },
                  ),
                ),

                if (showLoadMore)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Center(
                      child: OutlinedButton(
                        onPressed: _loading ? null : _fetchMore,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: _brandRed),
                          foregroundColor: _brandRed,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        child: _loading
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : Text('Ver mais (${_totalCount - _visibleCount})'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConsultorView {
  final String id, nome, matricula, telefone, email;
  _ConsultorView(this.id, this.nome, this.matricula, this.telefone, this.email);
}

class _ConsultorCard extends StatelessWidget {
  final _ConsultorView c;
  final VoidCallback onEditar;
  final VoidCallback onApagar;
  const _ConsultorCard({super.key, required this.c, required this.onEditar, required this.onApagar});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 3,
      shadowColor: const Color(0x33000000),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.account_circle, color: _brandRed, size: 42),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.nome, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.black87)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFF1F1F1), borderRadius: BorderRadius.circular(4)),
                        child: Text(c.matricula, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: onEditar,
                      icon: const Icon(Icons.edit, size: 16, color: _brandRed),
                      label: const Text('Editar', style: TextStyle(color: _brandRed)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _brandRed),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        foregroundColor: _brandRed,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton.icon(
                      onPressed: onApagar,
                      icon: const Icon(Icons.delete, size: 16, color: _brandRed),
                      label: const Text('Apagar', style: TextStyle(color: _brandRed)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _brandRed),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        foregroundColor: _brandRed,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(children: [const Icon(Icons.phone, size: 16, color: Colors.grey), const SizedBox(width: 6), Text(c.telefone, style: const TextStyle(color: Colors.black87))]),
            const SizedBox(height: 4),
            Row(children: [const Icon(Icons.email_outlined, size: 16, color: Colors.grey), const SizedBox(width: 6), Text(c.email, style: const TextStyle(color: Colors.black87))]),
          ],
        ),
      ),
    );
  }
}
