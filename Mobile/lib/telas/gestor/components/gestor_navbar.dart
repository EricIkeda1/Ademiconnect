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
  static const vermelhoTopoB = Color(0xFFCC1F17);
  static const corBorda = Color(0xFF3A2E2E);

  final SupabaseClient _sb = Supabase.instance.client;

  String _nome = 'Gestor';
  String _nomeCompleto = 'Gestor';
  String _email = '';
  String _idUsuario = '';
  final String _tipoCargo = 'Gestor';
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregarPerfil();
  }

  String _nomeCurto(String completo) {
    final parts = completo
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return completo.trim();
    if (parts.length > 1) return parts.first;
    return parts.first;
  }

  String _iniciais(String nome) {
    final p = nome
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (p.isEmpty) return 'GE';
    if (p.length == 1) return p.first.substring(0, 1).toUpperCase();
    return (p.first.substring(0, 1) + p.last.substring(0, 1)).toUpperCase();
  }

  Future<void> _carregarPerfil() async {
    try {
      final user = _sb.auth.currentUser;
      if (user == null) {
        setState(() => _carregando = false);
        return;
      }
      _idUsuario = user.id;

      final data = await _sb
          .from('gestor')
          .select('nome, email')
          .eq('id', _idUsuario)
          .maybeSingle();

      final nomeFromDb = data != null ? (data['nome'] as String?) : null;
      final emailFromDb = data != null ? (data['email'] as String?) : null;

      final nomeFinal =
          (nomeFromDb != null && nomeFromDb.trim().isNotEmpty)
              ? nomeFromDb.trim()
              : 'Gestor';

      setState(() {
        _nomeCompleto = nomeFinal;
        _nome = _nomeCurto(nomeFinal);
        _email = emailFromDb ?? '';
        _carregando = false;
      });
    } catch (_) {
      setState(() => _carregando = false);
    }
  }

  Future<void> _goLogin() async {
    await _sb.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/login',
      (route) => false,
    );
  }

  Future<void> _abrirMenuPerfilEsquerda(TapDownDetails details) async {
    if (!mounted) return;

    final screen = MediaQuery.of(context).size;
    final paddingTop = MediaQuery.of(context).padding.top;
    const gutterTop = 6.0;
    const leftPadding = 8.0;

    const desiredWidth = 310.0;
    final cardWidth =
        screen.width < desiredWidth + 24 ? screen.width * 0.92 : desiredWidth;

    final position = RelativeRect.fromLTRB(
      leftPadding,
      paddingTop + kToolbarHeight + gutterTop,
      screen.width - leftPadding - cardWidth,
      0,
    );

    await showMenu<int>(
      context: context,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: corBorda, width: 1),
      ),
      position: position,
      items: [
        PopupMenuItem<int>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: Material(
            type: MaterialType.transparency,
            child: SafeArea(
              minimum: const EdgeInsets.only(bottom: 8),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: cardWidth,
                  maxHeight: screen.height * 0.8,
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: _buildPerfilCard(
                    iniciais: _iniciais(_nomeCompleto),
                    nomeCompleto: _nomeCompleto,
                    cargo: _tipoCargo,
                    idUsuario: _idUsuario,
                    email: _email,
                    onSair: () async {
                      Navigator.pop(context); 
                      await _goLogin();      
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      backgroundColor: branco,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
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
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: _abrirMenuPerfilEsquerda,
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFFFE4E1),
                                Color(0xFFFFF5F5)
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(color: corBorda, width: 1),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x14000000),
                                blurRadius: 3,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              Center(
                                child: Text(
                                  _iniciais(_nomeCompleto),
                                  style: const TextStyle(
                                    color: vermelhoClaro,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2ECC71),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _nome,
                              style: const TextStyle(
                                color: preto09,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 1),
                            const Text(
                              'Gestor',
                              style: TextStyle(
                                color: vermelhoClaro,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPerfilCard({
    required String iniciais,
    required String nomeCompleto,
    required String cargo,
    required String idUsuario,
    required String email,
    required VoidCallback onSair,
  }) {
    const cinzaItem = Color(0xFFF7F7F7);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 310,
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 10,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [vermelhoClaro, vermelhoTopoB],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const SizedBox(width: 12),
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: Colors.white, width: 5),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 3,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            iniciais,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFB71C1C),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nomeCompleto,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                cargo,
                                style: const TextStyle(
                                  color: Color(0xFFEDEDED),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            Container(
              height: 14,
              color: const Color(0xFFF6F6F6),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              child: Column(
                children: [
                  _perfilRow(
                    bg: cinzaItem,
                    icon: Icons.tag,
                    titulo: 'ID do Usuário',
                    valor: idUsuario,
                    enfase: true,
                  ),
                  _perfilRow(
                    bg: cinzaItem,
                    icon: Icons.alternate_email,
                    titulo: 'Email Corporativo',
                    valor: email,
                    enfase: true,
                  ),
                  _perfilRow(
                    bg: cinzaItem,
                    icon: Icons.badge_outlined,
                    titulo: 'Cargo',
                    valor: cargo,
                    enfase: true,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0x143A2E2E)),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: vermelhoClaro,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: onSair,
                  icon: const Icon(Icons.logout_outlined),
                  label: const Text(
                    'Sair da Conta',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _perfilRow({
    required Color bg,
    required IconData icon,
    required String titulo,
    required String valor,
    bool enfase = false,
  }) {
    final Color borda =
        enfase ? const Color(0x33EA3124) : const Color(0x143A2E2E);
    final Color bgIcon = enfase ? const Color(0x1AEA3124) : bg;
    final Color corIcone =
        enfase ? vermelhoClaro : const Color(0xFF2F2B2B);
    final FontWeight pesoValor =
        enfase ? FontWeight.w800 : FontWeight.w700;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color:
                enfase ? const Color(0x1AEA3124) : const Color(0x0F000000),
            blurRadius: enfase ? 6 : 3,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: borda, width: enfase ? 1.5 : 1),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: bgIcon,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: corIcone, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF7A7A7A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  valor.isEmpty ? '—' : valor,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    color: const Color(0xFF231F20),
                    fontWeight: pesoValor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
