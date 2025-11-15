import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CustomNavbar extends StatefulWidget implements PreferredSizeWidget {
  final String nomeCompleto;
  final String email;
  final String idUsuario;
  final String matricula;
  final DateTime dataCadastro;
  final TabController? tabController;
  final List<Tab>? tabs;
  final bool tabsNoAppBar;
  final VoidCallback? onLogout;
  final double collapseProgress;
  final bool hideAvatar;

  const CustomNavbar({
    super.key,
    required this.nomeCompleto,
    required this.email,
    required this.idUsuario,
    required this.matricula,
    required this.dataCadastro,
    this.tabController,
    this.tabs,
    this.tabsNoAppBar = true,
    this.onLogout,
    this.collapseProgress = 0.0,
    this.hideAvatar = false,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(68 + (tabsNoAppBar && tabs != null ? 60 : 0));

  @override
  State<CustomNavbar> createState() => _CustomNavbarState();
}

class _CustomNavbarState extends State<CustomNavbar> {
  static const branco = Color(0xFFFFFFFF);
  static const preto09 = Color(0xFF231F20);
  static const vermelho = Color(0xFFEA3124);
  static const vermelhoB = Color(0xFFCC1F17);
  static const corBorda = Color(0xFF3A2E2E);
  static const corTexto = Color(0xFF2F2B2B);

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
    if (p.isEmpty) return 'US';
    if (p.length == 1) return p.first.substring(0, 1).toUpperCase();
    return (p.first.substring(0, 1) + p.last.substring(0, 1)).toUpperCase();
  }

  String _fmtData(DateTime d) => DateFormat('dd/MM/yyyy HH:mm').format(d);

  Future<void> _abrirMenuPerfilEsquerda(
      TapDownDetails details, double popupWidth) async {
    final screen = MediaQuery.of(context).size;
    final paddingTop = MediaQuery.of(context).padding.top;
    const gutterTop = 6.0;
    const leftPadding = 8.0;

    final cardWidth =
        screen.width < popupWidth + 24 ? screen.width * 0.92 : popupWidth;

    final double leftX = leftPadding;
    final double topY = paddingTop + kToolbarHeight + gutterTop;

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
                    iniciais: _iniciais(widget.nomeCompleto),
                    nomeCompleto: widget.nomeCompleto,
                    cargo: 'Consultor',
                    idUsuario: widget.idUsuario,
                    email: widget.email,
                    matricula: widget.matricula,
                    dataCadastroFmt: _fmtData(widget.dataCadastro),
                    onSair: () async {
                      Navigator.pop(context);

                      if (widget.onLogout != null) {
                        widget.onLogout!();
                      } else {
                        await Supabase.instance.client.auth.signOut();
                        if (mounted) {
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            '/login',
                            (route) => false,
                          );
                        }
                      }
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
    const double baseToolbar = 68.0;
    const double minToolbar = 56.0;

    final double t = widget.collapseProgress.clamp(0.0, 1.0);
    final double toolbarHeight = lerpDouble(baseToolbar, minToolbar, t);
    final double logoHeight = lerpDouble(32, 24, t);

    const Color cinzaBrand = Color(0xFF939598);
    final scale =
        MediaQuery.of(context).textScaleFactor.clamp(1.0, 1.3);
    final double nomeSize = 16.0 * scale;
    final double cargoSize = 12.0 * scale;

    final nomeCurto = _nomeCurto(widget.nomeCompleto);

    return PreferredSize(
      preferredSize: Size.fromHeight(
        toolbarHeight +
            (widget.tabsNoAppBar && widget.tabs != null ? 60 : 0),
      ),
      child: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 3,
        shadowColor: Colors.black12,
        toolbarHeight: toolbarHeight,
        titleSpacing: 0,
        title: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: logoHeight,
                child:
                    Image.asset('assets/Logo.png', fit: BoxFit.contain),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) => _abrirMenuPerfilEsquerda(d, 340),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!widget.hideAvatar)
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
                            border:
                                Border.all(color: corBorda, width: 1),
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
                                  _iniciais(widget.nomeCompleto),
                                  style: const TextStyle(
                                    color: vermelho,
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
                      if (!widget.hideAvatar) const SizedBox(width: 4),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                nomeCurto,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                  fontSize: nomeSize,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Consultor',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: cargoSize,
                              color: vermelho,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        bottom: widget.tabsNoAppBar &&
                widget.tabs != null &&
                widget.tabController != null
            ? PreferredSize(
                preferredSize: const Size.fromHeight(60),
                child: Container(
                  color: cinzaBrand,
                  padding: const EdgeInsets.all(10),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TabBar(
                      controller: widget.tabController,
                      isScrollable: true,
                      labelPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      labelColor: Colors.black,
                      unselectedLabelColor: Colors.white,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      indicator: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: cinzaBrand,
                          width: 1.4,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 14,
                            spreadRadius: 2,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      splashBorderRadius: BorderRadius.circular(22),
                      automaticIndicatorColorAdjustment: false,
                      tabs: widget.tabs!,
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildPerfilCard({
    required String iniciais,
    required String nomeCompleto,
    required String cargo,
    required String idUsuario,
    required String email,
    required String matricula,
    required String dataCadastroFmt,
    required VoidCallback onSair,
  }) {
    const cinzaItem = Color(0xFFF7F7F7);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 340,
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
                  colors: [vermelho, vermelhoB],
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
            Container(height: 14, color: const Color(0xFFF6F6F6)),
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
                  _perfilRow(
                    bg: cinzaItem,
                    icon: Icons.event,
                    titulo: 'Registrado em',
                    valor: dataCadastroFmt,
                    enfase: true,
                  ),
                  _perfilRow(
                    bg: cinzaItem,
                    icon: Icons.badge,
                    titulo: 'Matrícula',
                    valor: matricula,
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
                    backgroundColor: vermelho,
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
        enfase ? vermelho : const Color(0xFF2F2B2B);
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
            color: enfase
                ? const Color(0x1AEA3124)
                : const Color(0x0F000000),
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
                  valor,
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

double lerpDouble(double a, double b, double t) => a + (b - a) * t;
