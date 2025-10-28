// lib/telas/widgets/custom_navbar.dart
import 'package:flutter/material.dart';

class CustomNavbar extends StatelessWidget implements PreferredSizeWidget {
  final String nome;
  final String cargo;
  final TabController? tabController;
  final List<Tab>? tabs;
  final bool tabsNoAppBar;
  final VoidCallback? onLogout;
  final double collapseProgress;
  final bool hideAvatar;

  const CustomNavbar({
    super.key,
    required this.nome,
    required this.cargo,
    this.tabController,
    this.tabs,
    this.tabsNoAppBar = true,
    this.onLogout,
    this.collapseProgress = 0.0,
    this.hideAvatar = false,
  });

  @override
  Widget build(BuildContext context) {
    const double baseToolbar = 68.0;
    const double minToolbar = 56.0;

    final double t = collapseProgress.clamp(0.0, 1.0);
    final double toolbarHeight = lerpDouble(baseToolbar, minToolbar, t);
    final double logoHeight = lerpDouble(32, 24, t);

    const Color cinzaBrand = Color(0xFF939598);
    final scale = MediaQuery.of(context).textScaleFactor.clamp(1.0, 1.3);
    final double nomeSize = 16.0 * scale;
    final double cargoSize = 12.0 * scale;

    return PreferredSize(
      preferredSize: Size.fromHeight(
          toolbarHeight + (tabsNoAppBar && tabs != null ? 60 : 0)),
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
                child: Image.asset('assets/Logo.png', fit: BoxFit.contain),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!hideAvatar)
                      const CircleAvatar(
                        radius: 16,
                        backgroundColor: Color(0xFF231F20),
                        child: Icon(Icons.person, size: 16, color: Colors.white),
                      ),
                    if (!hideAvatar) const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          nome,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                            fontSize: nomeSize,
                          ),
                        ),
                        Text(
                          cargo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: cargoSize,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.logout, size: 14),
                  label: const Text('Sair'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF231F20),
                    side: const BorderSide(color: Color(0xFF231F20)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    textStyle:
                        const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed:
                      onLogout ?? () => Navigator.pushReplacementNamed(context, '/login'),
                ),
              ),
            ),
          ],
        ),
        bottom: tabsNoAppBar && tabs != null && tabController != null
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
                      controller: tabController,
                      isScrollable: true,
                      labelPadding:
                          const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      labelColor: Colors.black,
                      unselectedLabelColor: Colors.white,
                      labelStyle:
                          const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      unselectedLabelStyle:
                          const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      indicator: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: cinzaBrand, width: 1.4),
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
                      tabs: tabs!,
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  @override
  Size get preferredSize =>
      Size.fromHeight(68 + (tabsNoAppBar && tabs != null ? 60 : 0));
}

double lerpDouble(double a, double b, double t) => a + (b - a) * t;
