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
  // Paleta centralizada
  static const branco = Color(0xFFFFFFFF);
  static const preto09 = Color(0xFF231F20);
  static const vermelhoClaro = Color(0xFFEA3124);
  static const vermelhoTopoB = Color(0xFFCC1F17);
  static const corBorda = Color(0xFF3A2E2E);
  static const corTexto = Color(0xFF2F2B2B);

  final SupabaseClient _sb = Supabase.instance.client;

  // Estado
  String _nome = 'Gestor';               // curto (AppBar)
  String _nomeCompleto = 'Gestor';       // completo (cartão)
  String _email = '';
  String _idUsuario = '';
  final String _tipoCargo = 'Gestor';    // fixo, não busca do Supabase
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregarPerfil();
  }

  // Regra: AppBar mostra somente o primeiro nome se houver mais de uma palavra.
  String _nomeCurto(String completo) {
    final parts = completo.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return completo.trim();
    if (parts.length > 1) return parts.first; // "Augusto tal tal tal" -> "Augusto"
    return parts.first;
  }

  String _iniciais(String nome) {
    final p = nome.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (p.isEmpty) return 'US';
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
      final uid = user.id;
      _idUsuario = uid;

      // Query sem campo 'tipo'
      final data = await _sb
          .from('gestor')
          .select('id, email, nome')
          .eq('id', uid)
          .maybeSingle();

      final authEmail = user.email ?? '';
      final nomeFromDb = data != null ? (data['nome'] as String?) : null;
      final emailFromDb = data != null ? (data['email'] as String?) : null;

      final emailFinal = emailFromDb ?? authEmail;
      final nomeFinal = nomeFromDb ?? (emailFinal.isNotEmpty ? emailFinal : 'Gestor');

      setState(() {
        _nomeCompleto = nomeFinal;       // nome cheio (cartão)
        _nome = _nomeCurto(nomeFinal);   // nome curto (AppBar)
        _email = emailFinal;
        _carregando = false;
      });
    } catch (_) {
      setState(() => _carregando = false);
    }
  }

  void _goLogin() {
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  // Abre o cartão alinhado à esquerda da AppBar, compatível com mobile
  Future<void> _abrirMenuPerfilEsquerda(TapDownDetails details) async {
    if (!mounted) return;

    final overlay = Overlay.of(context);
    if (overlay == null) return;

    final screen = MediaQuery.of(context).size;
    const desiredWidth = 310.0;
    final cardWidth =
        screen.width < desiredWidth + 24 ? screen.width * 0.92 : desiredWidth;

    final appBarTopLeft =
        (context.findRenderObject() as RenderBox?)?.localToGlobal(Offset.zero) ??
            Offset.zero;
    const leftPadding = 8.0; // idem ao padding do título
    final leftX = leftPadding;
    final topY = appBarTopLeft.dy + kToolbarHeight;

    final position = RelativeRect.fromLTRB(
      leftX,
      topY,
      screen.width - leftX - cardWidth,
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
                  iniciais: _carregando ? '...' : _iniciais(_nomeCompleto),
                  nomeCompleto: _carregando ? 'Carregando' : _nomeCompleto,
                  subtitulo: _tipoCargo, // fixo
                  idUsuario: _idUsuario,
                  email: _email,
                  telefone: '',
                  localizacao: '',
                  onSair: () {
                    Navigator.pop(context);
                    _goLogin();
                  },
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
        padding: const EdgeInsets.fromLTRB(8, 4, 12, 4), // left=8, right=12
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
                  // Bloco do perfil à esquerda
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: _abrirMenuPerfilEsquerda,
                    child: Row(
                      children: [
                        // Avatar com status
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFE4E1), Color(0xFFFFF5F5)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(color: corBorda, width: 1),
                            boxShadow: const [
                              BoxShadow(
                                  color: Color(0x14000000),
                                  blurRadius: 3,
                                  offset: Offset(0, 1)),
                            ],
                          ),
                          child: Stack(
                            children: [
                              Center(
                                child: Text(
                                  _carregando ? '...' : _iniciais(_nome),
                                  style: const TextStyle(
                                      color: vermelhoClaro,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800),
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
                                        color: Colors.white, width: 1.5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4), // gap avatar→texto
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            // AppBar: somente primeiro nome
                            _NomeAppBar(),
                            SizedBox(height: 1),
                            Text('Gestor',
                                style: TextStyle(
                                    color: vermelhoClaro, fontSize: 11)), // fixo
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

  // ---------------- Card (com ênfase nos três itens) ----------------
  Widget _buildPerfilCard({
    required String iniciais,
    required String nomeCompleto,
    required String subtitulo, // será 'Gestor' fixo
    required String idUsuario,
    required String email,
    String? telefone,
    String? localizacao,
    required VoidCallback onSair,
  }) {
    const cinzaItem = Color(0xFFF7F7F7);
    const bordaLeve = Color(0x143A2E2E);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 310, // permanece 310; no mobile limitamos via ConstrainedBox
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Color(0x1A000000), blurRadius: 10, offset: Offset(0, 6))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Topo vermelho
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0x22FFFFFF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Gestor',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const SizedBox(width: 12),
                      // Avatar grande
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
                                offset: Offset(0, 1))
                          ],
                        ),
                        child: Center(
                          child: Text(iniciais,
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFB71C1C))),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Card: NOME COMPLETO
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
                              Text(subtitulo,
                                  style: const TextStyle(
                                      color: Color(0xFFEDEDED),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
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

            // Divisor suave
            Container(height: 14, color: const Color(0xFFF6F6F6)),

            // Lista de itens (3 com ênfase)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                children: [
                  _perfilRow(
                      bg: cinzaItem,
                      icon: Icons.tag,
                      titulo: 'ID do Usuário',
                      valor: idUsuario,
                      enfase: true),
                  _perfilRow(
                      bg: cinzaItem,
                      icon: Icons.alternate_email,
                      titulo: 'Email Corporativo',
                      valor: email,
                      enfase: true),
                  _perfilRow(
                      bg: cinzaItem,
                      icon: Icons.badge_outlined,
                      titulo: 'Cargo',
                      valor: 'Gestor',
                      enfase: true), // fixo
                  if (telefone != null && telefone!.isNotEmpty)
                    _perfilRow(
                        bg: cinzaItem,
                        icon: Icons.call_outlined,
                        titulo: 'Telefone',
                        valor: telefone!),
                  if (localizacao != null && localizacao!.isNotEmpty)
                    _perfilRow(
                        bg: cinzaItem,
                        icon: Icons.location_on_outlined,
                        titulo: 'Localização',
                        valor: localizacao!),
                ],
              ),
            ),

            // Botão sair
            Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: bordaLeve, width: 1)),
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
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: onSair,
                  icon: const Icon(Icons.logout_outlined),
                  label: const Text('Sair da Conta',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper com suporte a ênfase
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
            color: enfase ? const Color(0x1AEA3124) : const Color(0x0F000000),
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
                Text(titulo,
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF7A7A7A),
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(
                  valor,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 15,
                      color: const Color(0xFF231F20),
                      fontWeight: pesoValor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Extrai o nome curto da instância pai sem reconstruir toda a AppBar.
/// Mantém o texto da linha superior desacoplado do estado visual.
class _NomeAppBar extends StatelessWidget {
  const _NomeAppBar();

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_GestorNavbarState>();
    final carregando = state?._carregando ?? true;
    final nome = state?._nome ?? '...';
    return Text(
      carregando ? '...' : nome,
      style: const TextStyle(
        color: _GestorNavbarState.preto09,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
