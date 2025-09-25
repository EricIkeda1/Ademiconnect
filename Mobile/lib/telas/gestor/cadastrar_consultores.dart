import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para inputFormatters
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart'; // Telefone
import 'package:email_validator/email_validator.dart'; // E-mail

class ConsultoresTab extends StatefulWidget {
  const ConsultoresTab({super.key});

  @override
  State<ConsultoresTab> createState() => _ConsultoresTabState();
}

class _ConsultoresTabState extends State<ConsultoresTab> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nomeCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  final _matriculaCtrl = TextEditingController(); // opcional
  final _fotoCtrl = TextEditingController();

  // Máscara de telefone no padrão brasileiro: (99) 99999-9999
  final _telefoneMask = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {'#': RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.eager,
  );

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _telefoneCtrl.dispose();
    _emailCtrl.dispose();
    _senhaCtrl.dispose();
    _matriculaCtrl.dispose();
    _fotoCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      // Aqui pode integrar com backend/Firebase conforme necessário.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Consultor cadastrado!')),
      );

      // Reset do formulário e limpeza dos controllers
      _formKey.currentState!.reset();
      _nomeCtrl.clear();
      _telefoneCtrl.clear();
      _emailCtrl.clear();
      _senhaCtrl.clear();
      _matriculaCtrl.clear();
      _fotoCtrl.clear();

      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Gerenciar Consultores", style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text("Cadastre novos consultores no sistema", style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 16),

                // Avatar com iniciais do nome
                Center(
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFFEAEAEA),
                    child: Text(
                      _nomeCtrl.text.isEmpty
                          ? "CN"
                          : _nomeCtrl.text
                              .trim()
                              .split(' ')
                              .where((p) => p.isNotEmpty)
                              .take(2)
                              .map((p) => p[0])
                              .join()
                              .toUpperCase(),
                      style: const TextStyle(color: Colors.black),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Nome
                TextFormField(
                  controller: _nomeCtrl,
                  decoration: const InputDecoration(
                    labelText: "Nome Completo *",
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? "Informe o nome completo" : null,
                  onChanged: (_) => setState(() {}),
                ),

                const SizedBox(height: 12),

                // Telefone
                TextFormField(
                  controller: _telefoneCtrl,
                  decoration: const InputDecoration(
                    labelText: "Telefone *",
                    hintText: "(11) 91234-5678",
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [_telefoneMask],
                  validator: (v) {
                    final raw = _telefoneMask.getUnmaskedText();
                    if (raw.isEmpty) return "Informe o telefone";
                    // Validação simples: 11 dígitos (DDD + 9 + número)
                    if (raw.length < 11) return "Telefone inválido";
                    return null;
                  },
                ),

                const SizedBox(height: 12),

                // E-mail
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                    labelText: "E-mail *",
                    hintText: "nome@empresa.com",
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return "Informe o e-mail";
                    if (!EmailValidator.validate(v.trim())) return "E-mail inválido";
                    return null;
                  },
                ),

                const SizedBox(height: 12),

                // Senha
                TextFormField(
                  controller: _senhaCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Senha *",
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return "Informe a senha";
                    if (v.length < 6) return "Mínimo 6 caracteres";
                    return null;
                  },
                ),

                const SizedBox(height: 12),

                // Matrícula (opcional)
                TextFormField(
                  controller: _matriculaCtrl,
                  decoration: const InputDecoration(
                    labelText: "Número da matrícula (opcional)",
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  // Sem validator obrigatório: é opcional
                ),

                const SizedBox(height: 12),

                // URL da foto (opcional) — mantido
                TextFormField(
                  controller: _fotoCtrl,
                  decoration: const InputDecoration(
                    labelText: "URL da foto (opcional)",
                    hintText: "https://exemplo.com/foto.jpg",
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _submit,
                    child: const Text("Cadastrar Consultor"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
