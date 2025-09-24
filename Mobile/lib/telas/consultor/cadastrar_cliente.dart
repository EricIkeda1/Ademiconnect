import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CadastrarCliente extends StatefulWidget {
  const CadastrarCliente({super.key});

  @override
  State<CadastrarCliente> createState() => _CadastrarClienteState();
}

class _CadastrarClienteState extends State<CadastrarCliente> {
  final _formKey = GlobalKey<FormState>();

  final _nomeEstabelecimentoCtrl = TextEditingController();
  final _enderecoCtrl = TextEditingController();
  final _dataVisitaCtrl = TextEditingController();
  final _nomeClienteCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  final _observacoesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _dataVisitaCtrl.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
  }

  @override
  void dispose() {
    _nomeEstabelecimentoCtrl.dispose();
    _enderecoCtrl.dispose();
    _dataVisitaCtrl.dispose();
    _nomeClienteCtrl.dispose();
    _telefoneCtrl.dispose();
    _observacoesCtrl.dispose();
    super.dispose();
  }

  void _salvar() {
    if (_formKey.currentState?.validate() != true) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cliente cadastrado com sucesso!')),
    );

    _formKey.currentState?.reset();
    _nomeEstabelecimentoCtrl.clear();
    _enderecoCtrl.clear();
    _nomeClienteCtrl.clear();
    _telefoneCtrl.clear();
    _observacoesCtrl.clear();
    _dataVisitaCtrl.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      helpText: 'Selecione a data da visita',
      confirmText: 'Confirmar',
      cancelText: 'Cancelar',
    );
    if (picked != null) {
      _dataVisitaCtrl.text = DateFormat('dd/MM/yyyy').format(picked);
      setState(() {});
    }
  }

  String? _required(String? v, {String field = 'Campo'}) {
    if (v == null || v.trim().isEmpty) return '$field é obrigatório';
    return null;
  }

  String _maskTelefone(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    final b = StringBuffer();
    for (int i = 0; i < digits.length && i < 11; i++) {
      final c = digits[i];
      if (i == 0) b.write('(');
      if (i == 2) b.write(') ');
      if (i == 7) b.write('-');
      b.write(c);
    }
    return b.toString();
  }

  InputDecoration _dec(String label, {String? hint, Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF7F8FA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF9AA7FF)),
      ),
      suffixIcon: suffixIcon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        );
    final subtle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.black.withOpacity(0.6),
        );

    return _CardBase(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cadastrar Novo Cliente', style: titleStyle),
              const SizedBox(height: 4),
              Text('Preencha os dados do cliente para cadastro', style: subtle),

              const SizedBox(height: 16),

              Text('Dados Obrigatórios', style: titleStyle),
              const SizedBox(height: 8),

              TextFormField(
                controller: _nomeEstabelecimentoCtrl,
                decoration: _dec(
                  'Nome do Estabelecimento *',
                  hint: 'Digite o nome do estabelecimento',
                ),
                validator: (v) => _required(v, field: 'Nome do Estabelecimento'),
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _enderecoCtrl,
                decoration: _dec(
                  'Endereço *',
                  hint: 'Digite o endereço completo',
                ),
                validator: (v) => _required(v, field: 'Endereço'),
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _dataVisitaCtrl,
                readOnly: true,
                decoration: _dec(
                  'Data da Visita *',
                  hint: 'dd/mm/aaaa',
                  suffixIcon: IconButton(
                    tooltip: 'Selecionar data',
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined),
                  ),
                ),
                validator: (v) => _required(v, field: 'Data da Visita'),
                onTap: _pickDate,
              ),

              const SizedBox(height: 16),

              Text('Dados Opcionais', style: titleStyle),
              const SizedBox(height: 8),

              TextFormField(
                controller: _nomeClienteCtrl,
                decoration: _dec(
                  'Nome do Cliente',
                  hint: 'Digite o nome do cliente (opcional)',
                ),
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _telefoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: _dec(
                  'Telefone',
                  hint: '(00) 00000-0000',
                ),
                onChanged: (v) {
                  final masked = _maskTelefone(v);
                  if (masked != v) {
                    final sel = TextSelection.collapsed(offset: masked.length);
                    _telefoneCtrl.value = TextEditingValue(
                      text: masked,
                      selection: sel,
                    );
                  }
                },
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _observacoesCtrl,
                maxLines: 3,
                decoration: _dec(
                  'Observações',
                  hint: 'Digite observações sobre a visita (opcional)',
                ),
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _salvar,
                  child: const Text('Cadastrar Cliente'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardBase extends StatelessWidget {
  final Widget child;
  const _CardBase({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      color: Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: child,
    );
  }
}
