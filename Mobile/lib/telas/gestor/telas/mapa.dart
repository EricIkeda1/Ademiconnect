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
  LatLng? initialCenter;
  
  final Map<String, LatLng> _cacheCoordenadas = {};

  @override
  void initState() {
    super.initState();
    carregarClientes();
  }

  Future<void> carregarClientes() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      setState(() {
        isLoading = true;
        errorMessage = '';
        totalSemCep = 0;
        heatCircles = [];
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
          errorMessage = 'Nenhum consultor encontrado';
        });
        return;
      }

      final List<String> consultoresIds = consultores
          .map((c) => c['uid'].toString())
          .toList();

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
          errorMessage = 'Nenhum cliente encontrado';
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
        });
        return;
      }

      final List<Future<MapEntry<String, LatLng?>>> futures = [];
      
      for (var entry in contagemPorCep.entries) {
        final cep = entry.key;
        
        if (_cacheCoordenadas.containsKey(cep)) {
          futures.add(Future.value(MapEntry(cep, _cacheCoordenadas[cep])));
        } else {
          futures.add(_geocodeCepOtimizado(cep, infoPorCep[cep]));
        }
      }
      
      final resultados = await Future.wait(futures);
      
      List<CircleMarker> circles = [];
      List<LatLng> coordenadasEncontradas = [];
      
      for (var resultado in resultados) {
        final cep = resultado.key;
        final coordenada = resultado.value;
        final quantidade = contagemPorCep[cep] ?? 0;
        
        if (coordenada == null) {
          print('⚠️ Não foi possível geocodificar: $cep');
          continue;
        }
        
        coordenadasEncontradas.add(coordenada);
        
        double radius = 30 + (quantidade * 5);
        radius = radius.clamp(30.0, 120.0);
        
        Color cor = _getCorPorQuantidade(quantidade);
        
        circles.add(
          CircleMarker(
            point: coordenada,
            radius: radius,
            color: cor.withOpacity(0.4),
            borderStrokeWidth: 2,
            borderColor: cor,
            useRadiusInMeter: false,
          ),
        );
        
        print('📍 $cep → $quantidade clientes, raio: $radius');
      }

      print('✅ Total de círculos criados: ${circles.length}');
      print('⏱️ Tempo total: ${stopwatch.elapsedMilliseconds}ms');
      
      LatLng center = const LatLng(-23.5505, -46.6333); 
      if (coordenadasEncontradas.isNotEmpty) {
        center = coordenadasEncontradas.first;
      }
      
      setState(() {
        heatCircles = circles;
        initialCenter = center;
        isLoading = false;
      });

    } catch (e) {
      print('❌ Erro geral: $e');
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }
  
  Future<MapEntry<String, LatLng?>> _geocodeCepOtimizado(String cep, Map<String, String>? info) async {
    try {
      final cepLimpo = cep.replaceAll('-', '');
      
      final viaCepUrl = 'https://viacep.com.br/ws/$cepLimpo/json/';
      
      try {
        final response = await http.get(Uri.parse(viaCepUrl)).timeout(const Duration(seconds: 3));
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          
          if (data is Map && !data.containsKey('erro')) {
            final logradouro = data['logradouro'] ?? '';
            final cidade = data['localidade'] ?? '';
            final uf = data['uf'] ?? '';
            final bairro = data['bairro'] ?? '';
            
            if (cidade.isNotEmpty) {
              String query;
              if (logradouro.isNotEmpty && bairro.isNotEmpty) {
                query = '$logradouro, $bairro, $cidade, $uf';
              } else if (logradouro.isNotEmpty) {
                query = '$logradouro, $cidade, $uf';
              } else {
                query = '$cidade, $uf';
              }
              
              final coordenada = await _buscarCoordenadas(query);
              if (coordenada != null) {
                _cacheCoordenadas[cep] = coordenada;
                return MapEntry(cep, coordenada);
              }
            }
          }
        }
      } catch (e) {
        print('⚠️ Erro ViaCEP para $cep: $e');
      }
      
      if (info != null) {
        final cidade = info['cidade'] ?? '';
        final bairro = info['bairro'] ?? '';
        
        if (cidade.isNotEmpty) {
          String query = bairro.isNotEmpty ? '$bairro, $cidade, PR' : '$cidade, PR';
          final coordenada = await _buscarCoordenadas(query);
          if (coordenada != null) {
            _cacheCoordenadas[cep] = coordenada;
            return MapEntry(cep, coordenada);
          }
        }
      }
      
      return MapEntry(cep, null);
      
    } catch (e) {
      print('❌ Erro ao geocodificar $cep: $e');
      return MapEntry(cep, null);
    }
  }
  
  Future<LatLng?> _buscarCoordenadas(String query) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      
      final photonUrl = 'https://photon.komoot.io/api/?q=$encodedQuery&limit=1&lang=pt';
      
      try {
        final photonResponse = await http.get(Uri.parse(photonUrl)).timeout(const Duration(seconds: 4));
        
        if (photonResponse.statusCode == 200) {
          final data = jsonDecode(photonResponse.body);
          if (data['features'] != null && data['features'].isNotEmpty) {
            final coordinates = data['features'][0]['geometry']['coordinates'];
            if (coordinates != null && coordinates.length >= 2) {
              final lon = coordinates[0];
              final lat = coordinates[1];
              print('✅ Photon: "$query" → ($lat, $lon)');
              return LatLng(lat, lon);
            }
          }
        }
      } catch (e) {
        print('⚠️ Photon falhou para "$query": $e');
      }
      
      final nominatimUrl = 'https://nominatim.openstreetmap.org/search?q=$encodedQuery&format=json&limit=1&countrycodes=br';
      
      final nominatimResponse = await http.get(
        Uri.parse(nominatimUrl),
        headers: {
          'User-Agent': 'AdemicomApp/1.0 (contato@ademicom.com)',
          'Accept-Language': 'pt-BR,pt;q=0.9',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));
      
      if (nominatimResponse.statusCode == 200) {
        final List data = jsonDecode(nominatimResponse.body);
        if (data.isNotEmpty) {
          final lat = double.tryParse(data[0]['lat'].toString());
          final lon = double.tryParse(data[0]['lon'].toString());
          if (lat != null && lon != null) {
            print('✅ Nominatim: "$query" → ($lat, $lon)');
            return LatLng(lat, lon);
          }
        }
      }
      
      return null;
    } catch (e) {
      print('⚠️ Erro na busca para "$query": $e');
      return null;
    }
  }

  Color _getCorPorQuantidade(int quantidade) {
    if (quantidade >= 10) return Colors.red;
    if (quantidade >= 5) return Colors.deepOrange;
    if (quantidade >= 3) return Colors.orange;
    return Colors.yellow.shade700;
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
                      const Text(
                        "Clientes por CEP", 
                        style: TextStyle(fontWeight: FontWeight.bold)
                      ),
                      if (errorMessage.isNotEmpty && !isLoading)
                        Text(
                          errorMessage,
                          style: const TextStyle(fontSize: 12, color: Colors.red),
                        )
                      else if (isLoading)
                        const Text(
                          "Carregando...",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        )
                      else
                        Text(
                          "$totalClientes clientes (${heatCircles.length} CEPs encontrados)",
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      if (totalSemCep > 0)
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
          
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
    
    if (errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 8),
            Text(errorMessage, textAlign: TextAlign.center),
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
              "Tente novamente mais tarde",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    return FlutterMap(
      options: MapOptions(
        center: initialCenter ?? const LatLng(-23.5505, -46.6333),
        zoom: 10,
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
          width: 24, 
          height: 24, 
          decoration: BoxDecoration(
            color: cor.withOpacity(0.4), 
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