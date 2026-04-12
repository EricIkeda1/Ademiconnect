import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const Color kRed = Color(0xFFED3B2E);

class MapaPage extends StatefulWidget {
  const MapaPage({super.key});

  @override
  State<MapaPage> createState() => _MapaPageState();
}

class _MapaPageState extends State<MapaPage> {
  final supabase = Supabase.instance.client;
  
  List<CircleMarker> heatCircles = [];
  int totalClientes = 0;
  int totalSemCep = 0;
  bool isLoading = true;
  String errorMessage = '';
  
  final Map<String, LatLng> _cacheCoordenadas = {};

  @override
  void initState() {
    super.initState();
    carregarClientes();
  }

  Future<void> carregarClientes() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = '';
        totalSemCep = 0;
      });

      final user = supabase.auth.currentUser;
      
      if (user == null) {
        throw Exception('Usuário não está logado');
      }

      final consultoresResponse = await supabase
          .from('consultores')
          .select('uid')
          .eq('gestor_id', user.id);

      final List consultores = consultoresResponse as List;
      
      if (consultores.isEmpty) {
        setState(() {
          isLoading = false;
          heatCircles = [];
          totalClientes = 0;
        });
        return;
      }

      final List<String> consultoresIds = consultores
          .map((c) => c['uid'].toString())
          .toList();

      final response = await supabase
          .from('clientes')
          .select('cidade, bairro, cep')
          .inFilter('consultor_uid_t', consultoresIds);

      final data = response as List;
      totalClientes = data.length;

      if (totalClientes == 0) {
        setState(() {
          isLoading = false;
          heatCircles = [];
        });
        return;
      }

      Map<String, int> contagemPorCep = {};
      Map<String, Map<String, String>> infoPorCep = {};

      for (var cliente in data) {
        final cep = cliente['cep']?.toString() ?? '';
        
        if (cep.isEmpty) {
          totalSemCep++;
          continue;
        }
        
        contagemPorCep[cep] = (contagemPorCep[cep] ?? 0) + 1;
        
        if (!infoPorCep.containsKey(cep)) {
          infoPorCep[cep] = {
            'cidade': cliente['cidade']?.toString() ?? '',
            'bairro': cliente['bairro']?.toString() ?? '',
          };
        }
      }

      if (contagemPorCep.isEmpty) {
        setState(() {
          isLoading = false;
          heatCircles = [];
          errorMessage = 'Nenhum cliente possui CEP cadastrado';
        });
        return;
      }

      List<CircleMarker> circles = [];
      
      for (var entry in contagemPorCep.entries) {
        final cep = entry.key;
        final quantidade = entry.value;
        final cidade = infoPorCep[cep]?['cidade'] ?? '';
        final bairro = infoPorCep[cep]?['bairro'] ?? '';
        
        LatLng? coordenada = _cacheCoordenadas[cep];
        
        if (coordenada == null) {
          coordenada = await _geocodeCep(cep);
          if (coordenada != null) {
            _cacheCoordenadas[cep] = coordenada;
          }
        }
        
        if (coordenada == null) {
          print('⚠️ Não foi possível geocodificar: $cep');
          continue;
        }
        
        double radius = 30 + (quantidade * 4);
        radius = radius.clamp(25.0, 100.0);
        
        Color cor;
        if (quantidade >= 10) {
          cor = Colors.red;
        } else if (quantidade >= 5) {
          cor = Colors.deepOrange;
        } else if (quantidade >= 3) {
          cor = Colors.orange;
        } else {
          cor = Colors.yellow.shade700;
        }
        
        circles.add(
          CircleMarker(
            point: coordenada,
            radius: radius,
            color: cor.withOpacity(0.6),
            borderStrokeWidth: 2,
            borderColor: cor.withOpacity(0.9),
            useRadiusInMeter: false,
          ),
        );
        
        print('📍 $cep → $quantidade clientes');
        
        await Future.delayed(const Duration(milliseconds: 500));
      }

      setState(() {
        heatCircles = circles;
        isLoading = false;
      });

    } catch (e) {
      print('❌ Erro: $e');
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<LatLng?> _geocodeCep(String cep) async {
    try {
      final cepLimpo = cep.replaceAll('-', '');
      
      final viaCepUrl = 'https://viacep.com.br/ws/$cepLimpo/json/';
      final response = await http.get(Uri.parse(viaCepUrl)).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data.containsKey('erro')) {
          return null;
        }
        
        final logradouro = data['logradouro'] ?? '';
        final cidade = data['localidade'] ?? '';
        final uf = data['uf'] ?? '';
        
        if (cidade.isEmpty) return null;
        
        String endereco = '$logradouro, $cidade, $uf, Brasil';
        final encodedEndereco = Uri.encodeComponent(endereco);
        final nominatimUrl = 'https://nominatim.openstreetmap.org/search?q=$encodedEndereco&format=json&limit=1';
        
        final geoResponse = await http.get(
          Uri.parse(nominatimUrl),
          headers: {'User-Agent': 'MeuApp/1.0'},
        ).timeout(const Duration(seconds: 8));
        
        if (geoResponse.statusCode == 200) {
          final List geoData = jsonDecode(geoResponse.body);
          if (geoData.isNotEmpty) {
            final lat = double.parse(geoData[0]['lat'].toString());
            final lon = double.parse(geoData[0]['lon'].toString());
            print('✅ $cep → $lat, $lon');
            return LatLng(lat, lon);
          }
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kRed),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Mapa de Calor - Clientes',
          style: TextStyle(color: Color(0xFF231F20), fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 90),
          
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 6)],
            ),
            child: Row(
              children: [
                const Icon(Icons.heat_pump, color: kRed),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Clientes por CEP", style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        isLoading ? "Carregando..." : "$totalClientes clientes (${heatCircles.length} CEPs)",
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: isLoading ? null : carregarClientes,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text("Atualizar"),
                  style: OutlinedButton.styleFrom(foregroundColor: kRed, side: const BorderSide(color: kRed)),
                )
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE8E8E8)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : heatCircles.isEmpty
                        ? const Center(child: Text("Nenhum cliente com CEP encontrado"))
                        : FlutterMap(
                            options: MapOptions(
                              initialCenter: const LatLng(-23.3105, -51.1628),
                              initialZoom: 10,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                                subdomains: ['a', 'b', 'c'],
                              ),
                              CircleLayer(circles: heatCircles),
                            ],
                          ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildLegenda(Colors.yellow.shade700, '1-2'),
                _buildLegenda(Colors.orange, '3-4'),
                _buildLegenda(Colors.deepOrange, '5-9'),
                _buildLegenda(Colors.red, '10+'),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLegenda(Color cor, String texto) {
    return Row(
      children: [
        Container(width: 16, height: 16, decoration: BoxDecoration(color: cor.withOpacity(0.6), shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(texto, style: const TextStyle(fontSize: 10)),
      ],
    );
  }
}