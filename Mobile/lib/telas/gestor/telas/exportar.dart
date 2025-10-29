import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ExportarPage extends StatefulWidget {
  const ExportarPage({super.key});
  @override
  State<ExportarPage> createState() => _ExportarPageState();
}

class _ExportarPageState extends State<ExportarPage> {
  final sb = Supabase.instance.client;

  bool _loadingCsv = false;
  int? _qtdClientes;

  static const red = Color(0xFFED3B2E);
  static const redLight = Color(0xFFFFE5E3);
  static const border = Color(0xFFE8E8E8);
  static const bg = Color(0xFFF7F7F7);
  static const shadow = Color(0x1A000000);

  static const double kCanvas = 360; 
  static const double kPadH = 12;   
  static const double kGapHeaderToCard = 12;
  static const double kGapCards = 12;

  @override
  void initState() {
    super.initState();
    _carregarResumo();
  }

  Future<void> _carregarResumo() async {
    try {
      final res = await sb.from('clientes').select('id').count();
      setState(() => _qtdClientes = res.count ?? 0);
    } catch (_) {
      setState(() => _qtdClientes = null);
    }
  }

  Future<void> _baixarCSV() async {
    setState(() => _loadingCsv = true);
    try {
      final rows = await sb
          .from('clientes')
          .select('id,nome,endereco,bairro,cidade,estado,cep,telefone,data_visita,observacoes,consultor_uid_t,hora_visita,responsavel,consultor_id')
          .order('nome', ascending: true);

      final list = (rows as List);
      final buffer = StringBuffer();
      buffer.writeln('id;nome;endereco;bairro;cidade;estado;cep;telefone;data_visita;observacoes;consultor_uid_t;hora_visita;responsavel;consultor_id');

      String esc(dynamic v) {
        final s = (v ?? '').toString().replaceAll('\n', ' ').replaceAll(';', ',');
        return '"$s"';
      }

      for (final r in list) {
        buffer.writeln([
          esc(r['id']),
          esc(r['nome']),
          esc(r['endereco']),
          esc(r['bairro']),
          esc(r['cidade']),
          esc(r['estado']),
          esc(r['cep']),
          esc(r['telefone']),
          esc(r['data_visita']),
          esc(r['observacoes']),
          esc(r['consultor_uid_t']),
          esc(r['hora_visita']),
          esc(r['responsavel']),
          esc(r['consultor_id']),
        ].join(';'));
      }

      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Pré-visualização CSV'),
          content: SingleChildScrollView(child: Text(buffer.toString(), style: const TextStyle(fontSize: 12))),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar'))],
        ),
      );
    } finally {
      setState(() => _loadingCsv = false);
      _carregarResumo();
    }
  }

  void _copiarLink() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copiado para a área de transferência.')));
  }

  Widget _plainHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: redLight, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.file_download_outlined, color: red),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Exportar Dados', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16.5)),
            SizedBox(height: 4),
            Text('Exporte seus clientes para planilhas.', style: TextStyle(fontSize: 13, color: Color(0x99000000))),
          ]),
        ),
      ],
    );
  }

  BoxDecoration _cardDeco() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: const [BoxShadow(color: shadow, blurRadius: 8, offset: Offset(0, 2))],
      );

  // Card “Exportar para CSV”
  Widget _exportCard() {
    return Container(
      decoration: _cardDeco(),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: redLight, borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.assignment_outlined, color: red),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Exportar para CSV', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                SizedBox(height: 4),
                Text(
                  'Baixe seus dados em formato CSV para abrir no Excel,\nGoogle Sheets ou integrar com seu CRM.',
                  style: TextStyle(fontSize: 13, height: 1.25, color: Color(0x99000000)),
                ),
              ]),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            SizedBox(
              height: 44,
              width: 178,
              child: Material(
                color: red,
                borderRadius: BorderRadius.circular(26),
                child: InkWell(
                  borderRadius: BorderRadius.circular(26),
                  onTap: _loadingCsv ? null : _baixarCSV,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.download, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(_loadingCsv ? 'Gerando...' : 'Baixar CSV',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: _copiarLink,
                  icon: const Icon(Icons.copy_all_rounded, size: 18, color: Color(0xDD000000)),
                  label: const Text('Copiar', style: TextStyle(color: Color(0xE6000000), fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0x1F000000)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ]),
    );
  }

  Widget _resumoCard() {
    Widget metricLeft() {
      return Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: redLight, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.groups_2_outlined, color: red),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_qtdClientes == null ? '--' : '${_qtdClientes!}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              const Text('Clientes', style: TextStyle(fontSize: 12.5, color: Color(0x99000000))),
            ],
          ),
        ],
      );
    }

    Widget metricRight() {
      return Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: redLight, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.description_outlined, color: red),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('CSV', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              SizedBox(height: 2),
              Text('Formato', style: TextStyle(fontSize: 12.5, color: Color(0x99000000))),
            ],
          ),
        ],
      );
    }

    return Container(
      decoration: _cardDeco(),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          children: const [
            Icon(Icons.insert_drive_file_outlined, color: red),
            SizedBox(width: 8),
            Text('Resumo da Exportação', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 88,
          child: Row(
            children: [
              Expanded(child: metricLeft()),
              const SizedBox(width: 12),
              Expanded(child: metricRight()),
            ],
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final contentWidth = size.width < kCanvas + (kPadH * 2) ? size.width - (kPadH * 2) : kCanvas;

    return Container(
      color: bg,
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints.tightFor(width: contentWidth),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(kPadH, 10, kPadH, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _plainHeader(),
                  const SizedBox(height: kGapHeaderToCard),
                  _exportCard(),
                  const SizedBox(height: kGapCards),
                  _resumoCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
