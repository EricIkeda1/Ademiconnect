import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'cadastrar_consultor.dart';
import 'vendas.dart';

const _brandRed = Color(0xFFEA3124);
const _brandRedDark = Color(0xFFD12B20);
const _bg = Color(0xFFF6F6F8);
const _textPrimary = Color(0xFF222222);
const _muted = Color(0xFF8F8F95);

class BrPhoneTextInputFormatter extends TextInputFormatter {
  const BrPhoneTextInputFormatter();
  static final _digitsOnly = RegExp(r'\D');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final raw = newValue.text.replaceAll(_digitsOnly, '');
    final String mask = raw.length > 10 ? '(##) #####-####' : '(##) ####-####';
    final formatted = _applyMask(raw, mask);
    final sel = TextSelection.collapsed(offset: formatted.length);
    return TextEditingValue(text: formatted, selection: sel, composing: TextRange.empty);
  }

  String _applyMask(String digits, String mask) {
    final buf = StringBuffer();
    int i = 0;
    for (int m = 0; m < mask.length && i < digits.length; m++) {
      final ch = mask[m];
      if (ch == '#') { buf.write(digits[i]); i++; } else { buf.write(ch); }
    }
    return buf.toString();
  }

  String formatStatic(String input) {
    final raw = input.replaceAll(_digitsOnly, '');
    if (raw.isEmpty) return '';
    final mask = raw.length > 10 ? '(##) #####-####' : '(##) ####-####';
    return _applyMask(raw, mask);
  }
}

class ConsultoresRoot extends StatefulWidget {
  final VoidCallback? onCadastrar;
  final PageController? pageController; 

  const ConsultoresRoot({super.key, this.onCadastrar, this.pageController});

  @override
  State<ConsultoresRoot> createState() => _ConsultoresRootState();
}

class _ConsultoresRootState extends State<ConsultoresRoot> {
  static const _pageSize = 10;

  final _client = Supabase.instance.client;
  final _phoneFmt = const BrPhoneTextInputFormatter();

  final List<_ConsultorView> _consultores = [];
  int _visibleCount = 0;
  int _totalCount = 0;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchFirstPage();
  }

  Future<void> _fetchFirstPage() async {
    setState(() {
      _consultores.clear();
      _visibleCount = 0;
      _totalCount = 0;
      _loading = true;
      _error = null;
    });
    try {
      await Future.wait([_fetchTotalCount(), _fetchPage()]);
    } catch (e) {
      setState(() => _error = 'Erro ao carregar: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchTotalCount() async {
    final total = await _client.from('consultores').count(CountOption.exact);
    setState(() => _totalCount = total);
  }

  Future<void> _fetchPage() async {
    final start = _visibleCount;
    final end = _visibleCount + _pageSize - 1;

    final dynamic result = await _client
        .from('consultores')
        .select('id, uid, nome, email, telefone, matricula')
        .order('nome', ascending: true)
        .range(start, end);

    final List<dynamic> raw = result as List<dynamic>;
    final rows = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();

    final mapped = rows.map((r) => _ConsultorView(
          r['id'].toString(),
          (r['uid'] as String?) ?? '',
          (r['nome'] as String?) ?? '',
          (r['matricula'] as String?) ?? '',
          (r['telefone'] as String?) ?? '',
          (r['email'] as String?) ?? '',
        ));

    setState(() {
      _consultores.addAll(mapped.toList());
      _visibleCount = _consultores.length;
    });
  }

  Future<void> _fetchMore() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _fetchPage();
    } catch (e) {
      setState(() => _error = 'Erro ao carregar mais: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCadastrarConsultor() async {
    if (widget.onCadastrar != null) {
      widget.onCadastrar!.call();
      return;
    }
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CadastrarConsultorPage()),
    );
    if (ok == true) {
      await _fetchFirstPage();
    }
  }

  Future<void> _openEditarConsultor(_ConsultorView c) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (ctx) => _EditarConsultorDialog(consultor: c, phoneFmt: _phoneFmt),
    );
    if (changed == true) {
      await _fetchFirstPage();
    }
  }

  Future<void> _confirmarExcluir(_ConsultorView c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (ctx) => _ConfirmExcluirDialog(nome: c.nome),
    );
    if (confirmed != true) return;
    try {
      await _client.from('consultores').delete().eq('id', c.id);
      setState(() {
        _consultores.removeWhere((x) => x.id == c.id);
        _totalCount = (_totalCount - 1).clamp(0, 1 << 31);
        _visibleCount = _consultores.length;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Consultor excluído com sucesso'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao excluir: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _openDadosConsultor(_ConsultorView c) async {
    VendasPage.setSelectedConsultor(
      consultorId: c.id,
      consultorUid: c.uid,
      nomeConsultor: c.nome,
    );

    final pc = widget.pageController;
    if (pc != null) {
      await pc.animateToPage(1, duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    } else {
    }
  }

  @override
  Widget build(BuildContext context) {
    final showLoadMore = _visibleCount < _totalCount;
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchFirstPage,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.group, color: _brandRed, size: 20),
                    const SizedBox(width: 6),
                    const Text('Consultores', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: _textPrimary)),
                    const Spacer(),
                    _ChipTotal(count: _totalCount),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _openCadastrarConsultor,
                    icon: const Icon(Icons.person_add_alt_1_outlined, color: Colors.white, size: 20),
                    label: const Text('Cadastrar Novo Consultor', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brandRed,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
                if (_loading && _visibleCount == 0)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ..._consultores.map(
                  (c) => _ConsultorCard(
                    c: c,
                    phoneFmt: _phoneFmt,
                    onEditar: () => _openEditarConsultor(c),
                    onApagar: () => _confirmarExcluir(c),
                    onAbrirDados: () => _openDadosConsultor(c),
                  ),
                ),
                if (showLoadMore)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Center(
                      child: PillButton(
                        onPressed: _loading ? null : _fetchMore,
                        icon: const Icon(Icons.expand_more, size: 18, color: _brandRed),
                        label: 'Ver mais (${_totalCount - _visibleCount})',
                      ),
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

class _ConsultorView {
  final String id, uid, nome, matricula, telefone, email;
  _ConsultorView(this.id, this.uid, this.nome, this.matricula, this.telefone, this.email);
}

class _ConsultorCard extends StatelessWidget {
  final _ConsultorView c;
  final BrPhoneTextInputFormatter phoneFmt;
  final VoidCallback onEditar;
  final VoidCallback onApagar;
  final VoidCallback onAbrirDados;
  const _ConsultorCard({
    super.key,
    required this.c,
    required this.phoneFmt,
    required this.onEditar,
    required this.onApagar,
    required this.onAbrirDados,
  });

  @override
  Widget build(BuildContext context) {
    final fone = phoneFmt.formatStatic(c.telefone);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2))],
        border: Border.all(color: const Color(0x10A0A0A0), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AvatarRed(),
                const SizedBox(width: 10),
                Expanded(child: _NomeMatricula(nome: c.nome, matricula: c.matricula)),
                Row(
                  children: [
                    PillButton(
                      onPressed: onAbrirDados,
                      icon: const Icon(Icons.list_alt_outlined, size: 16, color: _brandRed),
                      label: 'Dados',
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    const SizedBox(width: 8),
                    PillIconButton(
                      onPressed: onEditar,
                      icon: Icons.edit_outlined,
                      radius: 10,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    PillIconButton(
                      onPressed: onApagar,
                      icon: Icons.delete_outline_rounded,
                      radius: 10,
                      size: 16,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.phone, size: 16, color: _muted),
                const SizedBox(width: 6),
                Text(fone.isEmpty ? '—' : fone, style: const TextStyle(color: Color(0xFF3E3E44), fontSize: 14)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.email_outlined, size: 16, color: _muted),
                const SizedBox(width: 6),
                Text(c.email, style: const TextStyle(color: Color(0xFF3E3E44), fontSize: 14)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarRed extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: _brandRed, borderRadius: BorderRadius.circular(12)),
      child: const Icon(Icons.person, color: Colors.white, size: 22),
    );
  }
}

class _NomeMatricula extends StatelessWidget {
  final String nome;
  final String matricula;
  const _NomeMatricula({required this.nome, required this.matricula});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(nome, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1E1E22))),
        const SizedBox(height: 4),
        Text('Mat. ${matricula.isEmpty ? '—' : matricula}', style: const TextStyle(fontSize: 12, color: Color(0xFF9A9AA0), height: 1.0)),
      ],
    );
  }
}

class PillButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget? icon;
  final String? label;
  final EdgeInsets? padding;
  final double radius;
  final bool dense;

  const PillButton({
    super.key,
    this.onPressed,
    this.icon,
    this.label,
    this.padding,
    this.radius = 10,
    this.dense = true,
  });

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) icon!,
        if (icon != null && label != null) const SizedBox(width: 6),
        if (label != null)
          Text(label!, style: const TextStyle(color: _brandRed, fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: 0.2)),
      ],
    );

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: _brandRed,
        backgroundColor: Colors.white,
        side: const BorderSide(color: _brandRed, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: child,
    );
  }
}

class PillIconButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final double size;
  final double radius;
  const PillIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.size = 16,
    this.radius = 10,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: _brandRed,
        backgroundColor: Colors.white,
        side: const BorderSide(color: _brandRed, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
        padding: const EdgeInsets.all(8),
        minimumSize: const Size(36, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Icon(icon, size: size, color: _brandRed),
    );
  }
}

class _ChipTotal extends StatelessWidget {
  final int count;
  const _ChipTotal({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: _brandRed, borderRadius: BorderRadius.circular(8)),
      alignment: Alignment.center,
      child: Text('$count consultores', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12, height: 1.0)),
    );
  }
}

class _EditarConsultorDialog extends StatefulWidget {
  final _ConsultorView consultor;
  final TextInputFormatter phoneFmt;
  const _EditarConsultorDialog({required this.consultor, required this.phoneFmt});

  @override
  State<_EditarConsultorDialog> createState() => _EditarConsultorDialogState();
}

class _EditarConsultorDialogState extends State<_EditarConsultorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomeCtrl;
  late final TextEditingController _telCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _matCtrl;
  bool _saving = false;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _nomeCtrl = TextEditingController(text: widget.consultor.nome);
    final fmt = const BrPhoneTextInputFormatter();
    _telCtrl = TextEditingController(text: fmt.formatStatic(widget.consultor.telefone));
    _emailCtrl = TextEditingController(text: widget.consultor.email);
    _matCtrl = TextEditingController(text: widget.consultor.matricula.isEmpty ? '' : widget.consultor.matricula);
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _telCtrl.dispose();
    _emailCtrl.dispose();
    _matCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE3E3E6))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE3E3E6))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _brandRed)),
      );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final telDigits = _telCtrl.text.replaceAll(RegExp(r'\D'), '');
      await _client
          .from('consultores')
          .update({
            'nome': _nomeCtrl.text.trim(),
            'telefone': telDigits,
            'email': _emailCtrl.text.trim(),
            'matricula': _matCtrl.text.trim().isEmpty ? null : _matCtrl.text.trim(),
          })
          .eq('id', widget.consultor.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alterações salvas com sucesso'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao salvar: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.of(context).viewInsets.bottom;
    return WillPopScope(
      onWillPop: () async => !_saving,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.only(bottom: keyboard),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Material(
              color: const Color(0xFFFDFDFE),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(color: const Color(0xFFFFECEA), borderRadius: BorderRadius.circular(10)),
                              child: const Icon(Icons.edit, color: _brandRed),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Editar Consultor', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                  SizedBox(height: 2),
                                  Text('Atualize as informações do consultor abaixo', style: TextStyle(color: Colors.black54, fontSize: 13)),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Fechar',
                              onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                              icon: const Icon(Icons.close, color: Colors.black54),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _FieldLabel(icon: Icons.person_outline, text: 'Nome Completo', requiredMark: true),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _nomeCtrl,
                          textInputAction: TextInputAction.next,
                          decoration: _dec('Ex: João da Silva Santos'),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Nome é obrigatório' : null,
                        ),
                        const SizedBox(height: 10),
                        _FieldLabel(icon: Icons.phone_outlined, text: 'Telefone', requiredMark: true),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _telCtrl,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          decoration: _dec('(11) 98765-4321'),
                          inputFormatters: [widget.phoneFmt],
                          validator: (v) {
                            final raw = v?.replaceAll(RegExp(r'\D'), '') ?? '';
                            if (raw.isEmpty) return 'Telefone é obrigatório';
                            if (raw.length != 10 && raw.length != 11) return 'Telefone inválido';
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        _FieldLabel(icon: Icons.alternate_email, text: 'Email', requiredMark: true),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: _dec('consultor@ademicon.com.br'),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Email é obrigatório';
                            final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v.trim());
                            return ok ? null : 'Email inválido';
                          },
                        ),
                        const SizedBox(height: 10),
                        _FieldLabel(icon: Icons.tag, text: 'Matrícula', requiredMark: false, hintExtra: '(opcional)'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _matCtrl,
                          textInputAction: TextInputAction.done,
                          decoration: _dec('Ex: 001'),
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  side: const BorderSide(color: Color(0xFFE3E3E6)),
                                  backgroundColor: Colors.white,
                                ),
                                child: const Text('Cancelar'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 46,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [_brandRed, _brandRedDark],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 3))],
                                  ),
                                  child: ElevatedButton.icon(
                                    onPressed: _saving ? null : _save,
                                    icon: const Icon(Icons.save, color: Colors.white),
                                    label: _saving
                                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                        : const Text('Salvar Alterações', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
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
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool requiredMark;
  final String? hintExtra;

  const _FieldLabel({required this.icon, required this.text, required this.requiredMark, this.hintExtra});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(color: Color(0xFFFFE9E7), shape: BoxShape.circle),
          child: Icon(icon, size: 16, color: _brandRed),
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

class _ConfirmExcluirDialog extends StatelessWidget {
  final String nome;
  const _ConfirmExcluirDialog({required this.nome});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: const Color(0xFFFFECEA), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.delete_outline, color: _brandRed),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('Confirmar Exclusão', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                    IconButton(
                      tooltip: 'Fechar',
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close, color: Colors.black54),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _BannerBox(
                  color: const Color(0xFFFFE6E6),
                  border: const Color(0xFFFFC6C6),
                  icon: Icons.error_outline,
                  iconColor: const Color(0xFFD32F2F),
                  title: 'Tem certeza que deseja excluir este consultor?',
                  subtitle: 'Esta ação não pode ser desfeita.',
                  titleColor: const Color(0xFFD32F2F),
                ),
                const SizedBox(height: 10),
                _BannerBox(
                  color: const Color(0xFFFFF7E0),
                  border: const Color(0xFFFFE7A8),
                  icon: Icons.warning_amber_rounded,
                  iconColor: const Color(0xFFB78900),
                  title: 'Você já transferiu os leads deste consultor?',
                  subtitle: 'Certifique-se de que todos os leads foram transferidos antes de excluir.',
                  titleColor: const Color(0xFFB78900),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close, color: Colors.black87),
                    label: const Text('Cancelar', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: Color(0xFFE3E3E6)),
                      backgroundColor: Colors.white,
                    ),
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

class _BannerBox extends StatelessWidget {
  final Color color;
  final Color border;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Color titleColor;

  const _BannerBox({
    super.key,
    required this.color,
    required this.border,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: titleColor, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                const Text('Esta ação não pode ser desfeita.', style: TextStyle(color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
