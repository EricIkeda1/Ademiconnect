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

const String kCorreiosBaseUrl = 'https://apihom.correios.com.br/';
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

  const EnderecoCep({
    this.uf,
    this.cidade,
    this.bairro,
    this.logradouro,
    this.complemento,
  });
}

class ViaCepService {
  final http.Client client;

  ViaCepService({http.Client? client}) : client = client ?? http.Client();

  Future<EnderecoCep?> buscar(String cep8) async {
    final uri = Uri.parse('https://viacep.com.br/ws/$cep8/json/');
    final resp = await client.get(uri);

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
  final http.Client client;

  CorreiosCepService({
    required this.baseUrl,
    required this.bearerToken,
    http.Client? client,
  }) : client = client ?? http.Client();

  Future<EnderecoCep?> buscar(String cep8) async {
    if (bearerToken.isEmpty) return null;

    final uri = Uri.parse('$baseUrl/cep/v1/enderecos/$cep8');
    final resp = await client.get(
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
    } else if (data is List &&
        data.isNotEmpty &&
        data.first is Map<String, dynamic>) {
      map = data.first as Map<String, dynamic>;
    } else {
      return null;
    }

    String? uf =
        _readString(map, ['uf', 'estado', 'siglaUf']);
    String? cidade =
        _readString(map, ['localidade', 'cidade', 'municipio', 'nomeMunicipio']);
    String? bairro =
        _readString(map, ['bairro', 'distrito']);
    String? logradouro =
        _readString(map, ['logradouro', 'endereco', 'nomeLogradouro']);
    String? complemento =
        _readString(map, ['complemento']);

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
  final Function? onClienteCadastrado;

  const CadastrarCliente({super.key, this.onClienteCadastrado});

  @override
  State<CadastrarCliente> createState() => CadastrarClienteState();
}

class CadastrarClienteState extends State<CadastrarCliente> {
  final formKey = GlobalKey<FormState>();
  final client = Supabase.instance.client;

  final nomeClienteCtrl = TextEditingController();
  final telefoneCtrl = TextEditingController();
  final nomeEstabelecimentoCtrl = TextEditingController();
  final estadoCtrl = TextEditingController();
  final cidadeCtrl = TextEditingController();
  final bairroCtrl = TextEditingController();
  final complementoCtrl = TextEditingController();
  String? tipoLogradouro;
  final nomeViaCtrl = TextEditingController();
  final numeroCtrl = TextEditingController();
  final cepCtrl = TextEditingController();
  String? statusNegociacao;
  final valorPropostaCtrl = TextEditingController();

  final dataNegociacaoCtrl = TextEditingController();
  final horaNegociacaoCtrl = TextEditingController();

  final dataVisitaCtrl = TextEditingController();
  final horaVisitaCtrl = TextEditingController();

  final observacoesCtrl = TextEditingController();

  final telefoneFormatter = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {'#': RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  final cepFormatter = MaskTextInputFormatter(
    mask: '#####-###',
    filter: {'#': RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  static const Map<String, String> abbr = {
    'Avenida': 'Av.',
    'Rua': 'R.',
    'Alameda': 'Al.',
    'Travessa': 'Tv.',
    'Rodovia': 'Rod.',
    'Estrada': 'Est.',
    'Praça': 'P.',
    'Largo': 'Lg.',
    'Via': 'Via',
  };

  static const List<String> tiposLogradouro = [
    'Rua',
    'Avenida',
    'Alameda',
    'Travessa',
    'Rodovia',
    'Estrada',
    'Praça',
    'Via',
    'Largo',
  ];

  final List<Map<String, String>> statusOptions = const [
    {'label': 'Conexão', 'value': 'conexao'},
    {'label': 'Negociação', 'value': 'negociacao'},
    {'label': 'Fechada', 'value': 'fechada'},
  ];

  bool isLoading = false;
  late final VoidCallback cepListener;
  late final ViaCepService viaCep;
  late final CorreiosCepService correios;

  String norm(String s) =>
      s.trim().replaceAll(RegExp(r'\s+'), ' ');

  @override
  void initState() {
    super.initState();
    viaCep = ViaCepService();
    correios = CorreiosCepService(
      baseUrl: kCorreiosBaseUrl,
      bearerToken: kCorreiosBearerToken,
    );

    dataNegociacaoCtrl.clear();
    horaNegociacaoCtrl.clear();
    dataVisitaCtrl.clear();
    horaVisitaCtrl.clear();

    cepListener = () {
      final raw = cepCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
      if (raw.length == 8) {
        buscarEnderecoComFallback(raw);
      }
    };

    cepCtrl.addListener(cepListener);
  }

  @override
  void dispose() {
    cepCtrl.removeListener(cepListener);

    nomeClienteCtrl.dispose();
    telefoneCtrl.dispose();
    nomeEstabelecimentoCtrl.dispose();
    estadoCtrl.dispose();
    cidadeCtrl.dispose();
    bairroCtrl.dispose();
    complementoCtrl.dispose();
    nomeViaCtrl.dispose();
    numeroCtrl.dispose();
    cepCtrl.dispose();
    valorPropostaCtrl.dispose();

    dataNegociacaoCtrl.dispose();
    horaNegociacaoCtrl.dispose();
    dataVisitaCtrl.dispose();
    horaVisitaCtrl.dispose();
    observacoesCtrl.dispose();

    super.dispose();
  }

  Future<void> selecionarDataNegociacao() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: kDanger,
              onPrimary: Colors.white,
              onSurface: kInk,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: kDanger,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        dataNegociacaoCtrl.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> selecionarHoraNegociacao() async {
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
              style: TextButton.styleFrom(
                foregroundColor: kDanger,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        horaNegociacaoCtrl.text = picked.format(context);
      });
    }
  }

  String? validarCampoObrigatorio(String? v, String field) {
    if (v == null || v.trim().isEmpty) {
      return '$field obrigatório';
    }
    return null;
  }

  String? validarUF(String? v) {
    final x = v?.trim().toUpperCase() ?? '';
    if (x.isEmpty) return 'Estado obrigatório';
    if (x.length != 2) return 'UF deve ter 2 letras';
    return null;
  }

  String? validarCEP(String? v) {
    final raw = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (raw.isEmpty) return null;
    if (raw.length != 8) return 'CEP deve ter 8 dígitos';
    return null;
  }

  String? validarValorProposta(String? v) {
    final raw = (v ?? '').trim();
    if (raw.isEmpty) return null;

    final norm = raw.replaceAll('.', '').replaceAll(',', '.');
    final parsed = num.tryParse(norm);
    if (parsed == null) return 'Valor inválido';
    if (parsed < 0) return 'Valor não pode ser negativo';
    return null;
  }

  InputDecoration obterDecoracaoCampo(
    String label, {
    String? hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool isObrigatorio = true,
  }) {
    return InputDecoration(
      labelText: isObrigatorio ? '$label *' : label,
      hintText: hint,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
    );
  }

  void onBuscarCepPressed() {
    final cepRaw = cepCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cepRaw.length != 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe um CEP com 8 dígitos para buscar.'),
        ),
      );
      return;
    }
    buscarEnderecoComFallback(cepRaw);
  }

  Future<void> buscarEnderecoComFallback(String cep8) async {
    try {
      final status = await Connectivity().checkConnectivity();
      if (status == ConnectivityResult.none) return;

      EnderecoCep? end;
      if (kCorreiosBearerToken.isNotEmpty) {
        end = await correios.buscar(cep8);
      }
      end ??= await viaCep.buscar(cep8);

      if (end == null) return;

      String? tipo;
      String nomeVia = end.logradouro ?? '';

      if (nomeVia.isNotEmpty) {
        final firstSpace = nomeVia.indexOf(' ');
        if (firstSpace > 0) {
          final possivelTipo = nomeVia.substring(0, firstSpace);
          final resto = nomeVia.substring(firstSpace + 1);

          if (abbr.keys.contains(possivelTipo)) {
            tipo = possivelTipo;
            nomeVia = resto;
          } else {
            final token =
                possivelTipo[0].toUpperCase() + possivelTipo.substring(1).toLowerCase();
            if (abbr.keys.contains(token)) {
              tipo = token;
              nomeVia = resto;
            }
          }
        }
      }

      if (!mounted) return;

      setState(() {
        final e = end!;
        final uf = e.uf ?? '';
        final cidade = e.cidade ?? '';
        final bairro = e.bairro ?? '';
        final logradouro = e.logradouro ?? '';
        final complemento = e.complemento ?? '';

        if (uf.isNotEmpty) estadoCtrl.text = uf;
        if (cidade.isNotEmpty) cidadeCtrl.text = cidade;
        if (bairro.isNotEmpty) bairroCtrl.text = bairro;

        if ((tipo ?? '').isNotEmpty) {
          tipoLogradouro = tipo;
          nomeViaCtrl.text = nomeVia;
        } else if (logradouro.isNotEmpty) {
          tipoLogradouro = null;
          nomeViaCtrl.text = logradouro;
        }

        if (complemento.isNotEmpty && complementoCtrl.text.trim().isEmpty) {
          complementoCtrl.text = complemento;
        }
      });
    } catch (_) {}
  }

  Future<void> salvarCliente() async {
    if (formKey.currentState?.validate() != true) return;

    if (mounted) {
      setState(() => isLoading = true);
    }

    try {
      final dataNegStr = dataNegociacaoCtrl.text.trim();
      final horaNegStr = horaNegociacaoCtrl.text.trim();

      if (dataNegStr.isEmpty || horaNegStr.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Data e hora da negociação (próxima visita) são obrigatórias',
            ),
          ),
        );
        return;
      }

      late DateTime dataHoraNegociacao;
      try {
        final horaParsed = DateFormat('HH:mm').parse(horaNegStr);
        final horaPadrao = DateFormat('HH:mm').format(horaParsed);

        dataHoraNegociacao =
            DateFormat('dd/MM/yyyy HH:mm').parse('$dataNegStr $horaPadrao');
      } on FormatException {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Data ou hora da negociação inválida. Use o formato correto.',
            ),
          ),
        );
        return;
      }

      final agora = DateTime.now();
      final dataVisitaAtual = DateFormat('dd/MM/yyyy').format(agora);
      final horaVisitaAtual = DateFormat('HH:mm').format(agora);

      dataVisitaCtrl.text = dataVisitaAtual;
      horaVisitaCtrl.text = horaVisitaAtual;

      final session = client.auth.currentSession;
      if (session == null || session.user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro: sessão expirada. Faça login novamente.'),
          ),
        );
        return;
      }

      final userId = session.user!.id;
      final consultorNomeLocal = session.user!.email ?? 'Desconhecido';

      final tipoCheio = (tipoLogradouro ?? '').trim();
      final tipoAbreviado = abbr[tipoCheio] ?? tipoCheio;
      final nomeViaNorm = norm(nomeViaCtrl.text);
      final logradouroTipo = tipoAbreviado;
      final enderecoNome = nomeViaNorm;

      final numeroStr = numeroCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
      final int? numeroInt =
          numeroStr.isEmpty ? null : int.tryParse(numeroStr);

      num? valorProposta;
      final rawValor = valorPropostaCtrl.text.trim();
      if (rawValor.isNotEmpty) {
        final normValor = rawValor.replaceAll('.', '').replaceAll(',', '.');
        valorProposta = num.tryParse(normValor);
      }

      final telefoneDigits =
          telefoneCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
      final cepDigits = cepCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
      final nomeClienteNorm = norm(nomeClienteCtrl.text);

      final cliente = Cliente(
        id: const Uuid().v4(),
        nomeCliente: nomeClienteNorm,
        telefone: telefoneDigits,
        estabelecimento: norm(nomeEstabelecimentoCtrl.text),
        estado: estadoCtrl.text.trim().toUpperCase(),
        cidade: norm(cidadeCtrl.text),
        endereco: enderecoNome,
        logradouro: logradouroTipo,
        numero: numeroInt, // opcional
        complemento: complementoCtrl.text.trim().isNotEmpty
            ? norm(complementoCtrl.text)
            : null,
        bairro: norm(bairroCtrl.text),
        cep: cepDigits,
        dataVisita: agora,
        horaVisita: horaVisitaAtual,
        observacoes: observacoesCtrl.text.trim().isNotEmpty
            ? norm(observacoesCtrl.text)
            : null,
        consultorResponsavel: consultorNomeLocal,
        consultorUid: userId,
        statusNegociacao: statusNegociacao,
        valorProposta: valorProposta,
        dataNegociacao: dataHoraNegociacao,
        horaNegociacao: horaNegStr,
      );

      final persistedNow =
          await ClienteService.instance.saveCliente(cliente);

      if (!mounted) return;

      if (persistedNow) {
        try {
          await client.from('clientes').update({
            'data_negociacao': dataHoraNegociacao.toIso8601String(),
            'hora_negociacao':
                DateFormat('HH:mm:ss').format(dataHoraNegociacao),
            'data_visita': agora.toIso8601String(),
            'hora_visita': DateFormat('HH:mm:ss').format(agora),
          }).eq('id', cliente.id);
        } catch (e) {
          debugPrint('Erro ao atualizar datas/horas extras: $e');
        }

        await NotificationService.showSuccessNotification();
        widget.onClienteCadastrado?.call();
        limparCampos();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enviado com sucesso!'),
            duration: Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Endereço já cadastrado (logradouro + número).',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      await NotificationService.showErrorNotification('Erro ao salvar: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void limparCampos() {
    formKey.currentState?.reset();
    nomeClienteCtrl.clear();
    telefoneCtrl.clear();
    nomeEstabelecimentoCtrl.clear();
    estadoCtrl.clear();
    cidadeCtrl.clear();
    bairroCtrl.clear();
    complementoCtrl.clear();
    nomeViaCtrl.clear();
    numeroCtrl.clear();
    cepCtrl.clear();
    valorPropostaCtrl.clear();
    observacoesCtrl.clear();
    tipoLogradouro = null;
    statusNegociacao = null;

    dataNegociacaoCtrl.clear();
    horaNegociacaoCtrl.clear();
    dataVisitaCtrl.clear();
    horaVisitaCtrl.clear();

    FocusScope.of(context).unfocus();
    setState(() {});
  }

  InputDecoration relaxIfNarrow(
    InputDecoration base,
    bool isNarrow,
  ) {
    return isNarrow
        ? base.copyWith(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 18,
            ),
          )
        : base;
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 420;
    final dropMenuMax = isNarrow ? 360.0 : 300.0;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          limparCampos();
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.add_business_rounded,
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimaryContainer,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cadastrar Cliente',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: kInk,
                                ),
                          ),
                          Text(
                            'Preencha os dados do cliente',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: kInk2),
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
                  constraints:
                      const BoxConstraints(maxWidth: 900),
                  child: Card(
                    margin: const EdgeInsets.fromLTRB(
                        16, 0, 16, 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: formKey,
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Dados do Cliente',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight:
                                        FontWeight.bold,
                                    color: kInk,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: nomeClienteCtrl,
                              decoration: relaxIfNarrow(
                                obterDecoracaoCampo(
                                  'Nome do Cliente',
                                  hint: 'Nome completo',
                                  prefixIcon: const Icon(
                                      Icons.person_outline),
                                  isObrigatorio: false,
                                ),
                                isNarrow,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: telefoneCtrl,
                              keyboardType:
                                  TextInputType.phone,
                              inputFormatters: [
                                telefoneFormatter
                              ],
                              decoration: relaxIfNarrow(
                                obterDecoracaoCampo(
                                  'Telefone',
                                  hint: '(00) 00000-0000',
                                  prefixIcon: const Icon(
                                      Icons.call_outlined),
                                  isObrigatorio: false,
                                ),
                                isNarrow,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller:
                                  nomeEstabelecimentoCtrl,
                              decoration: relaxIfNarrow(
                                obterDecoracaoCampo(
                                  'Estabelecimento',
                                  hint:
                                      'Nome do ponto de venda',
                                  prefixIcon: const Icon(
                                      Icons.storefront_outlined),
                                ),
                                isNarrow,
                              ),
                              validator: (v) =>
                                  validarCampoObrigatorio(
                                      v, 'Estabelecimento'),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Endereço',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight:
                                        FontWeight.bold,
                                    color: kInk,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isWide =
                                    constraints.maxWidth >
                                        480;
                                if (isWide) {
                                  return Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: CampoTipo(
                                          value:
                                              tipoLogradouro,
                                          onChanged: (v) {
                                            setState(() {
                                              tipoLogradouro =
                                                  v;
                                            });
                                          },
                                          menuMaxHeight:
                                              dropMenuMax,
                                        ),
                                      ),
                                      const SizedBox(
                                          width: 12),
                                      Expanded(
                                        flex: 4,
                                        child: CampoNomeVia(
                                          controller:
                                              nomeViaCtrl,
                                          isNarrow: false,
                                        ),
                                      ),
                                      const SizedBox(
                                          width: 12),
                                      Expanded(
                                        flex: 2,
                                        child: CampoNumero(
                                          controller:
                                              numeroCtrl,
                                          isNarrow: false,
                                        ),
                                      ),
                                    ],
                                  );
                                }
                                return Column(
                                  children: [
                                    CampoTipo(
                                      value: tipoLogradouro,
                                      onChanged: (v) {
                                        setState(() {
                                          tipoLogradouro = v;
                                        });
                                      },
                                      menuMaxHeight:
                                          dropMenuMax,
                                    ),
                                    const SizedBox(
                                        height: 12),
                                    CampoNomeVia(
                                      controller:
                                          nomeViaCtrl,
                                      isNarrow: true,
                                    ),
                                    const SizedBox(
                                        height: 12),
                                    CampoNumero(
                                      controller:
                                          numeroCtrl,
                                      isNarrow: true,
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: bairroCtrl,
                                    decoration:
                                        obterDecoracaoCampo(
                                      'Bairro',
                                      hint: 'Ex: Centro',
                                      prefixIcon:
                                          const Icon(Icons
                                              .location_on_outlined),
                                    ),
                                    validator: (v) =>
                                        validarCampoObrigatorio(
                                            v, 'Bairro'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller:
                                        complementoCtrl,
                                    decoration:
                                        obterDecoracaoCampo(
                                      'Complemento',
                                      hint:
                                          'Ap, bloco, casa, sala',
                                      prefixIcon:
                                          const Icon(Icons
                                              .apartment_outlined),
                                      isObrigatorio: false,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: estadoCtrl,
                                    textCapitalization:
                                        TextCapitalization
                                            .characters,
                                    maxLength: 2,
                                    decoration:
                                        obterDecoracaoCampo(
                                      'UF',
                                      hint: 'PR',
                                      prefixIcon:
                                          const Icon(Icons
                                              .flag_outlined),
                                    ).copyWith(
                                      counterText: '',
                                    ),
                                    validator: validarUF,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: cidadeCtrl,
                                    decoration:
                                        obterDecoracaoCampo(
                                      'Cidade',
                                      hint: 'Ex: Londrina',
                                      prefixIcon:
                                          const Icon(Icons
                                              .location_city_outlined),
                                    ),
                                    validator: (v) =>
                                        validarCampoObrigatorio(
                                            v, 'Cidade'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: cepCtrl,
                                    keyboardType:
                                        TextInputType
                                            .number,
                                    inputFormatters: [
                                      cepFormatter
                                    ],
                                    decoration:
                                        obterDecoracaoCampo(
                                      'CEP',
                                      hint: '00000-000',
                                      prefixIcon:
                                          const Icon(Icons
                                              .local_post_office_outlined),
                                      isObrigatorio: false,
                                    ),
                                    validator:
                                        validarCEP,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  height: 56,
                                  child: FilledButton.icon(
                                    onPressed:
                                        onBuscarCepPressed,
                                    icon: const Icon(Icons
                                        .cloud_download_outlined),
                                    label:
                                        const Text('Buscar'),
                                    style:
                                        FilledButton.styleFrom(
                                      backgroundColor:
                                          kDanger,
                                      foregroundColor:
                                          Colors.white,
                                      padding:
                                          const EdgeInsets
                                              .symmetric(
                                        horizontal: 16,
                                      ),
                                      shape:
                                          RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius
                                                .circular(
                                                    12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Negociação / Próxima visita',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight:
                                        FontWeight.bold,
                                    color: kInk,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child:
                                      DropdownButtonFormField<
                                          String>(
                                    isExpanded: true,
                                    value:
                                        statusNegociacao,
                                    items:
                                        statusOptions.map(
                                      (s) {
                                        return DropdownMenuItem<
                                            String>(
                                          value:
                                              s['value']!,
                                          child: Text(
                                              s['label']!),
                                        );
                                      },
                                    ).toList(),
                                    onChanged: (v) {
                                      setState(() {
                                        statusNegociacao =
                                            v;
                                      });
                                    },
                                    decoration:
                                        obterDecoracaoCampo(
                                      'Status',
                                      prefixIcon:
                                          const Icon(Icons
                                              .timeline_outlined),
                                    ),
                                    validator: (v) =>
                                        v == null ||
                                                v.isEmpty
                                            ? 'Status obrigatório'
                                            : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller:
                                        valorPropostaCtrl,
                                    keyboardType:
                                        const TextInputType
                                                .numberWithOptions(
                                            decimal: true),
                                    decoration:
                                        obterDecoracaoCampo(
                                      'Valor da proposta',
                                      hint: 'Ex: 1.500,00',
                                      prefixIcon: const Icon(
                                          Icons
                                              .attach_money_rounded),
                                      isObrigatorio: false,
                                    ),
                                    validator:
                                        validarValorProposta,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap:
                                        selecionarDataNegociacao,
                                    child: AbsorbPointer(
                                      child: TextFormField(
                                        controller:
                                            dataNegociacaoCtrl,
                                        readOnly: true,
                                        decoration:
                                            obterDecoracaoCampo(
                                          'Data negociação (próx. visita)',
                                          hint:
                                              'dd/mm/aaaa',
                                          prefixIcon: const Icon(
                                              Icons
                                                  .event_note_outlined),
                                          suffixIcon:
                                              IconButton(
                                            icon: const Icon(
                                                Icons
                                                    .calendar_today_outlined),
                                            onPressed:
                                                selecionarDataNegociacao,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: GestureDetector(
                                    onTap:
                                        selecionarHoraNegociacao,
                                    child: AbsorbPointer(
                                      child: TextFormField(
                                        controller:
                                            horaNegociacaoCtrl,
                                        readOnly: true,
                                        decoration:
                                            obterDecoracaoCampo(
                                          'Hora negociação',
                                          hint: '00:00',
                                          prefixIcon: const Icon(
                                              Icons
                                                  .access_time_outlined),
                                          suffixIcon:
                                              IconButton(
                                            icon: const Icon(
                                                Icons
                                                    .access_time),
                                            onPressed:
                                                selecionarHoraNegociacao,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Observações',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight:
                                        FontWeight.bold,
                                    color: kInk,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: observacoesCtrl,
                              minLines: 3,
                              maxLines: 6,
                              decoration:
                                  const InputDecoration(
                                labelText: 'Observações',
                                hintText:
                                    'Ex: cliente solicitou entrega no período da tarde',
                                alignLabelWithHint: true,
                                prefixIcon: Icon(
                                    Icons.notes_outlined),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding:
                                  const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: kDanger
                                    .withOpacity(0.08),
                                borderRadius:
                                    BorderRadius.circular(
                                        8),
                                border: Border.all(
                                  color: kDanger
                                      .withOpacity(0.25),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                children: [
                                  const Icon(
                                    Icons.info,
                                    color: kDanger,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'A data da visita e a hora da visita serão definidas automaticamente com a data e hora atuais do dispositivo no momento em que você salvar o cliente.',
                                      style: Theme.of(
                                              context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: kInk,
                                            fontWeight:
                                                FontWeight
                                                    .w600,
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
                                    onPressed:
                                        limparCampos,
                                    style: OutlinedButton
                                        .styleFrom(
                                      side: BorderSide(
                                        color: kDivider,
                                      ),
                                    ),
                                    child:
                                        const Text('Limpar'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: isLoading
                                        ? null
                                        : salvarCliente,
                                    style: FilledButton
                                        .styleFrom(
                                      backgroundColor:
                                          kDanger,
                                      foregroundColor:
                                          Colors.white,
                                    ),
                                    child: isLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child:
                                                CircularProgressIndicator(
                                              strokeWidth:
                                                  2,
                                              color: Colors
                                                  .white,
                                            ),
                                          )
                                        : const Text(
                                            'Cadastrar',
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CampoTipo extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  final double menuMaxHeight;

  const CampoTipo({
    required this.value,
    required this.onChanged,
    required this.menuMaxHeight,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: value,
      items: CadastrarClienteState.tiposLogradouro
          .map(
            (e) => DropdownMenuItem<String>(
              value: e,
              child: Text(
                e,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      selectedItemBuilder: (context) {
        return CadastrarClienteState.tiposLogradouro.map((e) {
          final abreviado =
              CadastrarClienteState.abbr[e] ?? e;
          return Align(
            alignment: Alignment.centerLeft,
            child: Text(
              abreviado,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium,
            ),
          );
        }).toList();
      },
      onChanged: onChanged,
      decoration: const InputDecoration(
        labelText: 'Logradouro *',
        prefixIcon: Icon(Icons.map_outlined),
      ),
      menuMaxHeight: menuMaxHeight,
      validator: (v) =>
          v == null || v.isEmpty ? 'Logradouro obrigatório' : null,
    );
  }
}

class CampoNomeVia extends StatelessWidget {
  final TextEditingController controller;
  final bool isNarrow;

  const CampoNomeVia({
    required this.controller,
    required this.isNarrow,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: 'Nome da via *',
        hintText: 'Ex: Tiradentes',
        prefixIcon: const Icon(Icons.route_outlined),
        contentPadding: isNarrow
            ? const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 18,
              )
            : null,
      ),
      validator: (v) => v == null || v.trim().isEmpty
          ? 'Nome da via obrigatório'
          : null,
    );
  }
}

class CampoNumero extends StatelessWidget {
  final TextEditingController controller;
  final bool isNarrow;

  const CampoNumero({
    required this.controller,
    required this.isNarrow,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'Número',      
        hintText: '123',
        prefixIcon: const Icon(Icons.pin_outlined),
        contentPadding: isNarrow
            ? const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 18,
              )
            : null,
      ),
      validator: (v) => null,
    );
  }
}
