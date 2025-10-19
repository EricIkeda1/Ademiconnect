import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:email_validator/email_validator.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:flutter/services.dart';

const String SENHA_PADRAO = 'Ademicon123456';

class ConsultoresTab extends StatefulWidget {
  const ConsultoresTab({super.key});

  @override
  State<ConsultoresTab> createState() => _ConsultoresTabState();
}

class _ConsultoresTabState extends State<ConsultoresTab> {
  final _formKey = GlobalKey<FormState>();
  final _nomeCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _matriculaCtrl = TextEditingController();

  final _telefoneMask = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {'#': RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.eager,
  );

  bool _loading = false;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _telefoneCtrl.dispose();
    _emailCtrl.dispose();
    _matriculaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cadastrarConsultor() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final sessionUser = _client.auth.currentSession?.user;
      final String gestorId = sessionUser?.id ?? '';

      if (gestorId.isEmpty) {
        _mostrarSnack('Sessão não encontrada. Faça login novamente.', cor: Colors.red);
        setState(() => _loading = false);
        return;
      }

      final email = _emailCtrl.text.trim();

      final gestorDoc = await _client
          .from('gestor')
          .select('email')
          .eq('id', gestorId)
          .maybeSingle();

      if (gestorDoc != null && gestorDoc['email'] != null) {
        final gestorEmail = gestorDoc['email'].toString().toLowerCase();
        if (email.toLowerCase() == gestorEmail) {
          _mostrarSnack('Você não pode cadastrar um consultor com seu próprio e-mail.', cor: Colors.red);
          setState(() => _loading = false);
          return;
        }
      }

      final consultorExistente = await _client
          .from('consultores')
          .select('id')
          .eq('email', email)
          .maybeSingle();

      if (consultorExistente != null) {
        _mostrarSnack('Este e-mail já está cadastrado como consultor.', cor: Colors.red);
        setState(() => _loading = false);
        return;
      }

      final response = await _client.auth.signUp(
        email: email,
        password: SENHA_PADRAO,
      );

      final authUser = response.user;
      if (authUser == null) {
        throw Exception('Falha ao criar usuário no Auth');
      }

      final userId = authUser.id;

      await _client.from('consultores').insert({
        'nome': _nomeCtrl.text.trim(),
        'telefone': _telefoneCtrl.text,
        'email': email,
        'matricula': _matriculaCtrl.text.trim(),
        'gestor_id': gestorId,
        'tipo': 'consultor', 
        'uid': userId,
        'data_cadastro': DateTime.now().toIso8601String(),
      });

      final login = await _client.auth.signInWithPassword(
        email: email,
        password: SENHA_PADRAO,
      );

      if (login.session != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushNamedAndRemoveUntil(context, '/consultor', (route) => false);
        });
        _mostrarSnack('Consultor cadastrado e logado com sucesso!', cor: Colors.green);
        _limparCampos();
      } else {
        throw Exception('Falha ao fazer login automático.');
      }
    } on AuthException catch (e) {
      _mostrarSnack('Erro de autenticação: ${e.message}', cor: Colors.red);
    } catch (e) {
      _mostrarSnack('Erro: ${e.toString()}', cor: Colors.red);
      print('❌ Erro completo: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _mostrarSnack(String mensagem, {required Color cor}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: cor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _limparCampos() {
    _formKey.currentState?.reset();
    _nomeCtrl.clear();
    _telefoneCtrl.clear();
    _emailCtrl.clear();
    _matriculaCtrl.clear();
    setState(() {});
  }

  String get _iniciais {
    final nome = _nomeCtrl.text.trim();
    if (nome.isEmpty) return 'CN';
    final partes = nome.split(' ').where((p) => p.isNotEmpty).take(2).toList();
    return partes.map((p) => p[0]).join().toUpperCase();
  }

  InputDecoration _decoracaoCampo(String label, {String? hint, bool obrigatorio = true}) {
    return InputDecoration(
      labelText: '$label${obrigatorio ? ' *' : ''}',
      hintText: hint,
      filled: true,
      fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => _limparCampos(),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(
              child: Card(
                margin: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Center(
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 32,
                                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                child: Text(
                                  _iniciais,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Iniciais do Consultor',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _nomeCtrl,
                          decoration: _decoracaoCampo('Nome Completo', hint: 'Digite o nome do consultor'),
                          validator: (v) => v == null || v.isEmpty ? 'Informe o nome' : null,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _telefoneCtrl,
                          decoration: _decoracaoCampo('Telefone', hint: '(00) 00000-0000'),
                          keyboardType: TextInputType.phone,
                          inputFormatters: [_telefoneMask],
                          validator: (v) {
                            final raw = _telefoneMask.getUnmaskedText();
                            if (raw.length < 11) return 'Telefone inválido';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _emailCtrl,
                          decoration: _decoracaoCampo('E-mail', hint: 'consultor@empresa.com'),
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Informe o e-mail';
                            if (!EmailValidator.validate(v.trim())) return 'E-mail inválido';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _matriculaCtrl,
                          decoration: _decoracaoCampo('Matrícula', hint: 'Número de matrícula', obrigatorio: false),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _limparCampos,
                                child: const Text('Limpar'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: _loading ? null : _cadastrarConsultor,
                                child: _loading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.group_add_rounded, size: 40, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cadastrar Consultor',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                'Adicione novos consultores ao sistema',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
