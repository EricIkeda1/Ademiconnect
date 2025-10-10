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

        final credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: senha);
        print('✅ Usuário criado: ${credential.user!.uid}');

        await FirebaseFirestore.instance
            .collection('gestor')
            .doc(credential.user!.uid)
            .set({
          'nome': _nomeCtrl.text.trim(),
          'email': email,
          'tipo': 'consultor',
          'uid': credential.user!.uid,
          'gestorId': gestorId,
          'data_criacao': FieldValue.serverTimestamp(),
        });

        await FirebaseFirestore.instance
            .collection('consultores')
            .doc(credential.user!.uid)
            .set({
          'nome': _nomeCtrl.text.trim(),
          'telefone': _telefoneCtrl.text,
          'email': email,
          'matricula': _matriculaCtrl.text.trim(),
          'gestorId': gestorId,
          'data_cadastro': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Consultor cadastrado com sucesso!')),
        );
        _limparCampos();
      } on FirebaseAuthException catch (e) {
        print('❌ Auth error: $e');
        String mensagem = 'Erro: ${e.message}';
        if (e.code == 'email-already-in-use') {
          mensagem = 'E-mail já cadastrado';
        } else if (e.code == 'weak-password') {
          mensagem = 'Senha muito fraca';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensagem)),
        );
      } on FirebaseException catch (e) {
        print('❌ Firebase error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Erro ao salvar no banco. Verifique: conexão, regras do Firestore ou tente novamente.',
            ),
          ),
        );
      } catch (e, stack) {
        print('❌ Erro inesperado: $e\n$stack');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: ${e.toString()}')),
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

  // Gera as iniciais do nome
  String get _iniciais {
    final nome = _nomeCtrl.text.trim();
    if (nome.isEmpty) return 'CN';
    final parts = nome.split(' ').where((p) => p.isNotEmpty).take(2).toList();
    return parts.map((p) => p[0]).join().toUpperCase();
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
                const Text(
                  "Gerenciar Consultores",
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Cadastre novos consultores no sistema",
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 16),
                Center(
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFFEAEAEA),
                    child: Text(
                      _iniciais,
                      style: const TextStyle(color: Colors.black),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
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
                    if (raw.length < 11) return "Telefone inválido";
                    return null;
                  },
                ),
                const SizedBox(height: 12),
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
                TextFormField(
                  controller: _matriculaCtrl,
                  decoration: const InputDecoration(
                    labelText: "Número da matrícula (opcional)",
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _cadastrarConsultor,
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Cadastrar Consultor"),
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
