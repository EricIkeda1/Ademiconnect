import 'package:flutter/material.dart';

class DesignarTrabalhoTab extends StatefulWidget {
  const DesignarTrabalhoTab({super.key});

  @override
  State<DesignarTrabalhoTab> createState() => _DesignarTrabalhoTabState();
}

class _DesignarTrabalhoTabState extends State<DesignarTrabalhoTab> {
  final _formKey = GlobalKey<FormState>();
  final _areaCtrl = TextEditingController();
  DateTime? _data;
  String? _consultorSel;
  final _consultores = const ["João Silva", "Pedro Costa"];

  @override
  void dispose() {
    _areaCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _data ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      helpText: "Selecione a data do trabalho",
    );
    if (picked != null) setState(() => _data = picked);
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Área designada com sucesso!')),
      );
      _formKey.currentState!.reset();
      setState(() {
        _consultorSel = null;
        _data = null;
      });
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
              const Text("Designar Áreas de Trabalho", style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text("Defina as ruas e regiões onde cada consultor deve trabalhar",
                  style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _consultorSel,
                items: _consultores.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _consultorSel = v),
                decoration: const InputDecoration(labelText: "Consultor *", border: OutlineInputBorder()),
                validator: (v) => v == null ? "Selecione um consultor" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _areaCtrl,
                decoration: const InputDecoration(
                  labelText: "Área de Trabalho / Rua Designada *",
                  hintText: "Ex: Rua das Flores, Centro - Foco em comércio local",
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? "Descreva a área" : null,
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: "Data do Trabalho *",
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    _data == null
                        ? "Selecione uma data"
                        : "${_data!.day.toString().padLeft(2, '0')}/${_data!.month.toString().padLeft(2, '0')}/${_data!.year}",
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "Dica: O consultor receberá esta informação e verá no dashboard a área específica para trabalhar no dia selecionado.",
                  style: TextStyle(color: Colors.black54),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _submit,
                  child: const Text("Designar Área de Trabalho"),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
