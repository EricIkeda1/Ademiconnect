import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GestorNavbar extends StatefulWidget implements PreferredSizeWidget {
  const GestorNavbar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  State<GestorNavbar> createState() => _GestorNavbarState();
}

class _GestorNavbarState extends State<GestorNavbar> {
  static const branco = Color(0xFFFFFFFF);
  static const preto09 = Color(0xFF231F20);
  static const vermelhoClaro = Color(0xFFEA3124);
  static const corBorda = Color(0xFF3A2E2E);
  static const corTexto = Color(0xFF2F2B2B);

  final SupabaseClient _sb = Supabase.instance.client;

  String _nome = 'Gestor';
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregarNomeGestor();
  }

  String _nomeCurto(String completo) {
    final parts = completo.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return completo.trim();
    if (parts.length == 1) return parts.first;
    final blacklist = {'filho', 'neto', 'junior', 'jr.', 'jr', 'sobrinho'};
    var last = parts.last;
    if (blacklist.contains(last.toLowerCase()) && parts.length >= 3) {
      last = parts[parts.length - 2];
    }
    return '${parts.first} $last';
  }

  Future<void> _carregarNomeGestor() async {
    try {
      final user = _sb.auth.currentUser;
      if (user == null) {
        setState(() {
          _nome = 'Gestor';
          _carregando = false;
        });
        return;
      }
      final uid = user.id;

      final data = await _sb
          .from('gestor')
          .select('nome')
          .eq('id', uid)
          .maybeSingle();

      final nomeBanco = (data != null ? data['nome'] as String? : null) ?? user.email ?? 'Gestor';

      setState(() {
        _nome = _nomeCurto(nomeBanco);
        _carregando = false;
      });
    } catch (_) {
      setState(() {
        _nome = 'Gestor';
        _carregando = false;
      });
    }
  }

  void _goLogin() {
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      backgroundColor: branco,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: SizedBox(
          height: kToolbarHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const IgnorePointer(
                ignoring: true,
                child: Image(
                  image: AssetImage('assets/Logo.png'),
                  height: 34,
                  fit: BoxFit.contain,
                ),
              ),

              Row(
                children: [
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _carregando ? '...' : _nome,
                            style: const TextStyle(
                              color: preto09,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_carregando)
                            const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(strokeWidth: 1.8),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      const Text('Gestor', style: TextStyle(color: vermelhoClaro, fontSize: 11)),
                    ],
                  ),
                  const Spacer(),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _goLogin,
                      hoverColor: const Color(0x0F000000),
                      child: Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: branco,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: corBorda, width: 1.1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.logout_outlined, size: 17, color: corTexto),
                            SizedBox(width: 6),
                            Text(
                              'Sair',
                              style: TextStyle(
                                color: corTexto,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
