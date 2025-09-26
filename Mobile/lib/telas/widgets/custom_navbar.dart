import 'package:flutter/material.dart';

class CustomNavbar extends StatelessWidget implements PreferredSizeWidget {
  final String nome;
  final String cargo;
  final List<Tab>? tabs;
  final bool tabsNoAppBar;
  final VoidCallback? onLogout;

  final double collapseProgress;

  const CustomNavbar({
    super.key,
    required this.nome,
    required this.cargo,
    this.tabs,
    this.tabsNoAppBar = true,
    this.onLogout,
    this.collapseProgress = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    const double baseToolbar = 68.0;
    const double minToolbar = 56.0;

    final double t = collapseProgress.clamp(0.0, 1.0);
    final double toolbarHeight = lerpDouble(baseToolbar, minToolbar, t);
    final double logoHeight = lerpDouble(32, 24, t);

    return PreferredSize(
      preferredSize:
          Size.fromHeight(toolbarHeight + (tabsNoAppBar && tabs != null ? 48 : 0)),
      child: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        toolbarHeight: toolbarHeight,
        title: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                height: logoHeight,
                child: Image.asset(
                  'assets/Logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.black12,
                      child: Icon(Icons.person, size: 16, color: Colors.black87),
                    ),
                    const SizedBox(width: 6),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          nome,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          cargo,
                          style: const TextStyle(
                            fontSize: 11,
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
                padding: const EdgeInsets.only(right: 12),
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black87,
                    side: const BorderSide(color: Colors.black26),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  onPressed:
                      onLogout ?? () => Navigator.pushReplacementNamed(context, '/login'),
                  child: const Text('Sair'),
                ),
              ),
            ),
          ],
        ),
        bottom: tabsNoAppBar && tabs != null
            ? PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  color: Colors.white,
                  child: TabBar(
                    isScrollable: true,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 14),
                    labelColor: Colors.black,
                    unselectedLabelColor: Colors.black54,
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 2),
                      ],
                    ),
                    tabs: tabs!,
                  ),
                ),
              )
            : null,
      ),
    );
  }

  @override
  Size get preferredSize =>
      Size.fromHeight(68 + (tabsNoAppBar && tabs != null ? 48 : 0));
}

double lerpDouble(double a, double b, double t) => a + (b - a) * t;
