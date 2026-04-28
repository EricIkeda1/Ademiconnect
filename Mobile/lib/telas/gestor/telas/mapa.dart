import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

const Color kRed = Color(0xFFED3B2E);
const Color kDarkGray = Color(0xFF231F20);
const Color kLightGray = Color(0xFFF7F7F7);
const Color kBorderGray = Color(0xFFE8E8E8);

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
  
  int clientesProcessados = 0;
  int totalClientesParaProcessar = 0;
  int cepsGeocodificados = 0;
  int totalCepsParaGeocodificar = 0;
  
  final Map<String, LatLng> _cacheCoordenadas = {};

  // Estado dos filtros
  final Map<String, bool> filtrosIntensidade = {
    'Muito Alta': true,
    'Alta': true,
    'Média': true,
    'Baixa': true,
  };

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
        clientesProcessados = 0;
        totalClientesParaProcessar = 0;
        cepsGeocodificados = 0;
        totalCepsParaGeocodificar = 0;
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
      totalClientesParaProcessar = totalClientes;

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

      int processados = 0;
      for (var cliente in data) {
        processados++;
        setState(() {
          clientesProcessados = processados;
          statusMessage = 'Processando clientes: $processados/${data.length}';
        });
        
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

      totalCepsParaGeocodificar = contagemPorCep.length;
      
      setState(() {
        statusMessage = 'Geocodificando ${contagemPorCep.length} CEPs...';
      });

      List<CircleMarker> circles = [];
      List<LatLng> coordenadasEncontradas = [];
      
      int processadosCeps = 0;
      final total = contagemPorCep.length;
      
      for (var entry in contagemPorCep.entries) {
        final cep = entry.key;
        final quantidade = entry.value;
        
        processadosCeps++;
        setState(() {
          cepsGeocodificados = processadosCeps;
          statusMessage = 'Processando ${processadosCeps}/$total CEPs...\nCEP: $cep ($quantidade clientes)';
        });
        
        LatLng? coordenada = _cacheCoordenadas[cep];
        
        if (coordenada == null) {
          if (processadosCeps > 1) {
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

  // FUNÇÕES DE GEOCODIFICAÇÃO ORIGINAIS - SEM ALTERAÇÕES
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
        
        return await _buscarPhoton(query);
      }
      
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
    
    final coordenada = await _buscarNominatim(query);
    if (coordenada != null) return coordenada;
    
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

  String _getIntensidadeByColor(Color cor) {
    if (cor == Colors.red) return 'Muito Alta';
    if (cor == Colors.deepOrange) return 'Alta';
    if (cor == Colors.orange) return 'Média';
    return 'Baixa';
  }

  int _getFiltrosAtivosCount() {
    return filtrosIntensidade.values.where((v) => v == true).length;
  }

  void _mostrarFiltros() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateBottomSheet) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filtrar por Intensidade',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: Row(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('Muito Alta (10+ clientes)'),
                      ],
                    ),
                    value: filtrosIntensidade['Muito Alta'],
                    onChanged: (value) {
                      setStateBottomSheet(() {
                        filtrosIntensidade['Muito Alta'] = value ?? false;
                      });
                    },
                    activeColor: kRed,
                  ),
                  CheckboxListTile(
                    title: Row(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: Colors.deepOrange,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('Alta (5-9 clientes)'),
                      ],
                    ),
                    value: filtrosIntensidade['Alta'],
                    onChanged: (value) {
                      setStateBottomSheet(() {
                        filtrosIntensidade['Alta'] = value ?? false;
                      });
                    },
                    activeColor: kRed,
                  ),
                  CheckboxListTile(
                    title: Row(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('Média (3-4 clientes)'),
                      ],
                    ),
                    value: filtrosIntensidade['Média'],
                    onChanged: (value) {
                      setStateBottomSheet(() {
                        filtrosIntensidade['Média'] = value ?? false;
                      });
                    },
                    activeColor: kRed,
                  ),
                  CheckboxListTile(
                    title: Row(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.yellow.shade700,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('Baixa (1-2 clientes)'),
                      ],
                    ),
                    value: filtrosIntensidade['Baixa'],
                    onChanged: (value) {
                      setStateBottomSheet(() {
                        filtrosIntensidade['Baixa'] = value ?? false;
                      });
                    },
                    activeColor: kRed,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setStateBottomSheet(() {
                              for (var key in filtrosIntensidade.keys) {
                                filtrosIntensidade[key] = true;
                              }
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kRed,
                            side: const BorderSide(color: kRed),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Selecionar Todos'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {});
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kRed,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Aplicar Filtros'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLightGray,
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
          'Voltar para Endereços',
          style: TextStyle(color: kDarkGray, fontWeight: FontWeight.w600, fontSize: 16),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          
          // Título e contagem
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.map, color: kRed, size: 28),
                const SizedBox(width: 8),
                const Text(
                  'Mapa de Calor - Leads',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kDarkGray),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: kRed,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isLoading ? 'Carregando...' : '$totalClientes leads encontrados',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Botão de Filtros
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: isLoading ? null : _mostrarFiltros,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kBorderGray),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.filter_list, color: kRed, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Filtros',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    if (!isLoading)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: kRed.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getFiltrosAtivosCount().toString(),
                          style: const TextStyle(color: kRed, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Mapa
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kBorderGray),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _buildMapa(),
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Indicador de Progresso (mostra quantidade de dados sendo carregados)
          if (isLoading && statusMessage.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kBorderGray),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          statusMessage,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: totalClientesParaProcessar > 0 
                        ? (cepsGeocodificados > 0 
                            ? cepsGeocodificados / totalCepsParaGeocodificar 
                            : clientesProcessados / totalClientesParaProcessar)
                        : null,
                    backgroundColor: kBorderGray,
                    color: kRed,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Clientes: $clientesProcessados/$totalClientesParaProcessar',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      if (totalCepsParaGeocodificar > 0)
                        Text(
                          'CEPs: $cepsGeocodificados/$totalCepsParaGeocodificar',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                    ],
                  ),
                ],
              ),
            ),
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
    
    // Aplicar filtros nos círculos
    List<CircleMarker> circlesFiltrados = [];
    for (var circle in heatCircles) {
      String intensidade = _getIntensidadeByColor(circle.borderColor);
      if (filtrosIntensidade[intensidade] == true) {
        circlesFiltrados.add(circle);
      }
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
          circles: circlesFiltrados,
        ),
      ],
    );
  }
}