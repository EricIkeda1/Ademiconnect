import 'package:flutter/material.dart';

class ConsultoresTab extends StatefulWidget {
  const ConsultoresTab({super.key});

  @override
  State<ConsultoresTab> createState() => _ConsultoresTabState();
}

class _ConsultoresTabState extends State<ConsultoresTab> {
  final _formKey = GlobalKey<FormState>();
  final _nomeCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  final _fotoCtrl = TextEditingController();

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _senhaCtrl.dispose();
    _fotoCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Consultor cadastrado!')),
      );
      _formKey.currentState!.reset();
      _nomeCtrl.clear();
      _senhaCtrl.clear();
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
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("Gerenciar Consultores", style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text("Cadastre novos consultores no sistema", style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 16),
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
                            .map((p) => p)
                            .join()
                            .toUpperCase(),
                    style: const TextStyle(color: Colors.black),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nomeCtrl,
                decoration: const InputDecoration(labelText: "Nome Completo *", border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? "Informe o nome completo" : null,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _senhaCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: "Senha *", border: OutlineInputBorder()),
                validator: (v) {
                  if (v == null || v.isEmpty) return "Informe a senha";
                  if (v.length < 6) return "Mínimo 6 caracteres";
                  return null;
                },
              ),
              const SizedBox(height: 12),
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
            ]),
          ),
        ),
      ),
    );
  }
}
