import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:email_validator/email_validator.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:flutter/services.dart';

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
  final _senhaCtrl = TextEditingController();
  final _matriculaCtrl = TextEditingController();

  final _telefoneMask = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {'#': RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.eager,
  );

  bool _loading = false;

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _telefoneCtrl.dispose();
    _emailCtrl.dispose();
    _senhaCtrl.dispose();
    _matriculaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cadastrarConsultor() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _loading = true);
      try {
        final String gestorId = FirebaseAuth.instance.currentUser!.uid;
        final String email = _emailCtrl.text.trim();
        final String senha = _senhaCtrl.text;

        final gestorDoc = await FirebaseFirestore.instance
            .collection('gestor')
            .doc(gestorId)
            .get();

        if (gestorDoc.exists) {
          final String gestorEmail = gestorDoc.get('email') as String? ?? '';
          if (email.toLowerCase() == gestorEmail.toLowerCase()) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Você não pode cadastrar um consultor com seu próprio e-mail.'),
                backgroundColor: Colors.red.shade700,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            );
            setState(() => _loading = false);
            return;
          }
        }

        final consultoresSnapshot = await FirebaseFirestore.instance
            .collection('consultores')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (consultoresSnapshot.docs.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Este e-mail já está cadastrado como consultor.'),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
          setState(() => _loading = false);
          return;
        }

        final credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: senha);
        print('✅ Usuário criado: ${credential.user!.uid}');

        await FirebaseFirestore.instance
            .collection('consultores')
            .doc(credential.user!.uid)
            .set({
          'nome': _nomeCtrl.text.trim(),
          'telefone': _telefoneCtrl.text,
          'email': email,
          'matricula': _matriculaCtrl.text.trim(),
          'gestorId': gestorId,
          'tipo': 'consultor',
          'uid': credential.user!.uid,
          'data_cadastro': FieldValue.serverTimestamp(),
        });

        print('✅ Consultor salvo em /consultores/${credential.user!.uid}');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Consultor cadastrado com sucesso!'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
        _limparCampos();
      } on FirebaseAuthException catch (e) {
        print('❌ Auth error: $e');
        String mensagem = 'Erro: ${e.message}';
        if (e.code == 'email-already-in-use') {
          mensagem = 'E-mail já cadastrado no Firebase';
        } else if (e.code == 'weak-password') {
          mensagem = 'Senha muito fraca';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensagem),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      } on FirebaseException catch (e) {
        print('❌ Firebase error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Erro ao salvar no banco. Verifique: conexão, regras do Firestore ou tente novamente.',
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      } catch (e, stack) {
        print('❌ Erro inesperado: $e\n$stack');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: ${e.toString()}'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      } finally {
        setState(() => _loading = false);
      }
    }
  }

  void _limparCampos() {
    _formKey.currentState!.reset();
    _nomeCtrl.clear();
    _telefoneCtrl.clear();
    _emailCtrl.clear();
    _senhaCtrl.clear();
    _matriculaCtrl.clear();
    setState(() {});
  }

  String get _iniciais {
    final nome = _nomeCtrl.text.trim();
    if (nome.isEmpty) return 'CN';
    final parts = nome.split(' ').where((p) => p.isNotEmpty).take(2).toList();
    return parts.map((p) => p[0]).join().toUpperCase();
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

  String? _validarCampoObrigatorio(String? v, {String field = 'Campo'}) {
    if (v == null || v.trim().isEmpty) return '$field é obrigatório';
    return null;
  }

  String? _validarCampoOpcional(String? v) {
    return null;
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
              Icons.group_add_rounded,
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
                  'Cadastrar Consultor',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Cadastre novos consultores para gerenciar clientes',
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
            // Header
            SliverToBoxAdapter(
              child: _buildHeader(),
            ),

            // Formulário
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
                        // Avatar do consultor
                        Center(
                          child: Column(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Center(
                                  child: Text(
                                    _iniciais,
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                                        ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Iniciais do Consultor',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Seção de Dados Pessoais
                        _buildSectionTitle(
                          'Dados Pessoais',
                          subtitle: 'Informações básicas do consultor',
                        ),

                        TextFormField(
                          controller: _nomeCtrl,
                          decoration: _obterDecoracaoCampo(
                            'Nome Completo',
                            hint: 'Digite o nome completo do consultor',
                          ),
                          validator: (v) =>
                              _validarCampoObrigatorio(v, field: 'Nome completo'),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _telefoneCtrl,
                          decoration: _obterDecoracaoCampo(
                            'Telefone',
                            hint: '(00) 00000-0000',
                          ),
                          keyboardType: TextInputType.phone,
                          inputFormatters: [_telefoneMask],
                          validator: (v) {
                            final raw = _telefoneMask.getUnmaskedText();
                            if (raw.isEmpty) return "Informe o telefone";
                            if (raw.length < 11) return "Telefone inválido";
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Seção de Acesso
                        _buildSectionTitle(
                          'Acesso ao Sistema',
                          subtitle: 'Credenciais para login',
                        ),

                        TextFormField(
                          controller: _emailCtrl,
                          decoration: _obterDecoracaoCampo(
                            'E-mail',
                            hint: 'consultor@empresa.com',
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return "Informe o e-mail";
                            if (!EmailValidator.validate(v.trim())) return "E-mail inválido";
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _senhaCtrl,
                          obscureText: true,
                          decoration: _obterDecoracaoCampo(
                            'Senha',
                            hint: 'Mínimo 6 caracteres',
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return "Informe a senha";
                            if (v.length < 6) return "Mínimo 6 caracteres";
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Seção de Dados Adicionais
                        _buildSectionTitle(
                          'Dados Adicionais',
                          subtitle: 'Informações complementares',
                        ),

                        TextFormField(
                          controller: _matriculaCtrl,
                          decoration: _obterDecoracaoCampo(
                            'Número da Matrícula',
                            hint: 'Digite o número da matrícula',
                            isObrigatorio: false,
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          validator: _validarCampoOpcional,
                        ),

                        const SizedBox(height: 24),

                        // Botões de ação
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
                                onPressed: _loading ? null : _cadastrarConsultor,
                                child: _loading
                                    ? SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Theme.of(context).colorScheme.onPrimary,
                                        ),
                                      )
                                    : Text(
                                        'Cadastrar Consultor',
                                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                              color: Theme.of(context).colorScheme.onPrimary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            '',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontStyle: FontStyle.italic,
                                ),
                            textAlign: TextAlign.center,
                          ),
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