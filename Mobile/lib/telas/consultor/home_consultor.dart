import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../widgets/custom_navbar.dart';
import '../widgets/trabalho_hoje_card.dart';
import 'meus_clientes_tab.dart';
import 'minhas_visitas_tab.dart';
import 'exportar_dados_tab.dart';
import 'cadastrar_cliente.dart';
import '../../models/cliente.dart';
import '../../services/cliente_service.dart';

class HomeConsultor extends StatefulWidget {
  const HomeConsultor({super.key});

  @override
  State<HomeConsultor> createState() => _HomeConsultorState();
}

class _HomeConsultorState extends State<HomeConsultor> {
  final ClienteService _clienteService = ClienteService();
  int _totalClientes = 0;
  int _totalVisitasHoje = 0;
  int _totalAlertas = 0;
  List<Cliente> _clientes = [];
  String _userName = 'Consultor';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadStats();
  }

  String _formatarNome(String nome) {
    final partes = nome.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) return 'Consultor';
    if (partes.length == 1) return partes[0];
    return '${partes[0]} ${partes.last}';
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('consultores')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final nomeCompleto = doc.get('nome') as String? ?? '';
        if (nomeCompleto.isNotEmpty) {
          setState(() {
            _userName = _formatarNome(nomeCompleto);
          });
          return;
        }
      }

      final displayName = user.displayName;
      if (displayName != null && displayName.isNotEmpty) {
        setState(() {
          _userName = _formatarNome(displayName);
        });
        return;
      }

      final email = user.email;
      if (email != null && email.isNotEmpty) {
        setState(() {
          _userName = email.split('@').first;
        });
        return;
      }

      setState(() => _userName = 'Consultor');
    } catch (e) {
      print('❌ Erro ao carregar nome do consultor: $e');
      setState(() => _userName = 'Consultor');
    }
  }

  Future<void> _loadStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;

    // Buscar apenas clientes do consultor logado
    final snapshot = await FirebaseFirestore.instance
        .collection('clientes')
        .where('consultorUid', isEqualTo: uid)
        .get();

    final clientes = snapshot.docs.map((doc) => Cliente.fromFirestore(doc)).toList();

    final hoje = DateTime.now();
    final visitasHoje = clientes.where((c) {
      final dataVisita = c.dataVisita;
      return dataVisita.year == hoje.year &&
          dataVisita.month == hoje.month &&
          dataVisita.day == hoje.day;
    }).length;

    final alertas = clientes.where((c) {
      final dataVisita = c.dataVisita;
      return dataVisita.isBefore(hoje);
    }).length;

    setState(() {
      _clientes = clientes;
      _totalClientes = clientes.length;
      _totalVisitasHoje = visitasHoje;
      _totalAlertas = alertas;
    });
  }

  void _onClienteCadastrado() {
    _loadStats();
  }

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
                backgroundColor: Color(0xFFD03025),
                surfaceTintColor: Color(0xFFD03025),
                elevation: 1,
                centerTitle: false,
              ),
            ),
            child: CustomNavbar(
              nome: _userName,
              cargo: 'Consultor',
              tabsNoAppBar: false,
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              const TrabalhoHojeCard(),
              const SizedBox(height: 10),
              _proximasVisitasCard(),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _statCardIcon(
                    title: 'Clientes',
                    value: _totalClientes.toString(),
                    icon: Icons.people_alt,
                    color: Colors.blue,
                  ),
                  _statCardIcon(
                    title: 'Visitas Hoje',
                    value: _totalVisitasHoje.toString(),
                    icon: Icons.place,
                    color: Colors.green,
                  ),
                  _statCardIcon(
                    title: 'Alertas',
                    value: _totalAlertas.toString(),
                    icon: Icons.notifications_active,
                    color: Colors.orange,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                elevation: 2,
                child: const TabBar(
                  isScrollable: true,
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
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  children: [
                    MinhasVisitasTab(),
                    CadastrarCliente(onClienteCadastrado: _onClienteCadastrado),
                    MeusClientesTab(onClienteRemovido: _loadStats),
                    ExportarDadosTab(clientes: _clientes),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _proximasVisitasCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 1,
      child: Padding(
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
                const SizedBox(width: 4),
                const Expanded(
                  child: Text(
                    'Próximas Visitas Programadas',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Ruas designadas pelo gestor para os próximos dias',
              style: TextStyle(color: Colors.black.withOpacity(0.6), fontSize: 11),
            ),
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
              title: const Text('Av. Principal, Bairro Comercial', style: TextStyle(fontSize: 13)),
              subtitle: const Text('qui, 18 de setembro de 2025', style: TextStyle(fontSize: 11)),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('Hoje', style: TextStyle(color: Colors.white, fontSize: 11)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
              dense: true,
              visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
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
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
