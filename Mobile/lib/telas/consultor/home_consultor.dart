import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:ademicon_app/models/cliente.dart';
import 'package:ademicon_app/services/cliente_service.dart';

class CadastrarCliente extends StatefulWidget {
  final Function()? onClienteCadastrado;
  const CadastrarCliente({super.key, this.onClienteCadastrado});

  @override
  State<CadastrarCliente> createState() => _CadastrarClienteState();
}

class _CadastrarClienteState extends State<CadastrarCliente> {
  final _formKey = GlobalKey<FormState>();
  final _client = Supabase.instance.client;

  final _nomeClienteCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  final _nomeEstabelecimentoCtrl = TextEditingController();
  final _estadoCtrl = TextEditingController();
  final _cidadeCtrl = TextEditingController();
  final _enderecoCtrl = TextEditingController();
  final _bairroCtrl = TextEditingController();
  final _cepCtrl = TextEditingController();
  final _dataVisitaCtrl = TextEditingController();
  final _horaVisitaCtrl = TextEditingController();
  final _observacoesCtrl = TextEditingController();

  final _telefoneFormatter = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {"#": RegExp(r'\d')},
    type: MaskAutoCompletionType.lazy,
  );
  final _cepFormatter = MaskTextInputFormatter(
    mask: '#####-###',
    filter: {"#": RegExp(r'\d')},
    type: MaskAutoCompletionType.lazy,
  );

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _dataVisitaCtrl.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
    _horaVisitaCtrl.text = DateFormat('HH:mm').format(DateTime.now());
  }

  @override
  void dispose() {
    _nomeClienteCtrl.dispose();
    _telefoneCtrl.dispose();
    _nomeEstabelecimentoCtrl.dispose();
    _estadoCtrl.dispose();
    _cidadeCtrl.dispose();
    _enderecoCtrl.dispose();
    _bairroCtrl.dispose();
    _cepCtrl.dispose();
    _dataVisitaCtrl.dispose();
    _horaVisitaCtrl.dispose();
    _observacoesCtrl.dispose();
    super.dispose();
  }

  Future<void> _selecionarData() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) {
      _dataVisitaCtrl.text = DateFormat('dd/MM/yyyy').format(picked);
    }
  }

  Future<void> _selecionarHora() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      _horaVisitaCtrl.text = picked.format(context);
    }
  }

  String? _validarCampoObrigatorio(String? v, {String field = 'Campo'}) {
    if (v == null || v.trim().isEmpty) return '$field é obrigatório';
    return null;
  }

  InputDecoration _obterDecoracaoCampo(
    String label, {
    String? hint,
    Widget? suffixIcon,
    bool isObrigatorio = true,
  }) {
    return InputDecoration(
      labelText: '$label${isObrigatorio ? ' *' : ''}',
      hintText: hint,
      filled: true,
      fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      suffixIcon: suffixIcon,
    );
  }

  Future<void> _salvarCliente() async {
    if (_formKey.currentState?.validate() != true) return;
    if (mounted) setState(() => _isLoading = true);

    try {
      final dataStr = _dataVisitaCtrl.text.trim();
      final horaStr = _horaVisitaCtrl.text.trim();

      late DateTime dataHora;
      try {
        final h = DateFormat('HH:mm').parse(horaStr);
        final horaPadrao = DateFormat('HH:mm').format(h);
        dataHora = DateFormat('dd/MM/yyyy HH:mm').parse('$dataStr $horaPadrao');
      } on FormatException {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data ou hora inválida. Use o formato correto.')),
        );
        return;
      }

      final session = _client.auth.currentSession;
      if (session == null || session.user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro: sessão expirada. Faça login novamente.')),
        );
        return;
      }

      final userId = session.user!.id;
      final consultorNomeLocal = session.user!.email ?? 'Desconhecido';

      final cliente = Cliente(
        id: const Uuid().v4(),
        nomeCliente: _nomeClienteCtrl.text.trim(),
        telefone: _telefoneCtrl.text.replaceAll(RegExp(r'[^\d]'), ''),
        estabelecimento: _nomeEstabelecimentoCtrl.text.trim(),
        estado: _estadoCtrl.text.trim(),
        cidade: _cidadeCtrl.text.trim(),
        endereco: _enderecoCtrl.text.trim(),
        bairro: _bairroCtrl.text.trim().isNotEmpty ? _bairroCtrl.text.trim() : null,
        cep: _cepCtrl.text.replaceAll('-', ''),
        dataVisita: dataHora,
        observacoes: _observacoesCtrl.text.trim().isNotEmpty ? _observacoesCtrl.text.trim() : null,
        consultorResponsavel: consultorNomeLocal,
        consultorUid: userId,
        horaVisita: horaStr,
      );

      final persistedNow = await ClienteService.instance.saveCliente(cliente);

      if (!mounted) return;
      _limparCampos();
      widget.onClienteCadastrado?.call();

      if (persistedNow) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cliente enviado ao servidor com sucesso.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cliente registrado localmente. Sincronizará automaticamente quando online.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _limparCampos() {
    _formKey.currentState?.reset();
    _nomeClienteCtrl.clear();
    _telefoneCtrl.clear();
    _nomeEstabelecimentoCtrl.clear();
    _estadoCtrl.clear();
    _cidadeCtrl.clear();
    _enderecoCtrl.clear();
    _bairroCtrl.clear();
    _cepCtrl.clear();
    _observacoesCtrl.clear();
    _dataVisitaCtrl.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
    _horaVisitaCtrl.text = DateFormat('HH:mm').format(DateTime.now());
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => _limparCampos(),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.add_business_rounded,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Cadastrar Cliente', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                          Text('Preencha os dados do cliente', style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Card(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Dados Obrigatórios', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        TextFormField(controller: _nomeClienteCtrl, decoration: _obterDecoracaoCampo('Nome do Cliente', hint: 'Nome completo'), validator: (v) => _validarCampoObrigatorio(v, field: 'Nome do cliente')),
                        const SizedBox(height: 12),
                        TextFormField(controller: _telefoneCtrl, keyboardType: TextInputType.phone, inputFormatters: [_telefoneFormatter], decoration: _obterDecoracaoCampo('Telefone', hint: '(00) 00000-0000'), validator: (v) => _validarCampoObrigatorio(v, field: 'Telefone')),
                        const SizedBox(height: 12),
                        TextFormField(controller: _nomeEstabelecimentoCtrl, decoration: _obterDecoracaoCampo('Estabelecimento', hint: 'Nome do ponto de venda'), validator: (v) => _validarCampoObrigatorio(v, field: 'Estabelecimento')),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: TextFormField(controller: _estadoCtrl, textCapitalization: TextCapitalization.characters, decoration: _obterDecoracaoCampo('Estado', hint: 'PR'), validator: (v) => _validarCampoObrigatorio(v, field: 'Estado'))),
                            const SizedBox(width: 12),
                            Expanded(child: TextFormField(controller: _cidadeCtrl, decoration: _obterDecoracaoCampo('Cidade', hint: 'Londrina'), validator: (v) => _validarCampoObrigatorio(v, field: 'Cidade'))),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(controller: _enderecoCtrl, decoration: _obterDecoracaoCampo('Endereço', hint: 'Av. ex: 123'), validator: (v) => _validarCampoObrigatorio(v, field: 'Endereço')),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(flex: 3, child: TextFormField(controller: _bairroCtrl, decoration: _obterDecoracaoCampo('Bairro', hint: 'Jardim x', isObrigatorio: false))),
                            const SizedBox(width: 12),
                            Expanded(flex: 2, child: TextFormField(controller: _cepCtrl, keyboardType: TextInputType.number, inputFormatters: [_cepFormatter], decoration: _obterDecoracaoCampo('CEP', hint: '00000-000', isObrigatorio: false))),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _dataVisitaCtrl,
                                readOnly: true,
                                decoration: _obterDecoracaoCampo('Data da Visita', hint: 'dd/mm/aaaa', suffixIcon: IconButton(icon: const Icon(Icons.calendar_today_outlined), onPressed: _selecionarData)),
                                onTap: _selecionarData,
                                validator: (v) => _validarCampoObrigatorio(v, field: 'Data da visita'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _horaVisitaCtrl,
                                readOnly: true,
                                decoration: _obterDecoracaoCampo('Hora', hint: '00:00', suffixIcon: IconButton(icon: const Icon(Icons.access_time), onPressed: _selecionarHora)),
                                onTap: _selecionarHora,
                                validator: (v) => _validarCampoObrigatorio(v, field: 'Hora'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text('Observações', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _observacoesCtrl,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Ex: cliente solicitou entrega no horário da tarde',
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(child: OutlinedButton(onPressed: _limparCampos, child: const Text('Limpar'))),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: _isLoading ? null : _salvarCliente,
                                child: _isLoading
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Text('Cadastrar'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
