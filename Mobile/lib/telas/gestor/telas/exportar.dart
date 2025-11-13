import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
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

  String get _gestorId => sb.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _carregarResumo();
  }

  Future<List<String>> _uidsConsultoresDoMeuTime() async {
    final rows = await sb
        .from('consultores')
        .select('uid')
        .eq('gestor_id', _gestorId)
        .eq('ativo', true);
    return (rows as List)
        .map((r) => r['uid'] as String?)
        .whereType<String>()
        .toList();
  }

  Future<List<Map<String, dynamic>>> _baseClientesSelect() async {
    final consUids = await _uidsConsultoresDoMeuTime();
    if (consUids.isEmpty) return <Map<String, dynamic>>[];

    final rows = await sb
        .from('clientes')
        .select('id,nome,telefone,observacoes,consultor_uid_t')
        .inFilter('consultor_uid_t', consUids)
        .order('nome', ascending: true);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> _carregarResumo() async {
    try {
      final rows = await _baseClientesSelect();
      if (!mounted) return;
      setState(() => _qtdClientes = rows.length);
    } catch (_) {
      if (!mounted) return;
      setState(() => _qtdClientes = null);
    }
  }

  String _montarCsvClientes(List<Map<String, dynamic>> rows) {
    final buffer = StringBuffer();
    const header = 'nome;celular;observacoes';
    buffer.writeln(header);

    String esc(dynamic v) {
      final s = (v ?? '').toString().replaceAll('\n', ' ').replaceAll(';', ',');
      return '"$s"';
    }

    for (final r in rows) {
      buffer.writeln([
        esc(r['nome']),
        esc(r['telefone']),
        esc(r['observacoes']),
      ].join(';'));
    }
    return buffer.toString();
  }

  Future<File> _criarArquivoTemp(String csv, String filename) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$filename');
    await file.writeAsString(csv, encoding: utf8);
    return file;
  }

  Future<void> _compartilharCSVAgora() async {
    if (!mounted || _loadingCsv) return;
    setState(() => _loadingCsv = true);
    try {
      final rows = await _baseClientesSelect();
      final csv = _montarCsvClientes(rows);
      if (mounted) setState(() => _qtdClientes = rows.length);

      if (kIsWeb) {
        await Clipboard.setData(ClipboardData(text: csv));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV copiado (Web). Use Ctrl+V para colar.')),
        );
      } else {
        final file = await _criarArquivoTemp(csv, 'clientes_time.csv');
        await Share.shareXFiles([XFile(file.path)], text: 'Clientes do time (CSV)');
      }
    } finally {
      if (mounted) setState(() => _loadingCsv = false);
    }
  }

  Future<void> _copiarCSVParaClipboard() async {
    final rows = await _baseClientesSelect();
    final csv = _montarCsvClientes(rows);
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSV copiado para a área de transferência.')),
    );
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
              Text('Compartilhe seus clientes em CSV para Excel/Sheets/CRM.', style: TextStyle(fontSize: 13, color: Color(0x99000000))),
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

  Widget _exportCardButtons(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final narrow = c.maxWidth < 320;

        final shareBtn = Expanded(
          flex: 5,
          child: SizedBox(
            height: 44,
            child: Material(
              color: red,
              borderRadius: BorderRadius.circular(26),
              child: InkWell(
                borderRadius: BorderRadius.circular(26),
                onTap: _loadingCsv ? null : _compartilharCSVAgora,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.ios_share_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _loadingCsv ? 'Gerando...' : 'Compartilhar CSV',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        final copyBtn = Expanded(
          flex: 3,
          child: SizedBox(
            height: 44,
            child: OutlinedButton.icon(
              onPressed: _copiarCSVParaClipboard,
              icon: const Icon(Icons.copy_all_rounded, size: 18, color: Color(0xDD000000)),
              label: const Flexible(
                child: Text('Copiar',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Color(0xE6000000), fontWeight: FontWeight.w700)),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0x1F000000)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
          ),
        );

        if (!narrow) {
          return Row(
            children: [
              shareBtn,
              const SizedBox(width: 8),
              copyBtn,
            ],
          );
        }

        return Column(
          children: [
            Row(children: [shareBtn]),
            const SizedBox(height: 8),
            Row(children: [copyBtn]),
          ],
        );
      },
    );
  }

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
                Text('Compartilhar CSV', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                SizedBox(height: 4),
                Text(
                  'Gera o CSV e abre o compartilhamento (WhatsApp, Gmail, Drive, etc).',
                  style: TextStyle(fontSize: 13, height: 1.25, color: Color(0x99000000)),
                ),
              ]),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _exportCardButtons(context),
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
              Text(_qtdClientes == null ? '--' : '${_qtdClientes!}',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
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
