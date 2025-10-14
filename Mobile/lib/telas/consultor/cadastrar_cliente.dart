import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
    _clienteService.initialize();
  }

  @override
  void dispose() {
    _clienteService.dispose();
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

  Future<String> _buscarNomeDoConsultorNoFirestore(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('consultores')
          .doc(uid)
          .get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['nome'] != null && (data['nome'] as String).trim().isNotEmpty) {
          return data['nome'] as String;
        }
      }
    } catch (e) {
      print('Erro ao buscar nome do consultor no Firestore: $e');
    }
    return '';
  }

  Future<void> _salvarCliente() async {
    if (_formKey.currentState?.validate() != true) return;

    setState(() => _isLoading = true);

    try {
      final dataHora = DateFormat('dd/MM/yyyy HH:mm')
          .parse('${_dataVisitaCtrl.text} ${_horaVisitaCtrl.text}');
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuário não autenticado.')),
        );
        return;
      }

      String consultorNome = await _buscarNomeDoConsultorNoFirestore(user.uid);

      if (consultorNome.trim().isEmpty) {
        consultorNome = user.displayName ?? '';
      }

      if (consultorNome.trim().isEmpty) {
        consultorNome = 'Consultor Desconhecido';
      }

      final cliente = Cliente(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        nomeCliente: _nomeClienteCtrl.text.trim(),
        telefone: _telefoneCtrl.text.trim(),
        estabelecimento: _nomeEstabelecimentoCtrl.text.trim(),
        estado: _estadoCtrl.text.trim(),
        cidade: _cidadeCtrl.text.trim(),
        endereco: _enderecoCtrl.text.trim(),
        bairro: _bairroCtrl.text.trim().isEmpty ? null : _bairroCtrl.text.trim(),
        cep: _cepCtrl.text.trim().isEmpty ? null : _cepCtrl.text.trim(),
        dataVisita: dataHora,
        observacoes: _observacoesCtrl.text.trim().isEmpty
            ? null
            : _observacoesCtrl.text.trim(),
        consultorResponsavel: consultorNome,
        consultorUid: user.uid,
      );

      await _clienteService.saveCliente(cliente);

      if (mounted) {
        _limparCampos();
        widget.onClienteCadastrado?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Cliente cadastrado com sucesso!'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e, st) {
      print('Erro ao salvar cliente: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao cadastrar cliente: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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

  Future<void> _selecionarData() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      locale: const Locale('pt', 'BR'),
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Colors.white,
              surface: Theme.of(context).colorScheme.surface,
              onSurface: Theme.of(context).colorScheme.onSurface,
            ),
            dialogBackgroundColor: Theme.of(context).colorScheme.surface,
          ),
          child: child!,
        );
      },
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Colors.white,
              surface: Theme.of(context).colorScheme.surface,
              onSurface: Theme.of(context).colorScheme.onSurface,
            ),
            dialogBackgroundColor: Theme.of(context).colorScheme.surface,
          ),
          child: Localizations.override(
            context: context,
            locale: const Locale('pt', 'BR'),
            child: child!,
          ),
        );
      },
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

  String? _validarCampoOpcional(String? v) {
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
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.error,
          width: 2,
        ),
      ),
      suffixIcon: suffixIcon,
      labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
      hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6),
          ),
    );
  }

  Widget _buildHeader() {
    return Padding(
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
              Icons.person_add_rounded,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cadastrar Cliente',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Preencha os dados do cliente',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          _limparCampos();
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _buildHeader(),
            ),

            SliverToBoxAdapter(
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSectionTitle(
                          'Dados Obrigatórios',
                          subtitle: 'Campos marcados com * são obrigatórios',
                        ),

                        TextFormField(
                          controller: _nomeClienteCtrl,
                          decoration: _obterDecoracaoCampo(
                            'Nome do Cliente',
                            hint: 'Digite o nome completo do cliente',
                          ),
                          validator: (v) =>
                              _validarCampoObrigatorio(v, field: 'Nome do Cliente'),
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _telefoneCtrl,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [_telefoneFormatter],
                          decoration: _obterDecoracaoCampo(
                            'Telefone',
                            hint: '(00) 00000-0000',
                          ),
                          validator: (v) =>
                              _validarCampoObrigatorio(v, field: 'Telefone'),
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _nomeEstabelecimentoCtrl,
                          decoration: _obterDecoracaoCampo(
                            'Nome do Estabelecimento',
                            hint: 'Digite o nome do estabelecimento',
                          ),
                          validator: (v) => _validarCampoObrigatorio(
                              v, field: 'Nome do Estabelecimento'),
                        ),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _estadoCtrl,
                                decoration: _obterDecoracaoCampo(
                                  'Estado',
                                  hint: 'UF',
                                ),
                                validator: (v) =>
                                    _validarCampoObrigatorio(v, field: 'Estado'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _cidadeCtrl,
                                decoration: _obterDecoracaoCampo(
                                  'Cidade',
                                  hint: 'Nome da cidade',
                                ),
                                validator: (v) =>
                                    _validarCampoObrigatorio(v, field: 'Cidade'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _enderecoCtrl,
                          decoration: _obterDecoracaoCampo(
                            'Endereço',
                            hint: 'Digite o endereço completo',
                          ),
                          validator: (v) =>
                              _validarCampoObrigatorio(v, field: 'Endereço'),
                        ),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _bairroCtrl,
                                decoration: _obterDecoracaoCampo(
                                  'Bairro',
                                  hint: 'Bairro',
                                  isObrigatorio: false, 
                                ),
                                validator: _validarCampoOpcional, 
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _cepCtrl,
                                keyboardType: TextInputType.number,
                                inputFormatters: [_cepFormatter],
                                decoration: _obterDecoracaoCampo(
                                  'CEP',
                                  hint: '00000-000',
                                  isObrigatorio: false, 
                                ),
                                validator: _validarCampoOpcional, 
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _dataVisitaCtrl,
                                readOnly: true,
                                decoration: _obterDecoracaoCampo(
                                  'Data da Visita',
                                  hint: 'dd/MM/yyyy',
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      Icons.calendar_today_outlined,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    onPressed: _selecionarData,
                                  ),
                                ),
                                validator: (v) =>
                                    _validarCampoObrigatorio(v, field: 'Data da Visita'),
                                onTap: _selecionarData,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _horaVisitaCtrl,
                                readOnly: true,
                                decoration: _obterDecoracaoCampo(
                                  'Hora da Visita',
                                  hint: 'HH:mm',
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      Icons.access_time_rounded,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    onPressed: _selecionarHora,
                                  ),
                                ),
                                validator: (v) =>
                                    _validarCampoObrigatorio(v, field: 'Hora da Visita'),
                                onTap: _selecionarHora,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        _buildSectionTitle(
                          'Dados Opcionais',
                          subtitle: 'Preencha conforme necessário',
                        ),

                        TextFormField(
                          controller: _observacoesCtrl,
                          maxLines: 4,
                          decoration: _obterDecoracaoCampo(
                            'Observações',
                            hint: 'Digite observações sobre a visita...',
                            isObrigatorio: false,
                          ),
                          validator: _validarCampoOpcional,
                        ),

                        const SizedBox(height: 24),

                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  side: BorderSide(
                                    color: Theme.of(context).colorScheme.outline,
                                  ),
                                ),
                                onPressed: _limparCampos,
                                child: Text(
                                  'Limpar',
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: _isLoading ? null : _salvarCliente,
                                child: _isLoading
                                    ? SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Theme.of(context).colorScheme.onPrimary,
                                        ),
                                      )
                                    : Text(
                                        'Cadastrar',
                                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                              color: Theme.of(context).colorScheme.onPrimary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
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