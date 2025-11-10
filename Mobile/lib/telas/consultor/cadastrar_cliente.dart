import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:ademicon_app/models/cliente.dart';
import 'package:ademicon_app/services/cliente_service.dart';
import 'package:ademicon_app/services/notification_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

const String kCorreiosBaseUrl = 'https://apihom.correios.com.br'; 
const String kCorreiosBearerToken = ''; 

const kDanger = Color(0xFFF00000);
const kDangerHover = Color(0xFFE31214);
const kDangerPressed = Color(0xFF7D1315);
const kInk = Color(0xFF231F20);
const kInk2 = Color(0xFF414042);
const kInkMuted = Color(0xFF939598);
const kDivider = Color(0xFFDCDCDC);

class EnderecoCep {
  final String? uf;
  final String? cidade;
  final String? bairro;
  final String? logradouro;
  final String? complemento;

  const EnderecoCep({this.uf, this.cidade, this.bairro, this.logradouro, this.complemento});
}

class ViaCepService {
  final http.Client _client;
  ViaCepService({http.Client? client}) : _client = client ?? http.Client();

  Future<EnderecoCep?> buscar(String cep8) async {
    final uri = Uri.parse('https://viacep.com.br/ws/$cep8/json/');
    final resp = await _client.get(uri);
    if (resp.statusCode != 200) return null;
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (data['erro'] == true) return null;
    return EnderecoCep(
      uf: (data['uf'] ?? '').toString().toUpperCase(),
      cidade: (data['localidade'] ?? '').toString(),
      bairro: (data['bairro'] ?? '').toString(),
      logradouro: (data['logradouro'] ?? '').toString(),
      complemento: (data['complemento'] ?? '').toString(),
    );
  }
}

class CorreiosCepService {
  final String baseUrl;
  final String bearerToken;
  final http.Client _client;

  CorreiosCepService({
    required this.baseUrl,
    required this.bearerToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Future<EnderecoCep?> buscar(String cep8) async {
    if (bearerToken.isEmpty) return null;
    final uri = Uri.parse('$baseUrl/cep/v1/enderecos/$cep8'); 
    final resp = await _client.get(
      uri,
      headers: {
        'Authorization': 'Bearer $bearerToken',
        'Accept': 'application/json',
      },
    );
    if (resp.statusCode == 401 || resp.statusCode == 403) return null;
    if (resp.statusCode != 200) return null;

    final data = jsonDecode(resp.body);
    final Map<String, dynamic> map;
    if (data is Map<String, dynamic>) {
      map = data;
    } else if (data is List && data.isNotEmpty && data.first is Map<String, dynamic>) {
      map = data.first as Map<String, dynamic>;
    } else {
      return null;
    }

    String? uf = _readString(map, ['uf', 'estado', 'siglaUf']);
    String? cidade = _readString(map, ['localidade', 'cidade', 'municipio', 'nomeMunicipio']);
    String? bairro = _readString(map, ['bairro', 'distrito']);
    String? logradouro = _readString(map, ['logradouro', 'endereco', 'nomeLogradouro']);
    String? complemento = _readString(map, ['complemento']);

    return EnderecoCep(
      uf: (uf ?? '').toUpperCase(),
      cidade: cidade,
      bairro: bairro,
      logradouro: logradouro,
      complemento: complemento,
    );
  }

  static String? _readString(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v is String && v.trim().isNotEmpty) return v;
    }
    return null;
  }
}

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

  final _bairroCtrl = TextEditingController();
  final _complementoCtrl = TextEditingController();

  String? _tipoLogradouro;
  final _nomeViaCtrl = TextEditingController();
  final _numeroCtrl = TextEditingController();
  final _cepCtrl = TextEditingController();

  String? _statusNegociacao;
  final _valorPropostaCtrl = TextEditingController();
  final _dataNegociacaoCtrl = TextEditingController();
  final _horaNegociacaoCtrl = TextEditingController();

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

  static const Map<String, String> _abbr = {
    'Avenida': 'Av.',
    'Rua': 'R.',
    'Alameda': 'Al.',
    'Travessa': 'Tv.',
    'Rodovia': 'Rod.',
    'Estrada': 'Est.',
    'Praça': 'Pç.',
    'Largo': 'Lg.',
    'Via': 'Via',
  };

  static const List<String> _tiposLogradouro = [
    'Rua','Avenida','Alameda','Travessa','Rodovia','Estrada','Praça','Via','Largo'
  ];

  final List<Map<String, String>> _statusOptions = const [
    {'label': 'Conexão',   'value': 'conexao'},
    {'label': 'Negociação','value': 'negociacao'},
    {'label': 'Fechada',   'value': 'fechada'},
  ];

  bool _isLoading = false;

  late final VoidCallback _cepListener;

  late final ViaCepService _viaCep;
  late final CorreiosCepService _correios;

  String _norm(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ');

  @override
  void initState() {
    super.initState();
    _viaCep = ViaCepService();
    _correios = CorreiosCepService(
      baseUrl: kCorreiosBaseUrl,
      bearerToken: kCorreiosBearerToken,
    );

    _dataVisitaCtrl.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
    _horaVisitaCtrl.text = DateFormat('HH:mm').format(DateTime.now());
    _dataNegociacaoCtrl.clear();
    _horaNegociacaoCtrl.clear();

    _cepListener = () {
      final raw = _cepCtrl.text.replaceAll(RegExp(r'[^\d]'), '');
      if (raw.length == 8) _buscarEnderecoComFallback(raw);
    };
    _cepCtrl.addListener(_cepListener);
  }

  @override
  void dispose() {
    _cepCtrl.removeListener(_cepListener);
    _nomeClienteCtrl.dispose();
    _telefoneCtrl.dispose();
    _nomeEstabelecimentoCtrl.dispose();
    _estadoCtrl.dispose();
    _cidadeCtrl.dispose();
    _bairroCtrl.dispose();
    _complementoCtrl.dispose();
    _nomeViaCtrl.dispose();
    _numeroCtrl.dispose();
    _cepCtrl.dispose();
    _valorPropostaCtrl.dispose();
    _dataNegociacaoCtrl.dispose();
    _horaNegociacaoCtrl.dispose();
    _dataVisitaCtrl.dispose();
    _horaVisitaCtrl.dispose();
    _observacoesCtrl.dispose();
    super.dispose();
  }

  Future<void> _selecionarDataVisita() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: kDanger,
              onPrimary: Colors.white,
              onSurface: kInk,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: kDanger),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _dataVisitaCtrl.text = DateFormat('dd/MM/yyyy').format(picked));
    }
  }

  Future<void> _selecionarHoraVisita() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: kDanger,
              onPrimary: Colors.white,
              onSurface: kInk,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: kDanger),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _horaVisitaCtrl.text = picked.format(context));
    }
  }

  String? _validarCampoObrigatorio(String? v, {String field = 'Campo'}) {
    if (v == null || v.trim().isEmpty) return '$field é obrigatório';
    return null;
  }

  String? _validarUF(String? v) {
    final x = v?.trim().toUpperCase() ?? '';
    if (x.isEmpty) return 'Estado é obrigatório';
    if (x.length != 2) return 'UF deve ter 2 letras';
    return null;
  }

  String? _validarCEP(String? v) {
    final raw = (v ?? '').replaceAll(RegExp(r'[^\d]'), '');
    if (raw.isEmpty) return null;
    if (raw.length != 8) return 'CEP deve ter 8 dígitos';
    return null;
  }

  String? _validarValorProposta(String? v) {
    final raw = (v ?? '').trim();
    if (raw.isEmpty) return null;
    final norm = raw.replaceAll('.', '').replaceAll(',', '.');
    final parsed = num.tryParse(norm);
    if (parsed == null) return 'Valor inválido';
    if (parsed < 0) return 'Valor não pode ser negativo';
    return null;
  }

  InputDecoration _obterDecoracaoCampo(
    String label, {
    String? hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool isObrigatorio = true,
  }) {
    return InputDecoration(
      labelText: '$label${isObrigatorio ? ' *' : ''}',
      hintText: hint,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
    );
  }

  void _onBuscarCepPressed() {
    final cepRaw = _cepCtrl.text.replaceAll(RegExp(r'[^\d]'), '');
    if (cepRaw.length != 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um CEP com 8 dígitos para buscar.')),
      );
      return;
    }
    _buscarEnderecoComFallback(cepRaw);
  }

  Future<void> _buscarEnderecoComFallback(String cep8) async {
    try {
      final status = await Connectivity().checkConnectivity();
      if (status == ConnectivityResult.none) return;

      EnderecoCep? end;
      if (kCorreiosBearerToken.isNotEmpty) {
        end = await _correios.buscar(cep8);
      }
      end ??= await _viaCep.buscar(cep8);

      if (end == null) return;

      String? tipo;
      String nomeVia = end.logradouro ?? '';
      if (nomeVia.isNotEmpty) {
        final firstSpace = nomeVia.indexOf(' ');
        if (firstSpace > 0) {
          final possivelTipo = nomeVia.substring(0, firstSpace);
          final resto = nomeVia.substring(firstSpace + 1);
          if (_abbr.keys.contains(possivelTipo)) {
            tipo = possivelTipo;
            nomeVia = resto;
          } else {
            final token = possivelTipo[0].toUpperCase() + possivelTipo.substring(1).toLowerCase();
            if (_abbr.keys.contains(token)) {
              tipo = token;
              nomeVia = resto;
            }
          }
        }
      }

      if (!mounted) return;
      setState(() {
        final e = end;
        if (e == null) return;

        final uf = e.uf ?? '';
        final cidade = e.cidade ?? '';
        final bairro = e.bairro ?? '';
        final logradouro = e.logradouro ?? '';
        final complemento = e.complemento ?? '';

        if (uf.isNotEmpty) _estadoCtrl.text = uf;
        if (cidade.isNotEmpty) _cidadeCtrl.text = cidade;
        if (bairro.isNotEmpty) _bairroCtrl.text = bairro;

        if ((tipo ?? '').isNotEmpty) {
          _tipoLogradouro = tipo;
          _nomeViaCtrl.text = nomeVia;
        } else if (logradouro.isNotEmpty) {
          _tipoLogradouro = null;
          _nomeViaCtrl.text = logradouro;
        }

        if (complemento.isNotEmpty && _complementoCtrl.text.trim().isEmpty) {
          _complementoCtrl.text = complemento;
        }
      });
    } catch (_) {
    }
  }

  Future<void> _salvarCliente() async {
    if (_formKey.currentState?.validate() != true) return;
    if (mounted) setState(() => _isLoading = true);

    try {
      final dataVisitaStr = _dataVisitaCtrl.text.trim();
      final horaVisitaStr = _horaVisitaCtrl.text.trim();

      if (dataVisitaStr.isEmpty || horaVisitaStr.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data e hora da visita são obrigatórias')),
        );
        return;
      }

      late DateTime dataHoraVisita;
      try {
        final horaParsed = DateFormat('HH:mm').parse(horaVisitaStr);
        final horaPadrao = DateFormat('HH:mm').format(horaParsed);
        dataHoraVisita = DateFormat('dd/MM/yyyy HH:mm').parse('$dataVisitaStr $horaPadrao');
      } on FormatException {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data ou hora da visita inválida. Use o formato correto.')),
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

      final tipoCheio = (_tipoLogradouro ?? '').trim();
      final tipoAbreviado = _abbr[tipoCheio] ?? tipoCheio;
      final nomeVia = _norm(_nomeViaCtrl.text);

      final logradouroTipo = tipoAbreviado;
      final enderecoNome  = nomeVia;

      final numeroStr = _numeroCtrl.text.replaceAll(RegExp(r'[^\d]'), '');
      final int? numeroInt = numeroStr.isEmpty ? null : int.tryParse(numeroStr);
      // REMOVIDO o bloqueio do número obrigatório — número pode ser null

      num? valorProposta;
      final rawValor = _valorPropostaCtrl.text.trim();
      if (rawValor.isNotEmpty) {
        final norm = rawValor.replaceAll('.', '').replaceAll(',', '.');
        valorProposta = num.tryParse(norm);
      }

      final agora = DateTime.now();
      final dataNegociacaoAtual = DateFormat('dd/MM/yyyy').format(agora);
      final horaNegociacaoAtual = DateFormat('HH:mm').format(agora);

      final telefoneDigits = _telefoneCtrl.text.replaceAll(RegExp(r'[^\d]'), '');
      final cepDigits = _cepCtrl.text.replaceAll(RegExp(r'[^\d]'), '');
      final nomeClienteNorm = _norm(_nomeClienteCtrl.text);

      final cliente = Cliente(
        id: const Uuid().v4(),
        nomeCliente: nomeClienteNorm,
        telefone: telefoneDigits,
        estabelecimento: _norm(_nomeEstabelecimentoCtrl.text),
        estado: _estadoCtrl.text.trim().toUpperCase(),
        cidade: _norm(_cidadeCtrl.text),
        endereco: enderecoNome,
        logradouro: logradouroTipo,
        numero: numeroInt, // aceita null
        complemento: _complementoCtrl.text.trim().isNotEmpty ? _norm(_complementoCtrl.text) : null,
        bairro: _norm(_bairroCtrl.text),
        cep: cepDigits,
        dataVisita: dataHoraVisita,
        observacoes: _observacoesCtrl.text.trim().isNotEmpty ? _norm(_observacoesCtrl.text) : null,
        consultorResponsavel: consultorNomeLocal,
        consultorUid: userId,
        horaVisita: horaVisitaStr,
        statusNegociacao: _statusNegociacao,
        valorProposta: valorProposta,
      );

      final persistedNow = await ClienteService.instance.saveCliente(cliente);

      if (!mounted) return;

      if (persistedNow) {
        try {
          await _client.from('clientes').update({
            'data_negociacao': dataNegociacaoAtual,
            'hora_negociacao': horaNegociacaoAtual,
          }).eq('id', cliente.id);

          await NotificationService.showSuccessNotification();
          widget.onClienteCadastrado?.call();
          _limparCampos();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Cliente cadastrado com sucesso! Data/hora da negociação: $dataNegociacaoAtual $horaNegociacaoAtual'),
                duration: const Duration(seconds: 4),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Cliente salvo, mas erro ao salvar data/hora da negociação: $e'),
                backgroundColor: kDanger,
              ),
            );
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Endereço já cadastrado (logradouro + número).')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      await NotificationService.showErrorNotification('Erro ao salvar: $e');
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
    _bairroCtrl.clear();
    _complementoCtrl.clear();
    _nomeViaCtrl.clear();
    _numeroCtrl.clear();
    _cepCtrl.clear();
    _valorPropostaCtrl.clear();
    _observacoesCtrl.clear();

    _tipoLogradouro = null;
    _statusNegociacao = null;

    _dataNegociacaoCtrl.clear();
    _horaNegociacaoCtrl.clear();

    _dataVisitaCtrl.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
    _horaVisitaCtrl.text = DateFormat('HH:mm').format(DateTime.now());

    FocusScope.of(context).unfocus();
    setState(() {});
  }

  InputDecoration relaxIfNarrow(InputDecoration base, bool isNarrow) {
    return isNarrow
        ? base.copyWith(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18))
        : base;
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width <= 420;
    final dropMenuMax = isNarrow ? 360.0 : 300.0;

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
                          Text(
                            'Cadastrar Cliente',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: kInk),
                          ),
                          Text(
                            'Preencha os dados do cliente',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: kInk2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
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
                            Text('Dados do Cliente', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: kInk)),
                            const SizedBox(height: 16),

                            TextFormField(
                              controller: _nomeClienteCtrl,
                              decoration: relaxIfNarrow(
                                _obterDecoracaoCampo(
                                  'Nome do Cliente',
                                  hint: 'Nome completo',
                                  prefixIcon: const Icon(Icons.person_outline),
                                  isObrigatorio: false,
                                ),
                                isNarrow,
                              ),
                            ),
                            const SizedBox(height: 12),

                            TextFormField(
                              controller: _telefoneCtrl,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [_telefoneFormatter],
                              decoration: relaxIfNarrow(
                                _obterDecoracaoCampo(
                                  'Telefone',
                                  hint: '(00) 00000-0000',
                                  prefixIcon: const Icon(Icons.call_outlined),
                                  isObrigatorio: false,
                                ),
                                isNarrow,
                              ),
                            ),
                            const SizedBox(height: 12),

                            TextFormField(
                              controller: _nomeEstabelecimentoCtrl,
                              decoration: relaxIfNarrow(
                                _obterDecoracaoCampo('Estabelecimento', hint: 'Nome do ponto de venda', prefixIcon: const Icon(Icons.storefront_outlined)),
                                isNarrow,
                              ),
                              validator: (v) => _validarCampoObrigatorio(v, field: 'Estabelecimento'),
                            ),
                            const SizedBox(height: 16),

                            Text('Endereço', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: kInk)),
                            const SizedBox(height: 12),

                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isWide = constraints.maxWidth >= 480;
                                if (isWide) {
                                  return Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: _CampoTipo(value: _tipoLogradouro, onChanged: (v) => setState(() => _tipoLogradouro = v), menuMaxHeight: dropMenuMax),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(flex: 4, child: _CampoNomeVia(controller: _nomeViaCtrl, isNarrow: false)),
                                      const SizedBox(width: 12),
                                      Expanded(flex: 2, child: _CampoNumero(controller: _numeroCtrl, isNarrow: false)),
                                    ],
                                  );
                                }
                                return Column(
                                  children: [
                                    _CampoTipo(value: _tipoLogradouro, onChanged: (v) => setState(() => _tipoLogradouro = v), menuMaxHeight: dropMenuMax),
                                    const SizedBox(height: 12),
                                    _CampoNomeVia(controller: _nomeViaCtrl, isNarrow: true),
                                    const SizedBox(height: 12),
                                    _CampoNumero(controller: _numeroCtrl, isNarrow: true),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 12),

                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _bairroCtrl,
                                    decoration: _obterDecoracaoCampo('Bairro', hint: 'Ex: Centro', prefixIcon: const Icon(Icons.location_on_outlined)),
                                    validator: (v) => _validarCampoObrigatorio(v, field: 'Bairro'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _complementoCtrl,
                                    decoration: _obterDecoracaoCampo('Complemento', hint: 'Ap, bloco, casa, sala', prefixIcon: const Icon(Icons.apartment_outlined), isObrigatorio: false),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _estadoCtrl,
                                    textCapitalization: TextCapitalization.characters,
                                    maxLength: 2,
                                    decoration: _obterDecoracaoCampo('UF', hint: 'PR', prefixIcon: const Icon(Icons.flag_outlined)).copyWith(counterText: ''),
                                    validator: _validarUF,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: _cidadeCtrl,
                                    decoration: _obterDecoracaoCampo('Cidade', hint: 'Ex: Londrina', prefixIcon: const Icon(Icons.location_city_outlined)),
                                    validator: (v) => _validarCampoObrigatorio(v, field: 'Cidade'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _cepCtrl,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [_cepFormatter],
                                    decoration: _obterDecoracaoCampo(
                                      'CEP',
                                      hint: '00000-000',
                                      prefixIcon: const Icon(Icons.local_post_office_outlined),
                                      isObrigatorio: false,
                                    ),
                                    validator: _validarCEP,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  height: 56,
                                  child: FilledButton.icon(
                                    onPressed: _onBuscarCepPressed,
                                    icon: const Icon(Icons.cloud_download_outlined),
                                    label: const Text('Buscar'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: kDanger,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            Text('Negociação', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: kInk)),
                            const SizedBox(height: 12),

                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    value: _statusNegociacao,
                                    items: _statusOptions.map((s) => DropdownMenuItem<String>(value: s['value']!, child: Text(s['label']!))).toList(),
                                    onChanged: (v) => setState(() => _statusNegociacao = v),
                                    decoration: _obterDecoracaoCampo('Status', prefixIcon: const Icon(Icons.timeline_outlined)),
                                    validator: (v) => v == null || v.isEmpty ? 'Status é obrigatório' : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: _valorPropostaCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: _obterDecoracaoCampo('Valor da proposta', hint: 'Ex: 1.500,00', prefixIcon: const Icon(Icons.attach_money_rounded), isObrigatorio: false),
                                    validator: _validarValorProposta,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            Text('Observações', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: kInk)),
                            const SizedBox(height: 12),

                            TextFormField(
                              controller: _observacoesCtrl,
                              minLines: 3,
                              maxLines: 6,
                              decoration: const InputDecoration(
                                labelText: 'Observações',
                                hintText: 'Ex: cliente solicitou entrega no período da tarde',
                                alignLabelWithHint: true,
                                prefixIcon: Icon(Icons.notes_outlined),
                              ),
                            ),

                            const SizedBox(height: 16),

                            Text('Agendamento de Visita', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: kInk)),
                            const SizedBox(height: 12),

                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: _selecionarDataVisita,
                                    child: AbsorbPointer(
                                      child: TextFormField(
                                        controller: _dataVisitaCtrl,
                                        readOnly: true,
                                        decoration: _obterDecoracaoCampo(
                                          'Data da visita',
                                          hint: 'dd/mm/aaaa',
                                          prefixIcon: const Icon(Icons.event_available_outlined),
                                          suffixIcon: IconButton(icon: const Icon(Icons.calendar_today_outlined), onPressed: _selecionarDataVisita),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: _selecionarHoraVisita,
                                    child: AbsorbPointer(
                                      child: TextFormField(
                                        controller: _horaVisitaCtrl,
                                        readOnly: true,
                                        decoration: _obterDecoracaoCampo(
                                          'Hora da visita',
                                          hint: '00:00',
                                          prefixIcon: const Icon(Icons.access_time_outlined),
                                          suffixIcon: IconButton(icon: const Icon(Icons.access_time), onPressed: _selecionarHoraVisita),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: kDanger.withOpacity(.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: kDanger.withOpacity(.25)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.info, color: kDanger, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Data da visita e hora da visita são definidas automaticamente com a data e hora atuais no momento do cadastro.',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: kInk,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _limparCampos,
                                    style: OutlinedButton.styleFrom(side: BorderSide(color: kDivider)),
                                    child: const Text('Limpar'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: _isLoading ? null : _salvarCliente,
                                    style: FilledButton.styleFrom(backgroundColor: kDanger, foregroundColor: Colors.white),
                                    child: _isLoading
                                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CampoTipo extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  final double menuMaxHeight;
  const _CampoTipo({required this.value, required this.onChanged, required this.menuMaxHeight});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: value,
      items: _CadastrarClienteState._tiposLogradouro.map((e) => DropdownMenuItem<String>(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
      selectedItemBuilder: (context) {
        return _CadastrarClienteState._tiposLogradouro.map((e) {
          final abreviado = _CadastrarClienteState._abbr[e] ?? e;
          return Align(alignment: Alignment.centerLeft, child: Text(abreviado, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium));
        }).toList();
      },
      onChanged: onChanged,
      decoration: const InputDecoration(labelText: 'Logradouro *', prefixIcon: Icon(Icons.map_outlined)),
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      menuMaxHeight: menuMaxHeight,
      validator: (v) => v == null || v.isEmpty ? 'Logradouro é obrigatório' : null,
    );
  }
}

class _CampoNomeVia extends StatelessWidget {
  final TextEditingController controller;
  final bool isNarrow;
  const _CampoNomeVia({required this.controller, required this.isNarrow});
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: 'Nome da via *',
        hintText: 'Ex: Tiradentes',
        prefixIcon: const Icon(Icons.route_outlined),
        contentPadding: isNarrow ? const EdgeInsets.symmetric(horizontal: 16, vertical: 18) : null,
      ),
      validator: (v) => (v == null || v.trim().isEmpty) ? 'Nome da via é obrigatório' : null,
    );
  }
}

class _CampoNumero extends StatelessWidget {
  final TextEditingController controller;
  final bool isNarrow;
  const _CampoNumero({required this.controller, required this.isNarrow});
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'Número', // removido asterisco
        hintText: '123',
        prefixIcon: const Icon(Icons.pin_outlined),
        contentPadding: isNarrow ? const EdgeInsets.symmetric(horizontal: 16, vertical: 18) : null,
      ),
      // validator removido para tornar opcional
    );
  }
}
