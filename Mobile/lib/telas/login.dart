import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  final SupabaseClient _client = Supabase.instance.client;
  late final AuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = AuthService(_client);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    if (mounted) {
      setState(() => _loading = true);
    }

    try {
      final email = _emailCtrl.text.trim().toLowerCase();
      final password = _passCtrl.text;

      final authResponse = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (authResponse.session == null) {
        throw Exception('Falha na autenticação');
      }

      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('Nenhum usuário logado');
      }

      Map<String, dynamic>? gestor;
      Map<String, dynamic>? consultor;

      try {
        gestor = await _client
            .from('gestor')
            .select('tipo')
            .eq('id', user.id)
            .maybeSingle();
        if (gestor != null) {
          print('✅ Gestor encontrado: ${gestor['tipo']}');
        }
      } catch (e) {
        gestor = null;
        print('❌ Erro ao buscar gestor: $e');
      }

      if (gestor == null) {
        try {
          consultor = await _client
              .from('consultores')
              .select('tipo')
              .eq('uid', user.id)
              .maybeSingle();
          if (consultor != null) {
            print('✅ Consultor encontrado: ${consultor['tipo']}');
          }
        } catch (e) {
          consultor = null;
          print('❌ Erro ao buscar consultor: $e');
        }
      }

      if (gestor == null && consultor == null) {
        await _client.auth.signOut();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Usuário não encontrado no sistema. Contate o administrador.'),
            ),
          );
        }
        if (mounted) {
          setState(() => _loading = false);
        }
        return;
      }

      String route = '/consultor';
      if (gestor != null) {
        final tipo = (gestor['tipo'] as String?) ?? 'gestor';
        route = (tipo == 'gestor' || tipo == 'supervisor') ? '/gestor' : '/consultor';
      }

      if (mounted) {
        Navigator.pushReplacementNamed(context, route);
      }
    } on AuthException catch (e) {
      String mensagem = 'Erro ao fazer login';
      switch (e.code) {
        case 'invalid_credentials':
          mensagem = 'E-mail ou senha incorretos';
          break;
        case 'user_not_found':
          mensagem = 'Usuário não encontrado';
          break;
        case 'email_not_confirmed':
          mensagem = 'E-mail não confirmado. Verifique sua caixa de entrada.';
          break;
        default:
          mensagem = e.message;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagem)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Image.asset("assets/Linha_Lateral.png", fit: BoxFit.cover),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              child: Form(
                key: _formKey,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset("assets/Logo.png", height: 120),
                      const SizedBox(height: 40),
                      TextFormField(
                        controller: _emailCtrl,
                        decoration: InputDecoration(
                          labelText: "E-mail",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        enableSuggestions: false,
                        textCapitalization: TextCapitalization.none,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Informe o e-mail';
                          final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                          if (!emailRegex.hasMatch(value)) return 'Email inválido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: "Senha",
                          suffixIcon: IconButton(
                            icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: (v) => (v?.isEmpty ?? true) ? 'Informe a senha' : null,
                        onFieldSubmitted: (_) => _login(),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 38.0, right: 7.6),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.pushNamed(context, '/recuperar'),
                            child: const Text('Esqueceu a senha?'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Transform.translate(
                        offset: const Offset(0, -46),
                        child: SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF231F20),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: _loading ? null : _login,
                            child: _loading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text(
                                    "Entrar",
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Transform.translate(
                        offset: const Offset(0, -40),
                        child: const Text(
                          'Use o e-mail e senha cadastrados',
                          style: TextStyle(color: Colors.black54),
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
    );
  }
}
