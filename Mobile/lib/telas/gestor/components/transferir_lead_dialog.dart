import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TLCliente {
  final dynamic id;
  final String? nome;
  final String? telefone;
  const TLCliente({required this.id, this.nome, this.telefone});
}

class TLTransferirLeadDialog extends StatefulWidget {
  final TLCliente lead;
  final String consultorAtualNome;
  final Future<void> Function(String consultorUid) onConfirmar;

  const TLTransferirLeadDialog({
    super.key,
    required this.lead,
    required this.consultorAtualNome,
    required this.onConfirmar,
  });

  @override
  State<TLTransferirLeadDialog> createState() => _TLTransferirLeadDialogState();
}

class _TLTransferirLeadDialogState extends State<TLTransferirLeadDialog> {
  final _formKey = GlobalKey<FormState>();
  final _sb = Supabase.instance.client;

  bool _loading = true;
  bool _sending = false;
  String? _erro;
  List<Map<String, dynamic>> _consultores = [];
  String? _selecionado;

  static const Color branco = Color(0xFFFFFFFF);
  static const Color texto = Color(0xFF231F20);
  static const Color cinza = Color(0xFF9A9AA0);
  static const Color cinzaClaro = Color(0xFF6B6B6E);
  static const Color borda = Color(0xFFE8E8E8);
  static const Color vermelho = Color(0xFFEA3124);
  static const Color laranja = Color(0xFFF15A24);

  @override
  void initState() {
    super.initState();
    _loadConsultores();
  }

  Future<void> _loadConsultores() async {
    try {
      final rows = await _sb
          .from('consultores')
          .select('uid, nome')
          .eq('ativo', true)
          .order('nome');
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
    if (uid == null || uid.isEmpty) {
      setState(() => _erro = 'Selecione o consultor.');
      return;
    }
    setState(() {
      _erro = null;
      _sending = true;
    });
    try {
      await widget.onConfirmar(uid);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _erro = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Material(
          color: branco,
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0x1AEA3124),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.sync_alt_rounded, color: vermelho, size: 16),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Transferir Lead',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: texto),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: texto),
                      onPressed: () => Navigator.of(context).pop(false),
                      tooltip: 'Fechar',
                    )
                  ],
                ),
              ),
              const Divider(height: 1),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: _loading
                    ? const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Lead Selecionado', style: TextStyle(fontSize: 12.5, color: Color(0xFF6B6B6E))),
                          const SizedBox(height: 6),
                          Container(
                            decoration: BoxDecoration(
                              color: branco,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: borda, width: 1),
                            ),
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.lead.nome ?? '-',
                                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: texto),
                                ),
                                if ((widget.lead.telefone ?? '').isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(widget.lead.telefone!, style: const TextStyle(fontSize: 13.5, color: texto)),
                                ],
                                const SizedBox(height: 4),
                                Text(
                                  'Consultor atual: ${widget.consultorAtualNome}',
                                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B6B6E)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text('Transferir para',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: texto)),
                          const SizedBox(height: 6),
                          Form(
                            key: _formKey,
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: _selecionado,
                              items: _consultores
                                  .map((c) => DropdownMenuItem<String>(
                                        value: c['uid'] as String,
                                        child: Text(c['nome'] as String),
                                      ))
                                  .toList(),
                              onChanged: (v) => setState(() => _selecionado = v),
                              decoration: InputDecoration(
                                hintText: 'Selecione o consultor',
                                hintStyle: const TextStyle(color: cinza),
                                isDense: true,
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: borda, width: 1),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: borda, width: 1),
                                ),
                                focusedBorder: const OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(10)),
                                  borderSide: BorderSide(color: vermelho, width: 1.2),
                                ),
                              ),
                              validator: (v) => v == null ? 'Selecione um consultor' : null,
                            ),
                          ),
                          if (_erro != null) ...[
                            const SizedBox(height: 8),
                            Text(_erro!, style: const TextStyle(color: Colors.red)),
                          ],
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 44,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: (_selecionado != null && !_sending)
                                    ? const LinearGradient(
                                        colors: [laranja, vermelho],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      )
                                    : null,
                                color: (_selecionado != null && !_sending)
                                    ? null
                                    : const Color(0xFFEEC5C2),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x14000000),
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  )
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: (_selecionado == null || _sending) ? null : _confirmar,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  disabledBackgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 0,
                                ),
                                child: _sending
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: const [
                                          Icon(Icons.sync_alt_rounded, size: 18, color: Colors.white),
                                          SizedBox(width: 8),
                                          Text('Confirmar Transferência',
                                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
