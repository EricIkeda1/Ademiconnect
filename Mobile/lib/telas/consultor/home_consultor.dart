import 'package:flutter/material.dart';
import '../widgets/custom_navbar.dart';
import '../widgets/trabalho_hoje_card.dart';
import 'meus_clientes_tab.dart';
import 'minhas_visitas_tab.dart';
import 'exportar_dados_tab.dart';
import 'cadastrar_cliente.dart';

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
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Theme(
            data: Theme.of(context).copyWith(
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFFD03025), // d03025
                surfaceTintColor: Color(0xFFD03025),
                elevation: 1,
                centerTitle: false,
              ),
            ),
            child: const CustomNavbar(
              nome: 'João Silva',
              cargo: 'Consultor',
              tabsNoAppBar: false,
            ),
          ),
        ),
        body: Column(
          children: [
            // Padding externo reduzido de 16 para 12
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  const TrabalhoHojeCard(),
                  // separação reduzida de 16 para 10
                  const SizedBox(height: 10),

                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 1,
                    child: Padding(
                      // padding interno reduzido de 8 para 6
                      padding: const EdgeInsets.all(6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFFAF1),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(color: const Color(0xFFDCEFE1)),
                                ),
                                child: const Icon(
                                  Icons.place,
                                  size: 13,
                                  color: Color(0xFF3CB371),
                                ),
                              ),
                              // gap reduzido de 6 para 4
                              const SizedBox(width: 4),
                              const Expanded(
                                child: Text(
                                  'Próximas Visitas Programadas',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // mantém 2 para título->descrição
                          const SizedBox(height: 2),
                          Text(
                            'Ruas designadas pelo gestor para os próximos dias',
                            style: TextStyle(
                              color: Colors.black.withOpacity(0.6),
                              fontSize: 11,
                            ),
                          ),
                          // de 6 para 4
                          const SizedBox(height: 4),
                          ListTile(
                            leading: Container(
                              width: 28,
                              height: 28,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF2F5FF),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.black12),
                              ),
                              child: const Icon(
                                Icons.place_outlined,
                                color: Color(0xFF2F6FED),
                                size: 16,
                              ),
                            ),
                            title: const Text(
                              'Av. Principal, Bairro Comercial',
                              style: TextStyle(fontSize: 13),
                            ),
                            subtitle: const Text(
                              'qui, 18 de setembro de 2025',
                              style: TextStyle(fontSize: 11),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Hoje',
                                style: TextStyle(color: Colors.white, fontSize: 11),
                              ),
                            ),
                            // contentPadding horizontal reduzido de 6 para 4
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                            // densidade do ListTile mais compacta
                            dense: true,
                            visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // separação reduzida de 16 para 10
                  const SizedBox(height: 10),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _statCardIcon(
                        title: 'Clientes',
                        value: '0',
                        icon: Icons.people_alt,
                        color: Colors.blue,
                      ),
                      _statCardIcon(
                        title: 'Visitas',
                        value: '0',
                        icon: Icons.place,
                        color: Colors.green,
                      ),
                      _statCardIcon(
                        title: 'Alertas',
                        value: '0',
                        icon: Icons.notifications_active,
                        color: Colors.orange,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // TabBar com padding lateral reduzido (mantido 16 -> 12)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                elevation: 2,
                child: const TabBar(
                  isScrollable: true,
                  // padding do rótulo mais compacto (14 -> 12)
                  labelPadding: EdgeInsets.symmetric(horizontal: 12),
                  labelColor: Colors.black,
                  unselectedLabelColor: Colors.black54,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  indicator: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2)],
                  ),
                  tabs: [
                    Tab(text: 'Minhas Visitas'),
                    Tab(text: 'Cadastrar Cliente'),
                    Tab(text: 'Meus Clientes'),
                    Tab(text: 'Exportar Dados'),
                  ],
                ),
              ),
            ),

            // gap de 12 -> 8
            const SizedBox(height: 8),

            Expanded(
              child: TabBarView(
                children: [
                  ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: const [
                      SizedBox(height: 6),
                      MinhasVisitasTab(),
                    ],
                  ),

                  ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: const [
                      SizedBox(height: 6),
                      CadastrarCliente(),
                    ],
                  ),

                  ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      const SizedBox(height: 6),
                      MeusClientesTab(clientes: []),
                    ],
                  ),

                  ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: const [
                      SizedBox(height: 6),
                      ExportarDadosTab(clientes: []),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCardIcon({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          // de 8 para 6
          padding: const EdgeInsets.all(6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: color.withOpacity(0.12),
                    child: Icon(icon, color: color, size: 16),
                  ),
                  // de 6 para 4
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              // de 6 para 4
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
