import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Cliente {
  final dynamic id;
  final String? nome;
  final String? telefone;
  Cliente({required this.id, this.nome, this.telefone});
}

class TransferirLeadDialog extends StatefulWidget {
  final Cliente lead;
  final String consultorAtualNome;
  final Future<void> Function(String consultorUid) onConfirmar;

  const TransferirLeadDialog({
    super.key,
    required this.lead,
    required this.consultorAtualNome,
    required this.onConfirmar,
  });

  @override
  State<TransferirLeadDialog> createState() => _TransferirLeadDialogState();
}

class _TransferirLeadDialogState extends State<TransferirLeadDialog> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _sb = Supabase.instance.client;

  bool _loading = true;
  bool _sending = false;
  String? _erro;
  List<Map<String, dynamic>> _consultores = [];
  String? _selecionado;

  static const branco = Color(0xFFFFFFFF);
  static const texto = Color(0xFF231F20);
  static const vermelho = Color(0xFFEA3124);
  static const borda = Color(0xFFDFDFDF);

  static const double kMaxWidth = 520;
  static const double kMinBodyHeight = 220;
  static const EdgeInsets kInsetPadding = EdgeInsets.symmetric(horizontal: 28, vertical: 24);

  @override
  void initState() {
    super.initState();
    _carregarConsultores();
  }

  Future<void> _carregarConsultores() async {
    try {
      final rows = await _sb.from('consultores').select('uid, nome').eq('ativo', true).order('nome');
      setState(() {
        _consultores = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _erro = 'Erro ao carregar consultores';
        _loading = false;
      });
    }
  }

  Future<void> _confirmar() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = _selecionado;
    if (uid == null) return;

    setState(() => _sending = true);
    try {
      await widget.onConfirmar(uid);
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: kInsetPadding,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kMaxWidth),
          child: Material(
            color: branco,
            elevation: 6,
            shadowColor: Colors.black26,
            borderRadius: BorderRadius.circular(14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.swap_horiz_rounded, color: vermelho),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text('Transferir Lead',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: texto)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: texto),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    AnimatedSize(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: kMinBodyHeight),
                        child: _buildBody(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_erro != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Text(_erro!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: _carregarConsultores, child: const Text('Tentar novamente')),
          ],
        ),
      );
    }
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
            const Text('Lead Selecionado', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: texto)),
            const SizedBox(height: 6),

            Container(
              decoration: BoxDecoration(
                border: Border.all(color: borda),
                borderRadius: BorderRadius.circular(10),
                color: branco,
              ),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.lead.nome ?? '-',
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: texto)),
                  const SizedBox(height: 4),
                  if ((widget.lead.telefone ?? '').isNotEmpty)
                    Text(widget.lead.telefone!, style: const TextStyle(fontSize: 13.5, color: texto)),
                  const SizedBox(height: 4),
                  Text('Consultor atual: ${widget.consultorAtualNome}', style: const TextStyle(fontSize: 13, color: texto)),
                ],
              ),
            ),

            const SizedBox(height: 14),
            const Text('Transferir para', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: texto)),
            const SizedBox(height: 6),

            DropdownButtonFormField<String>(
              value: _selecionado,
              isExpanded: true,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: borda)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: borda)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: vermelho)),
              ),
              hint: const Text('Selecione o consultor'),
              items: _consultores
                  .map((c) => DropdownMenuItem<String>(
                        value: c['uid'] as String,
                        child: Text(c['nome'] as String),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selecionado = v),
              validator: (v) => v == null ? 'Selecione um consultor' : null,
            ),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                style: ElevatedButton.styleFrom(
                  backgroundColor: vermelho,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _sending ? null : _confirmar,
                label: _sending
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Confirmar Transferência'),
              ),
            ),
        ],
      ),
    );
  }
}
