import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

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
  String statusMessage = '';
  
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
        statusMessage = 'Iniciando...';
        totalSemCep = 0;
        heatCircles = [];
      });

      final user = supabase.auth.currentUser;
      
      if (user == null) {
        throw Exception('Usuário não está logado');
      }

      setState(() {
        statusMessage = 'Buscando consultores...';
      });

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
          statusMessage = '';
        });
        return;
      }

      final List<String> consultoresIds = consultores
          .map((c) => c['uid'].toString())
          .toList();

      setState(() {
        statusMessage = 'Buscando clientes...';
      });

      final response = await supabase
          .from('clientes')
          .select('cidade, bairro, cep, logradouro, numero')
          .inFilter('consultor_uid_t', consultoresIds);

      final data = response as List;
      totalClientes = data.length;

      if (totalClientes == 0) {
        setState(() {
          isLoading = false;
          heatCircles = [];
          statusMessage = '';
        });
        return;
      }

      setState(() {
        statusMessage = 'Processando ${data.length} clientes...';
      });

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
            'logradouro': cliente['logradouro']?.toString() ?? '',
            'numero': cliente['numero']?.toString() ?? '',
          };
        }
      }

      if (contagemPorCep.isEmpty) {
        setState(() {
          isLoading = false;
          heatCircles = [];
          errorMessage = 'Nenhum cliente possui CEP cadastrado';
          statusMessage = '';
        });
        return;
      }

      setState(() {
        statusMessage = 'Geocodificando ${contagemPorCep.length} CEPs...';
      });

      List<CircleMarker> circles = [];
      List<LatLng> coordenadasEncontradas = [];
      
      int processados = 0;
      final total = contagemPorCep.length;
      
      for (var entry in contagemPorCep.entries) {
        final cep = entry.key;
        final quantidade = entry.value;
        
        setState(() {
          statusMessage = 'Processando ${processados + 1}/$total CEPs...\nCEP: $cep';
        });
        
        LatLng? coordenada = _cacheCoordenadas[cep];
        
        if (coordenada == null) {
          // Aguardar entre requisições para não ser bloqueado
          if (processados > 0) {
            await Future.delayed(const Duration(milliseconds: 1000));
          }
          
          coordenada = await _geocodeCep(cep, infoPorCep[cep]);
          if (coordenada != null) {
            _cacheCoordenadas[cep] = coordenada;
          }
        }
        
        if (coordenada != null) {
          coordenadasEncontradas.add(coordenada);
          
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
          
          print('📍 $cep → $quantidade clientes | Coord: ${coordenada.latitude}, ${coordenada.longitude}');
        } else {
          print('⚠️ Não foi possível geocodificar: $cep');
        }
        
        processados++;
      }

      print('✅ Total de círculos criados: ${circles.length}');

      setState(() {
        heatCircles = circles;
        isLoading = false;
        statusMessage = '';
      });

    } catch (e) {
      print('❌ Erro: $e');
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
        statusMessage = '';
      });
    }
  }

  Future<LatLng?> _geocodeCep(String cep, Map<String, String>? info) async {
    try {
      final cepLimpo = cep.replaceAll('-', '');
      
      // 1. Tentar ViaCEP primeiro
      final viaCepUrl = 'https://viacep.com.br/ws/$cepLimpo/json/';
      final response = await http.get(Uri.parse(viaCepUrl)).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data.containsKey('erro')) {
          return await _geocodePorInfo(cep, info);
        }
        
        final logradouro = data['logradouro'] ?? '';
        final cidade = data['localidade'] ?? '';
        final uf = data['uf'] ?? '';
        final bairro = data['bairro'] ?? '';
        
        if (cidade.isEmpty) {
          return await _geocodePorInfo(cep, info);
        }
        
        // Construir query
        String query;
        if (logradouro.isNotEmpty && logradouro != 'null' && bairro.isNotEmpty && bairro != 'null') {
          query = '$logradouro, $bairro, $cidade, $uf, Brasil';
        } else if (logradouro.isNotEmpty && logradouro != 'null') {
          query = '$logradouro, $cidade, $uf, Brasil';
        } else if (bairro.isNotEmpty && bairro != 'null') {
          query = '$bairro, $cidade, $uf, Brasil';
        } else {
          query = '$cidade, $uf, Brasil';
        }
        
        print('🔍 Buscando: "$query"');
        
        // 2. Tentar Nominatim (funciona em todas plataformas)
        final coordenada = await _buscarNominatim(query);
        if (coordenada != null) {
          return coordenada;
        }
        
        // 3. Tentar Photon como fallback
        return await _buscarPhoton(query);
      }
      
      // Fallback para informações do banco
      return await _geocodePorInfo(cep, info);
      
    } catch (e) {
      print('❌ Erro geocoding $cep: $e');
      return await _geocodePorInfo(cep, info);
    }
  }
  
  Future<LatLng?> _geocodePorInfo(String cep, Map<String, String>? info) async {
    if (info == null) return null;
    
    final cidade = info['cidade'] ?? '';
    final bairro = info['bairro'] ?? '';
    final logradouro = info['logradouro'] ?? '';
    
    if (cidade.isEmpty) return null;
    
    String query;
    if (logradouro.isNotEmpty && logradouro != 'null' && bairro.isNotEmpty && bairro != 'null') {
      query = '$logradouro, $bairro, $cidade, PR, Brasil';
    } else if (bairro.isNotEmpty && bairro != 'null') {
      query = '$bairro, $cidade, PR, Brasil';
    } else {
      query = '$cidade, PR, Brasil';
    }
    
    print('🔍 Buscando (info): "$query"');
    
    // Tentar Nominatim
    final coordenada = await _buscarNominatim(query);
    if (coordenada != null) return coordenada;
    
    // Tentar Photon
    return await _buscarPhoton(query);
  }
  
  Future<LatLng?> _buscarNominatim(String query) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final url = 'https://nominatim.openstreetmap.org/search?q=$encodedQuery&format=json&limit=1&countrycodes=br';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'AdemicomApp/2.0 (https://ademicom.com; contato@ademicom.com)',
          'Accept-Language': 'pt-BR,pt;q=0.9',
        },
      ).timeout(const Duration(seconds: 8));
      
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final lat = double.tryParse(data[0]['lat'].toString());
          final lon = double.tryParse(data[0]['lon'].toString());
          if (lat != null && lon != null) {
            print('✅ Nominatim: ($lat, $lon)');
            return LatLng(lat, lon);
          }
        }
      } else {
        print('⚠️ Nominatim status: ${response.statusCode}');
      }
    } catch (e) {
      print('⚠️ Nominatim erro: $e');
    }
    return null;
  }
  
  Future<LatLng?> _buscarPhoton(String query) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final url = 'https://photon.komoot.io/api/?q=$encodedQuery&limit=1&lang=pt';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'AdemicomApp/2.0'},
      ).timeout(const Duration(seconds: 8));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['features'] != null && data['features'].isNotEmpty) {
          final coordinates = data['features'][0]['geometry']['coordinates'];
          if (coordinates != null && coordinates.length >= 2) {
            final lon = coordinates[0];
            final lat = coordinates[1];
            print('✅ Photon: ($lat, $lon)');
            return LatLng(lat, lon);
          }
        }
      }
    } catch (e) {
      print('⚠️ Photon erro: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
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
                      if (statusMessage.isNotEmpty)
                        Text(
                          statusMessage,
                          style: const TextStyle(fontSize: 12, color: Colors.blue),
                        )
                      else if (errorMessage.isNotEmpty && !isLoading)
                        Text(
                          errorMessage,
                          style: const TextStyle(fontSize: 12, color: Colors.red),
                        )
                      else if (!isLoading)
                        Text(
                          "$totalClientes clientes (${heatCircles.length} CEPs encontrados)",
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      if (totalSemCep > 0 && !isLoading)
                        Text(
                          "$totalSemCep clientes sem CEP",
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: isLoading ? null : carregarClientes,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text("Atualizar"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kRed, 
                    side: const BorderSide(color: kRed),
                  ),
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
                child: _buildMapa(),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          if (heatCircles.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 4)],
              ),
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
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }
  
  Widget _buildMapa() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (errorMessage.isNotEmpty && heatCircles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(errorMessage, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: carregarClientes,
              icon: const Icon(Icons.refresh),
              label: const Text("Tentar Novamente"),
              style: ElevatedButton.styleFrom(backgroundColor: kRed),
            ),
          ],
        ),
      );
    }
    
    if (heatCircles.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text("Nenhum cliente com localização encontrada"),
            SizedBox(height: 8),
            Text(
              "Verifique sua conexão com a internet",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    return FlutterMap(
      options: MapOptions(
        initialCenter: const LatLng(-23.3105, -51.1628),
        initialZoom: 11,
        minZoom: 4,
        maxZoom: 18,
      ),
      children: [
        TileLayer(
          urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
          subdomains: const ['a', 'b', 'c'],
          userAgentPackageName: 'com.ademicom.app',
        ),
        CircleLayer(
          circles: heatCircles,
        ),
      ],
    );
  }
  
  Widget _buildLegenda(Color cor, String texto) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: cor.withOpacity(0.6),
            shape: BoxShape.circle,
            border: Border.all(color: cor, width: 2),
          ),
        ),
        const SizedBox(width: 6),
        Text(texto, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}