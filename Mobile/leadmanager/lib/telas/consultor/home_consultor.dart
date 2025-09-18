import 'package:flutter/material.dart';
import '../widgets/custom_navbar.dart';
import '../widgets/trabalho_hoje_card.dart';
import 'meus_clientes_tab.dart';
import 'minhas_visitas_tab.dart';
import 'exportar_dados_tab.dart';

class HomeConsultor extends StatefulWidget {
  const HomeConsultor({super.key});
  @override
  State<HomeConsultor> createState() => _HomeConsultorState();
}

class _HomeConsultorState extends State<HomeConsultor> {
  final List _clientes = [];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: const CustomNavbar(
          nome: 'João Silva',
          cargo: 'Consultor',
          tabs: [
            Tab(text: 'Minhas Visitas'),
            Tab(text: 'Cadastrar Cliente'),
            Tab(text: 'Meus Clientes'),
            Tab(text: 'Exportar Dados'),
          ],
        ),
        body: TabBarView(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                TrabalhoHojeCard(),
                SizedBox(height: 12),
                MinhasVisitasTab(),
              ],
            ),
            const Center(child: Text('Form de cadastrar cliente aqui')), // substitua pelo formulário
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const TrabalhoHojeCard(),
                MeusClientesTab(clientes: []),
              ],
            ),
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const TrabalhoHojeCard(),
                ExportarDadosTab(clientes: []),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
