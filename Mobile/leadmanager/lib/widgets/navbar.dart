import 'package:flutter/material.dart';

class NavBar extends StatelessWidget {
  final String userName;
  final String userRole;
  final int leadCount;
  final Function(int) onItemSelected;
  final int selectedIndex;

  const NavBar({
    Key? key,
    required this.userName,
    required this.userRole,
    required this.leadCount,
    required this.onItemSelected,
    required this.selectedIndex,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 280,
      child: Container(
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 40, 16, 20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.black,
                    child: Text(
                      userName.isNotEmpty ? userName[0] : 'U',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          userRole,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),

            Expanded(
              child: ListView(
                children: [
                  _buildNavItem(Icons.dashboard, 'Dashboard de Leads', 0),
                  _buildNavItem(Icons.file_upload, 'Importar Leads', 1),
                  _buildNavItem(Icons.assignment, 'P.A.P.', 2),
                  _buildNavItem(Icons.group, 'Gerenciar Equipe', 3),
                  _buildNavItem(Icons.verified_user, 'Auditoria', 4),
                ],
              ),
            ),

            const Divider(height: 1),

            Padding(
              padding: const EdgeInsets.only(bottom: 37),
              child: ListTile(
                leading: const Icon(Icons.exit_to_app, color: Colors.black),
                title: const Text(
                  "Sair",
                  style: TextStyle(color: Colors.black),
                ),
                onTap: () => onItemSelected(6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String title, int index) {
    final bool isSelected = selectedIndex == index;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? Colors.black : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 5,
            height: 48,
            decoration: BoxDecoration(
              color: isSelected ? Colors.red : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          Expanded(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Icon(
                icon,
                color: isSelected ? Colors.white : Colors.black,
              ),
              title: Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              trailing: isSelected
                  ? const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white)
                  : null,
              onTap: () => onItemSelected(index),
            ),
          ),
        ],
      ),
    );
  }
}
