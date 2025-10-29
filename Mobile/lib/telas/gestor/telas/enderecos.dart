import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Color kRed = Color(0xFFED3B2E);
const Color kRedLight = Color(0xFFFFE5E3);
const Color kBorder = Color(0xFFE8E8E8);
const Color kBg = Color(0xFFF7F7F7);
const Color kShadow10 = Color(0x1A000000);

class BairroResumo {
  final String nome;
  final List<String> ruas;
  const BairroResumo({required this.nome, required this.ruas});
}

class _EnderecoRepo {
  final SupabaseClient sb;
  _EnderecoRepo(this.sb);

  Future<Map<String, List<BairroResumo>>> listarPorCidades({double similaridade = 0.62}) async {
    final rows = await sb.rpc('rpc_cidades_bairros_ruas', params: {
      'min_similaridade': similaridade,
    });

    final mapa = <String, List<BairroResumo>>{};
    for (final r in (rows as List)) {
      final cidade = (r['cidade'] ?? 'Sem cidade').toString();
      final bairro = (r['bairro'] ?? 'Sem bairro').toString();
      final ruas = ((r['ruas'] as List?) ?? const [])
          .map((e) => (e ?? '').toString())
          .where((s) => s.trim().isNotEmpty)
          .toList();
      (mapa[cidade] ??= []).add(BairroResumo(nome: bairro, ruas: ruas));
    }
    for (final e in mapa.entries) {
      e.value.sort((a, b) => a.nome.compareTo(b.nome));
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

  void _recarregar() => setState(() => _future = _repo.listarPorCidades());

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
            'Visualize e gerencie as cidades, bairros e ruas do sistema',
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
                        final totalRuas = bairros.fold<int>(0, (acc, b) => acc + b.ruas.length);
                        return _CidadeCard(
                          cidade: cidade,
                          bairros: bairros,
                          totalBairros: totalBairros,
                          totalRuas: totalRuas,
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
  final int totalRuas;
  const _CidadeCard({
    required this.cidade,
    required this.bairros,
    required this.totalBairros,
    required this.totalRuas,
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
                          Text('${widget.totalBairros} bairros',
                              style: const TextStyle(fontSize: 12.5, color: Color(0x99000000))),
                          const SizedBox(width: 12),
                          const Icon(Icons.route_outlined, size: 14, color: Color(0x99000000)),
                          const SizedBox(width: 4),
                          Text('${widget.totalRuas} ruas',
                              style: const TextStyle(fontSize: 12.5, color: Color(0x99000000))),
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
                      Text('${widget.bairro.ruas.length} ruas',
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
                children: widget.bairro.ruas
                    .map((r) => Container(
                          height: 40,
                          margin: const EdgeInsets.only(top: 8),
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFDFDFDF)),
                          ),
                          child: Text(r, style: const TextStyle(color: Color(0xFF231F20))),
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}
