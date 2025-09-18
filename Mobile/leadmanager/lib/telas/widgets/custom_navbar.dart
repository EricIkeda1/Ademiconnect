// lib/telas/widgets/custom_navbar.dart
import 'package:flutter/material.dart';

class CustomNavbar extends StatelessWidget implements PreferredSizeWidget {
  final String nome;
  final String cargo;
  final List<Tab>? tabs;            // agora opcional
  final bool tabsNoAppBar;          // controla a posição das abas
  final VoidCallback? onLogout;

  const CustomNavbar({
    super.key,
    required this.nome,
    required this.cargo,
    this.tabs,
    this.tabsNoAppBar = true,       // padrão mantém compatibilidade
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 16,
      title: Row(
        children: [
          const CircleAvatar(radius: 16, child: Icon(Icons.person, size: 18)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start, 
            children: [
              Text(nome, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(cargo, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: OutlinedButton(
            onPressed: onLogout ?? () => Navigator.pushReplacementNamed(context, '/login'),
            child: const Text('Sair'),
          ),
        ),
      ],
      bottom: tabsNoAppBar && tabs != null
          ? TabBar(
              isScrollable: true,
              labelPadding: const EdgeInsets.symmetric(horizontal: 14),
              labelColor: Colors.black,
              unselectedLabelColor: Colors.black54,
              indicatorSize: TabBarIndicatorSize.tab,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
              ),
              tabs: tabs!,
            )
          : null,
    );
  }

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + ((tabsNoAppBar && tabs != null) ? 48 : 0));
}
