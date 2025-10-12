import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../../models/cliente.dart';
import '../../services/cliente_service.dart';

class CadastrarCliente extends StatefulWidget {
  final Function()? onClienteCadastrado;
  const CadastrarCliente({super.key, this.onClienteCadastrado});

  @override
  State<CadastrarCliente> createState() => _CadastrarClienteState();
}

class _CadastrarClienteState extends State<CadastrarCliente> {
  final _formKey = GlobalKey<FormState>();
  final _clienteService = ClienteService();

  final _nomeEstabelecimentoCtrl = TextEditingController();
  final _estadoCtrl = TextEditingController();
  final _cidadeCtrl = TextEditingController();
  final _enderecoCtrl = TextEditingController();
  final _dataVisitaCtrl = TextEditingController();
  final _horaVisitaCtrl = TextEditingController();
  final _nomeClienteCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  final _observacoesCtrl = TextEditingController();

  final _telefoneFormatter = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: { "#": RegExp(r'\d') },
    type: MaskAutoCompletionType.lazy,
  );

  @override
  void initState() {
    super.initState();
    _dataVisitaCtrl.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
    _horaVisitaCtrl.text = DateFormat('HH:mm').format(DateTime.now());
  }

  @override
  void dispose() {
    _nomeEstabelecimentoCtrl.dispose();
    _estadoCtrl.dispose();
    _cidadeCtrl.dispose();
    _enderecoCtrl.dispose();
    _dataVisitaCtrl.dispose();
    _horaVisitaCtrl.dispose();
    _nomeClienteCtrl.dispose();
    _telefoneCtrl.dispose();
    _observacoesCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvarCliente() async {
    if (_formKey.currentState?.validate() != true) return;

    try {
      final dataHora = DateFormat('dd/MM/yyyy HH:mm')
          .parse('${_dataVisitaCtrl.text} ${_horaVisitaCtrl.text}');

      final cliente = Cliente(
        estabelecimento: _nomeEstabelecimentoCtrl.text.trim(),
        estado: _estadoCtrl.text.trim(),
        cidade: _cidadeCtrl.text.trim(),
        endereco: _enderecoCtrl.text.trim(),
        dataVisita: dataHora,
        nomeCliente: _nomeClienteCtrl.text.trim().isEmpty
            ? null
            : _nomeClienteCtrl.text.trim(),
        telefone: _telefoneCtrl.text.trim().isEmpty
            ? null
            : _telefoneCtrl.text.trim(),
        observacoes: _observacoesCtrl.text.trim().isEmpty
            ? null
            : _observacoesCtrl.text.trim(),
        consultorResponsavel: "Consultor Teste",
      );

      await _clienteService.saveCliente(cliente);

      if (mounted) {
        _limparCampos();
        widget.onClienteCadastrado?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao cadastrar cliente: $e')),
        );
      }
    }
  }

  void _limparCampos() {
    _formKey.currentState?.reset();
    _nomeEstabelecimentoCtrl.clear();
    _estadoCtrl.clear();
    _cidadeCtrl.clear();
    _enderecoCtrl.clear();
    _nomeClienteCtrl.clear();
    _telefoneCtrl.clear();
    _observacoesCtrl.clear();
    _dataVisitaCtrl.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
    _horaVisitaCtrl.text = DateFormat('HH:mm').format(DateTime.now());
    setState(() {});
  }

  Future<void> _selecionarData() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      _dataVisitaCtrl.text = DateFormat('dd/MM/yyyy').format(picked);
      setState(() {});
    }
  }

  Future<void> _selecionarHora() async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: now,
    );
    if (picked != null) {
      _horaVisitaCtrl.text = picked.format(context);
      setState(() {});
    }
  }

  String? _validarCampoObrigatorio(String? v, {String field = 'Campo'}) {
    if (v == null || v.trim().isEmpty) return '$field é obrigatório';
    return null;
  }

  InputDecoration _obterDecoracaoCampo(String label,
      {String? hint, Widget? suffixIcon}) {
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
      child: SingleChildScrollView(
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
                decoration: _obterDecoracaoCampo(
                  'Nome do Estabelecimento *',
                  hint: 'Digite o nome do estabelecimento',
                ),
                validator: (v) =>
                    _validarCampoObrigatorio(v, field: 'Nome do Estabelecimento'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _estadoCtrl,
                decoration: _obterDecoracaoCampo(
                  'Estado *',
                  hint: 'Digite o estado (ex: SP, RJ...)',
                ),
                validator: (v) => _validarCampoObrigatorio(v, field: 'Estado'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _cidadeCtrl,
                decoration: _obterDecoracaoCampo(
                  'Cidade *',
                  hint: 'Digite a cidade',
                ),
                validator: (v) => _validarCampoObrigatorio(v, field: 'Cidade'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _enderecoCtrl,
                decoration: _obterDecoracaoCampo(
                  'Endereço *',
                  hint: 'Digite o endereço completo',
                ),
                validator: (v) => _validarCampoObrigatorio(v, field: 'Endereço'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _dataVisitaCtrl,
                readOnly: true,
                decoration: _obterDecoracaoCampo(
                  'Data da Visita *',
                  hint: 'dd/MM/yyyy',
                  suffixIcon: IconButton(
                    tooltip: 'Selecionar data',
                    onPressed: _selecionarData,
                    icon: const Icon(Icons.calendar_today_outlined),
                  ),
                ),
                validator: (v) =>
                    _validarCampoObrigatorio(v, field: 'Data da Visita'),
                onTap: _selecionarData,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _horaVisitaCtrl,
                readOnly: true,
                decoration: _obterDecoracaoCampo(
                  'Hora da Visita *',
                  hint: 'HH:mm',
                  suffixIcon: IconButton(
                    tooltip: 'Selecionar hora',
                    onPressed: _selecionarHora,
                    icon: const Icon(Icons.access_time),
                  ),
                ),
                validator: (v) =>
                    _validarCampoObrigatorio(v, field: 'Hora da Visita'),
                onTap: _selecionarHora,
              ),
              const SizedBox(height: 16),
              Text('Dados Opcionais', style: titleStyle),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nomeClienteCtrl,
                decoration: _obterDecoracaoCampo(
                  'Nome do Cliente',
                  hint: 'Digite o nome do cliente (opcional)',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _telefoneCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [_telefoneFormatter],
                decoration: _obterDecoracaoCampo(
                  'Telefone',
                  hint: '(00) 00000-0000',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _observacoesCtrl,
                maxLines: 3,
                decoration: _obterDecoracaoCampo(
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
                  onPressed: _salvarCliente,
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
