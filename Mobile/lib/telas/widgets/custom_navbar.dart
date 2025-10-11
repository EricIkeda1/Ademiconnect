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
          Size.fromHeight(toolbarHeight + (tabsNoAppBar && tabs != null ? 54 : 0)),
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
                child: Image.asset(
                  'assets/Logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),

            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(0xFF231F20),
                      child: Icon(Icons.person, size: 16, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          nome,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                            fontSize: 13.8,
                          ),
                        ),
                        Text(
                          cargo,
                          style: const TextStyle(
                            fontSize: 11.5,
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    textStyle:
                        const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onPressed:
                      onLogout ?? () => Navigator.pushReplacementNamed(context, '/login'),
                ),
              ),
            ),
          ],
        ),

        bottom: tabsNoAppBar && tabs != null
            ? PreferredSize(
                preferredSize: const Size.fromHeight(54),
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FA),
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: TabBar(
                      isScrollable: true,
                      labelPadding:
                          const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.black54,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                      indicator: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF231F20),
                            Color(0xFF3A3839),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(color: Colors.black26, width: 0.8),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black38,
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      splashBorderRadius: BorderRadius.circular(50),
                      overlayColor:
                          MaterialStateProperty.all(Colors.black12.withOpacity(0.05)),
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
      Size.fromHeight(68 + (tabsNoAppBar && tabs != null ? 54 : 0));
}

double lerpDouble(double a, double b, double t) => a + (b - a) * t;
