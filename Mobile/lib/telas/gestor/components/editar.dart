import 'package:flutter/material.dart';

class EditarLeadSheet extends StatefulWidget {
  final String nome;
  final String telefone;
  final String endereco;
  final String bairro;
  final int diasPAP;
  final String observacoes;

  const EditarLeadSheet({
    super.key,
    required this.nome,
    required this.telefone,
    required this.endereco,
    required this.bairro,
    required this.diasPAP,
    required this.observacoes,
  });

  @override
  State<EditarLeadSheet> createState() => _EditarLeadSheetState();
}

class _EditarLeadSheetState extends State<EditarLeadSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nomeCtrl;
  late final TextEditingController _telCtrl;
  late final TextEditingController _endCtrl;
  late final TextEditingController _bairroCtrl;
  late final TextEditingController _diasCtrl;
  late final TextEditingController _obsCtrl;

  @override
  void initState() {
    super.initState();
    _nomeCtrl = TextEditingController(text: widget.nome);
    _telCtrl = TextEditingController(text: widget.telefone);
    _endCtrl = TextEditingController(text: widget.endereco);
    _bairroCtrl = TextEditingController(text: widget.bairro);
    _diasCtrl = TextEditingController(text: widget.diasPAP.toString());
    _obsCtrl = TextEditingController(text: widget.observacoes);
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _telCtrl.dispose();
    _endCtrl.dispose();
    _bairroCtrl.dispose();
    _diasCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  void _salvar() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop({
      'nome': _nomeCtrl.text.trim(),
      'telefone': _telCtrl.text.trim(),
      'endereco': _endCtrl.text.trim(),
      'bairro': _bairroCtrl.text.trim(),
      'diasPAP': int.tryParse(_diasCtrl.text.trim()) ?? widget.diasPAP,
      'observacoes': _obsCtrl.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    const branco = Color(0xFFFFFFFF);
    const vermelho = Color(0xFFEA3124);

    const double menuHeight = 72; 
    final media = MediaQuery.of(context);
    final totalH = media.size.height;
    final double sheetAltura = totalH * 0.85; 

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: sheetAltura,
        width: double.infinity,
        decoration: const BoxDecoration(
          color: branco,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          bottom: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Editar Lead',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Fechar',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _campo(
                            label: 'Nome',
                            controller: _nomeCtrl,
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
                          ),
                          _campo(
                            label: 'Telefone',
                            controller: _telCtrl,
                            keyboardType: TextInputType.phone,
                          ),
                          _campo(
                            label: 'Endereço',
                            controller: _endCtrl,
                          ),
                          _campo(
                            label: 'Bairro',
                            controller: _bairroCtrl,
                          ),
                          _campo(
                            label: 'Dias para Retorno PAP',
                            controller: _diasCtrl,
                            keyboardType: TextInputType.number,
                            helper: 'Parâmetro maleável - máximo 90 dias',
                            validator: (v) {
                              final n = int.tryParse(v ?? '');
                              if (n == null) return 'Informe um número';
                              if (n < 0) return 'Valor inválido';
                              if (n > 90) return 'Máximo 90 dias';
                              return null;
                            },
                          ),
                          _campoMultilinha(
                            label: 'Observações',
                            controller: _obsCtrl,
                            minLines: 3,
                            maxLines: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
                  child: SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save_outlined, size: 18),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: vermelho,
                        foregroundColor: branco,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _salvar,
                      label: const Text('Salvar Alterações'),
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

  Widget _campo({
    required String label,
    required TextEditingController controller,
    String? helper,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            validator: validator,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          if (helper != null) ...[
            const SizedBox(height: 6),
            Text(helper, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ],
      ),
    );
  }

  Widget _campoMultilinha({
    required String label,
    required TextEditingController controller,
    int minLines = 3,
    int maxLines = 6,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            minLines: minLines,
            maxLines: maxLines,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
