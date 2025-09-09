import 'package:flutter/material.dart';
import '../widgets/navbar.dart';
import '../models/lead_model.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({Key? key}) : super(key: key);

  @override
  _DashboardState createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int _selectedIndex = 0;
  final TextEditingController _searchController = TextEditingController();

  List<Lead> leads = [
    Lead(
      name: 'Ana Silva',
      phone: '(43) 99999-1234',
      email: 'ana.silva@email.com',
      status: 'Ativo',
    ),
    Lead(
      name: 'Carlos Oliveira',
      phone: '(43) 98888-5678',
      email: 'carlos@empresa.com.br',
      status: 'Expirado',
    ),
  ];

  List<Lead> filteredLeads = [];

  @override
  void initState() {
    super.initState();
    filteredLeads = leads;
    _searchController.addListener(_filterLeads);
  }

  void _filterLeads() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        filteredLeads = leads;
      } else {
        filteredLeads = leads.where((lead) {
          return lead.name.toLowerCase().contains(query) ||
              lead.phone.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _onItemSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
    Navigator.pop(context);

    if (index == 6) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          "Dashboard de Leads",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.circle, size: 36, color: Colors.black87),
                onPressed: () {},
              ),
              const Positioned(
                top: 6,
                right: 12,
                child: Text(
                  "J",
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              )
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: NavBar(
        userName: 'João Silva',
        userRole: 'Gestor',
        leadCount: leads.length,
        onItemSelected: _onItemSelected,
        selectedIndex: _selectedIndex,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14.0),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Novo Lead',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(child: _buildSummaryCard(Icons.people, "Total", leads.length, Colors.black)),
                const SizedBox(width: 12),
                Expanded(child: _buildSummaryCard(Icons.check_circle, "Ativos", _countLeadsByStatus("Ativo"), Colors.green)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildSummaryCard(Icons.warning, "Expirados", _countLeadsByStatus("Expirado"), Colors.red)),
                const SizedBox(width: 12),
                Expanded(child: _buildSummaryCard(Icons.trending_up, "Convertidos", _countLeadsByStatus("Convertido"), Colors.blue)),
              ],
            ),
            const SizedBox(height: 12),

            _buildVencendoCard("Vencendo", _countLeadsByStatus("Vencendo")),
            const SizedBox(height: 16),

            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Buscar por nome ou telefone...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text("Todos"),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Lista de Leads", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("${filteredLeads.length} leads"),
              ],
            ),
            const SizedBox(height: 12),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredLeads.length,
              itemBuilder: (context, index) {
                final lead = filteredLeads[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            lead.name,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: lead.status == "Ativo" ? Colors.black : Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              lead.status,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.phone, size: 16, color: Colors.black54),
                          const SizedBox(width: 6),
                          Text(lead.phone),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.email, size: 16, color: Colors.black54),
                          const SizedBox(width: 6),
                          Text(lead.email),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.person, size: 16, color: Colors.black54),
                          const SizedBox(width: 6),
                          const Text("João Silva"),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  int _countLeadsByStatus(String status) {
    return leads.where((lead) => lead.status == status).length;
  }

  Widget _buildSummaryCard(IconData icon, String title, int value, Color color) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              value.toString(),
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVencendoCard(String title, int value) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.timer, color: Colors.orange, size: 18),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value.toString(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
