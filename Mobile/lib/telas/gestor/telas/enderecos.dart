import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Color kRed = Color(0xFFED3B2E);
const Color kRedLight = Color(0xFFFFE5E3);
const Color kBorder = Color(0xFFE8E8E8);
const Color kBg = Color(0xFFF7F7F7);
const Color kShadow10 = Color(0x1A000000);

class BairroResumo {
  final String nome;
  final List<String> enderecos; 
  const BairroResumo({required this.nome, required this.enderecos});
}

class _EnderecoRepo {
  final SupabaseClient sb;
  _EnderecoRepo(this.sb);

  String _cleanTail(String s) => s.replaceFirst(RegExp(r',\s*$'), '').trimRight();
  String _cleanHead(String s) => s.replaceFirst(RegExp(r'^\s*,\s*'), '').trimLeft();

  String _fixCommaAfterTypeAtStart(String s) {
    final reDot = RegExp(r'^\s*(R\.|Av\.|Rod\.|Al\.|Trav\.)\s*,\s*', caseSensitive: false);
    final reFull = RegExp(r'^\s*(Rua|Avenida|Rodovia|Alameda|Travessa)\s*,\s*', caseSensitive: false);
    var out = s;
    out = out.replaceFirstMapped(reDot, (m) => '${m.group(1)} ');
    out = out.replaceFirstMapped(reFull, (m) => '${m.group(1)} ');
    return out;
  }

  String _removeCommaBeforeTypes(String s) {
    final pattern = RegExp(
      r',\s*(?=(R\.|Av\.|Rod\.|Al\.|Trav\.|Rua|Avenida|Rodovia|Alameda|Travessa)\b)',
      caseSensitive: false,
    );
    return s.replaceAll(pattern, ' ');
  }

  String _fmtLogEndNumCompl({
    required String logradouro,
    required String endereco,
    required String numero,
    required String complemento,
  }) {
    var l = _fixCommaAfterTypeAtStart(_cleanTail(logradouro));
    final e = _cleanTail(endereco);
    final n = numero.trim();
    final c = complemento.trim();

    final partes = <String>[];
    if (l.isNotEmpty) partes.add(l);
    if (e.isNotEmpty) partes.add(e);
    if (n.isNotEmpty) partes.add(n);
    if (c.isNotEmpty) partes.add(c);

    var out = partes.join(', ');
    out = _cleanHead(out);
    out = _cleanTail(out);
    out = _removeCommaBeforeTypes(out);
    out = out.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    return out;
  }

  Future<Map<String, List<BairroResumo>>> listarPorCidades({double similaridade = 0.62}) async {
    final gestorId = sb.auth.currentUser?.id;
    if (gestorId == null) return {};

    var cQ = sb.from('consultores').select('uid').filter('gestor_id', 'eq', gestorId).filter('ativo', 'eq', true);
    final cons = await cQ;
    final uids = (cons is List ? cons : const [])
        .map((e) => (e['uid'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toList();

    if (uids.isEmpty) return {};

    final inText = uids.map((e) => '"$e"').join(',');
    var q = sb
        .from('clientes')
        .select('cidade, bairro, logradouro, endereco, numero, complemento, consultor_uid_t')
        .filter('consultor_uid_t', 'in', '($inText)');

    final rows = await q;

    final mapa = <String, List<BairroResumo>>{};
    if (rows is List) {
      final tmp = <String, Map<String, List<String>>>{};

      for (final r in rows) {
        final cidade = (r['cidade'] ?? 'Sem cidade').toString();
        final bairro = (r['bairro'] ?? 'Sem bairro').toString();
        final logradouro = (r['logradouro'] ?? '').toString();
        final endereco = (r['endereco'] ?? '').toString();
        final numero = (r['numero'] ?? '').toString();
        final compl = (r['complemento'] ?? '').toString();

        final linha = _fmtLogEndNumCompl(
          logradouro: logradouro,
          endereco: endereco,
          numero: numero,
          complemento: compl,
        );

        if (linha.isEmpty) continue;

        final byCidade = (tmp[cidade] ??= <String, List<String>>{});
        final lista = (byCidade[bairro] ??= <String>[]);
        lista.add(linha);
      }

      for (final entry in tmp.entries) {
        final cidade = entry.key;
        final bairrosMap = entry.value;
        final bairrosList = <BairroResumo>[];
        for (final b in bairrosMap.entries) {
          final lista = b.value.toSet().toList()..sort();
          bairrosList.add(BairroResumo(nome: b.key, enderecos: lista));
        }
        bairrosList.sort((a, b) => a.nome.compareTo(b.nome));
        mapa[cidade] = bairrosList;
      }
    }

    return mapa;
  }
}

class EnderecosPage extends StatefulWidget {
  const EnderecosPage({super.key});
  @override
  State<EnderecosPage> createState() => _EnderecosPageState();
}

class _EnderecosPageState extends State<EnderecosPage> {
  late final _EnderecoRepo _repo;
  late Future<Map<String, List<BairroResumo>>> _future;

  @override
  void initState() {
    super.initState();
    _repo = _EnderecoRepo(Supabase.instance.client);
    _future = _repo.listarPorCidades();
  }

  void _recarregar() {
    setState(() {
      _future = _repo.listarPorCidades();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget header() {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: const [
              Icon(Icons.location_city_outlined, color: kRed),
              SizedBox(width: 8),
              Text('Gerenciamento de Endereços', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Visualize e gerencie as cidades, bairros e endereços do seu time',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurface.withOpacity(0.6)),
          ),
        ]),
      );
    }

    return Container(
      color: kBg,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            header(),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<Map<String, List<BairroResumo>>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text('Erro ao carregar dados'),
                        const SizedBox(height: 8),
                        FilledButton(onPressed: _recarregar, child: const Text('Tentar novamente')),
                      ]),
                    );
                  }

                  final mapa = snap.data ?? {};
                  if (mapa.isEmpty) {
                    return const Center(child: Text('Nenhum endereço encontrado'));
                  }

                  final cidades = mapa.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

                  return RefreshIndicator(
                    onRefresh: () async => _recarregar(),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                      itemCount: cidades.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final cidade = cidades[i].key;
                        final bairros = cidades[i].value;
                        final totalBairros = bairros.length;
                        final totalEnderecos = bairros.fold<int>(0, (acc, b) => acc + b.enderecos.length);
                        return _CidadeCard(
                          cidade: cidade,
                          bairros: bairros,
                          totalBairros: totalBairros,
                          totalEnderecos: totalEnderecos,
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CidadeCard extends StatefulWidget {
  final String cidade;
  final List<BairroResumo> bairros;
  final int totalBairros;
  final int totalEnderecos;
  const _CidadeCard({
    required this.cidade,
    required this.bairros,
    required this.totalBairros,
    required this.totalEnderecos,
  });

  @override
  State<_CidadeCard> createState() => _CidadeCardState();
}

class _CidadeCardState extends State<_CidadeCard> {
  bool _expanded = false;

  BoxDecoration _cardDeco({required bool highlighted}) => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _expanded ? const Color(0xFFE7CBC8) : kBorder),
        boxShadow: [BoxShadow(color: kShadow10, blurRadius: highlighted ? 10 : 6, offset: const Offset(0, 2))],
      );

  Widget _cityIcon() => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: kRedLight, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.location_city_outlined, color: kRed),
      );

  Widget _badgeExpandido() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: kRed, borderRadius: BorderRadius.circular(20)),
        child: const Text('Expandido', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDeco(highlighted: _expanded),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  _cityIcon(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(widget.cidade,
                                style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: Color(0xFF231F20))),
                          ),
                          if (_expanded) _badgeExpandido(),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.layers_outlined, size: 14, color: Color(0x99000000)),
                          const SizedBox(width: 4),
                          Text('${widget.totalBairros} bairros', style: const TextStyle(fontSize: 12.5, color: Color(0x99000000))),
                          const SizedBox(width: 12),
                          const Icon(Icons.route_outlined, size: 14, color: Color(0x99000000)),
                          const SizedBox(width: 4),
                          Text('${widget.totalEnderecos} endereços', style: const TextStyle(fontSize: 12.5, color: Color(0x99000000))),
                        ],
                      ),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: kRed),
                ],
              ),
            ),
          ),
          if (_expanded)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kBorder),
              ),
              child: Column(
                children: widget.bairros.map((b) => _BairroCard(bairro: b)).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _BairroCard extends StatefulWidget {
  final BairroResumo bairro;
  const _BairroCard({required this.bairro});

  @override
  State<_BairroCard> createState() => _BairroCardState();
}

class _BairroCardState extends State<_BairroCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
        boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(color: kRedLight, shape: BoxShape.circle),
                    child: const Icon(Icons.location_on, size: 16, color: kRed),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.bairro.nome,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF231F20))),
                      const SizedBox(height: 2),
                      Text('${widget.bairro.enderecos.length} endereços',
                          style: const TextStyle(fontSize: 12.5, color: Color(0x99000000))),
                    ]),
                  ),
                  Icon(_open ? Icons.expand_less : Icons.expand_more, color: kRed),
                ],
              ),
            ),
          ),
          if (_open)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: widget.bairro.enderecos
                    .map((end) => Container(
                          height: 40,
                          margin: const EdgeInsets.only(top: 8),
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFDFDFDF)),
                          ),
                          child: Text(end, style: const TextStyle(color: Color(0xFF231F20))),
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}
