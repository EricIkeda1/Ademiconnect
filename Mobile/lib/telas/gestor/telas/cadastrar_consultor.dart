import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:email_validator/email_validator.dart';

const String SENHA_PADRAO = 'Ademicon123456';

class BrPhoneTextInputFormatter extends TextInputFormatter {
  const BrPhoneTextInputFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final isCell = digits.length > 10;
    final mask = isCell ? '(##) #####-####' : '(##) ####-####';

    final masked = _applyMask(digits, mask);
    final cursor = masked.length.clamp(0, masked.length);

    return TextEditingValue(
      text: masked,
      selection: TextSelection.collapsed(offset: cursor),
    );
  }

  String _applyMask(String digits, String mask) {
    final buf = StringBuffer();
    int i = 0;
    for (int m = 0; m < mask.length && i < digits.length; m++) {
      final ch = mask[m];
      if (ch == '#') {
        buf.write(digits[i]);
        i++;
      } else {
        buf.write(ch);
      }
    }
    return buf.toString();
  }
}

class CadastrarConsultorPage extends StatefulWidget {
  const CadastrarConsultorPage({super.key});
  @override
  State<CadastrarConsultorPage> createState() => _CadastrarConsultorPageState();
}

class _CadastrarConsultorPageState extends State<CadastrarConsultorPage> {
  static const _brandRed = Color(0xFFEA3124);
  static const _brandRedDark = Color(0xFFD12B20);
  static const _bg = Color(0xFFF6F6F8);
  static const _textPrimary = Color(0xFF231F20);
  static const _chipBg = Color(0xFFFFECEA);
  static const _chipIcon = Color(0xFFE24B3C);
  static const _fieldFill = Color(0xFFF7F7FA);
  static const _border = Color(0xFFE3E3E6);
  static const double _radiusCard = 16;
  static const double _radiusField = 12;
  static const double _maxWidth = 560;

  final _formKey = GlobalKey<FormState>();
  final _nomeCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _matCtrl = TextEditingController();

  final _phoneFmt = const BrPhoneTextInputFormatter();

  bool _loading = false;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _telCtrl.dispose();
    _emailCtrl.dispose();
    _matCtrl.dispose();
    super.dispose();
  }

  String? _req(String? v, String label) => (v == null || v.trim().isEmpty) ? '$label é obrigatório' : null;

  void _snack(String m, {required Color cor}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m),
        backgroundColor: cor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _clear() {
    _formKey.currentState?.reset();
    _nomeCtrl.clear();
    _telCtrl.clear();
    _emailCtrl.clear();
    _matCtrl.clear();
    setState(() {});
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final user = _client.auth.currentSession?.user;
      final gestorId = user?.id ?? '';
      if (gestorId.isEmpty) {
        _snack('Sessão não encontrada. Faça login novamente.', cor: Colors.red);
        setState(() => _loading = false);
        return;
      }

      final email = _emailCtrl.text.trim();
      final telDigits = _telCtrl.text.replaceAll(RegExp(r'\D'), '');

      final g = await _client.from('gestor').select('email').eq('id', gestorId).maybeSingle();
      if (g != null && (g['email'] as String?) != null) {
        if (email.toLowerCase() == (g['email'] as String).toLowerCase()) {
          _snack('Você não pode cadastrar um consultor com seu próprio e-mail.', cor: Colors.red);
          setState(() => _loading = false);
          return;
        }
      }

      final dup = await _client
          .from('consultores')
          .select('id')
          .eq('gestor_id', gestorId)
          .eq('email', email)
          .maybeSingle();
      if (dup != null) {
        _snack('Este e-mail já está cadastrado como consultor para este gestor.', cor: Colors.red);
        setState(() => _loading = false);
        return;
      }

      final signUp = await _client.auth.signUp(email: email, password: SENHA_PADRAO);
      final authUser = signUp.user;
      if (authUser == null) throw Exception('Falha ao criar usuário no Auth');
      final uid = authUser.id;

      await _client.from('consultores').insert({
        'nome': _nomeCtrl.text.trim(),
        'telefone': telDigits,
        'email': email,
        'matricula': _matCtrl.text.trim().isEmpty ? null : _matCtrl.text.trim(),
        'gestor_id': gestorId,
        'tipo': 'consultor',
        'uid': uid,
        'data_cadastro': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      Navigator.of(context).pop(true);
      _snack('Consultor cadastrado com sucesso!', cor: Colors.green);
      _clear();
    } on AuthException catch (e) {
      _snack('Erro de autenticação: ${e.message}', cor: Colors.red);
    } catch (e) {
      _snack('Erro: $e', cor: Colors.red);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, color: _textPrimary),
                        splashRadius: 22,
                        onPressed: () => Navigator.of(context).maybePop(),
                        tooltip: 'Voltar',
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _chipBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.person_add_alt_1, color: _chipIcon),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cadastrar Consultor',
                              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: _textPrimary),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Preencha os dados do novo consultor da equipe',
                              style: TextStyle(color: Colors.black54, fontSize: 13.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(_radiusCard),
                      boxShadow: const [BoxShadow(color: Color(0x19000000), blurRadius: 10, offset: Offset(0, 4))],
                      border: Border.all(color: _border),
                    ),
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SectionLabel(icon: Icons.person_outline, text: 'Nome Completo', requiredMark: true),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _nomeCtrl,
                            textInputAction: TextInputAction.next,
                            decoration: _input('Ex: João da Silva Santos'),
                            validator: (v) => _req(v, 'Nome'),
                          ),
                          const SizedBox(height: 12),

                          _SectionLabel(icon: Icons.phone_outlined, text: 'Telefone', requiredMark: true),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _telCtrl,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            decoration: _input('(11) 98765-4321'),
                            inputFormatters: [_phoneFmt],
                            validator: (v) {
                              final raw = v?.replaceAll(RegExp(r'\D'), '') ?? '';
                              if (raw.isEmpty) return 'Telefone é obrigatório';
                              if (raw.length != 10 && raw.length != 11) return 'Telefone inválido';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          _SectionLabel(icon: Icons.alternate_email, text: 'Email', requiredMark: true),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: _input('consultor@ademicon.com.br'),
                            validator: (v) {
                              final msg = _req(v, 'Email');
                              if (msg != null) return msg;
                              final ok = EmailValidator.validate(v!.trim());
                              return ok ? null : 'Email inválido';
                            },
                          ),
                          const SizedBox(height: 12),

                          _SectionLabel(icon: Icons.tag, text: 'Matrícula', requiredMark: false, hintExtra: '(opcional)'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _matCtrl,
                            textInputAction: TextInputAction.done,
                            decoration: _input('Ex: 001'),
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  SizedBox(
                    height: 52,
                    width: double.infinity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                          colors: [_brandRed, _brandRedDark],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 3))],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : _submit,
                        icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
                        label: _loading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Cadastrar Consultor',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _input(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black38),
      filled: true,
      fillColor: _fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radiusField),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radiusField),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radiusField),
        borderSide: const BorderSide(color: _brandRed),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool requiredMark;
  final String? hintExtra;
  const _SectionLabel({
    required this.icon,
    required this.text,
    required this.requiredMark,
    this.hintExtra,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(color: Color(0xFFFFE9E7), shape: BoxShape.circle),
          child: Icon(icon, size: 16, color: Color(0xFFE24B3C)),
        ),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
        if (requiredMark) const Text(' *', style: TextStyle(color: Colors.red)),
        if (hintExtra != null) ...[
          const SizedBox(width: 6),
          Text(hintExtra!, style: const TextStyle(color: Colors.black45, fontSize: 12)),
        ],
      ],
    );
  }
}
