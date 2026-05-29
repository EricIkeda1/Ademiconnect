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
  bool isLoading = true;
  String errorMessage = '';
  String detalhesErro = '';
  
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
    setState(() {
      isLoading = true;
      errorMessage = '';
      detalhesErro = '';
      heatCircles = [];
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Usuário não está logado.');
      }
      print('✅ Usuário logado: ${user.id}');

      // Buscar consultores
      print('🔍 Buscando consultores...');
      final consultoresResponse = await supabase
          .from('consultores')
          .select('uid')
          .eq('gestor_id', user.id);

      final List consultores = consultoresResponse as List;
      print('📊 Consultores encontrados: ${consultores.length}');

      if (consultores.isEmpty) {
        throw Exception('Nenhum consultor encontrado.');
      }

      final List<String> consultoresIds = consultores
          .map((c) => c['uid'].toString())
          .toList();
      
      print('📋 IDs dos consultores: $consultoresIds');

      // Buscar clientes
      print('🔍 Buscando clientes...');
      final response = await supabase
          .from('clientes')
          .select('cidade, bairro, cep, logradouro, numero')
          .inFilter('consultor_uid_t', consultoresIds);

      final data = response as List;
      totalClientes = data.length;
      print('✅ Total de clientes encontrados: $totalClientes');

      if (totalClientes == 0) {
        throw Exception('Nenhum cliente encontrado.');
      }

      // Processar clientes
      print('📊 Processando clientes...');
      Map<String, int> contagemPorCep = {};
      Map<String, Map<String, String>> infoPorCep = {};
      int clientesSemCep = 0;

      for (var cliente in data) {
        String cep = cliente['cep']?.toString() ?? '';
        
        if (cep.isEmpty) {
          clientesSemCep++;
          continue;
        }
        
        cep = cep.replaceAll(RegExp(r'[^0-9]'), '');
        
        if (cep.length != 8) {
          clientesSemCep++;
          continue;
        }
        
        contagemPorCep[cep] = (contagemPorCep[cep] ?? 0) + 1;
        
        if (!infoPorCep.containsKey(cep)) {
          infoPorCep[cep] = {
            'cidade': cliente['cidade']?.toString() ?? '',
            'bairro': cliente['bairro']?.toString() ?? '',
            'logradouro': cliente['logradouro']?.toString() ?? '',
          };
        }
      }

      print('📊 CEPs únicos: ${contagemPorCep.length}');
      print('📊 Clientes sem CEP: $clientesSemCep');

      if (contagemPorCep.isEmpty) {
        throw Exception('Nenhum cliente possui CEP válido.');
      }

      // Geocodificar CEPs
      print('🌐 Iniciando geocodificação...');
      List<CircleMarker> circles = [];
      int processados = 0;
      int totalCeps = contagemPorCep.length;

      for (var entry in contagemPorCep.entries) {
        final cep = entry.key;
        final quantidade = entry.value;
        
        processados++;
        setState(() {
          errorMessage = 'Geocodificando: $processados de $totalCeps\nCEP: $cep';
        });
        
        LatLng? coordenada = await geocodeCep(cep, infoPorCep[cep]);
        
        if (coordenada != null) {
          double radius = 25.0 + (quantidade * 2);
          radius = radius.clamp(20.0, 70.0);
          
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
          print('✅ CEP $cep geocodificado!');
        } else {
          print('❌ Falha ao geocodificar CEP $cep');
        }
        
        await Future.delayed(const Duration(milliseconds: 500));
      }

      print('✅ Círculos criados: ${circles.length}');
      
      setState(() {
        heatCircles = circles;
        isLoading = false;
        errorMessage = '';
        detalhesErro = '';
      });

      if (circles.isEmpty) {
        setState(() {
          errorMessage = 'Não foi possível geocodificar nenhum CEP. Verifique sua conexão com a internet.';
        });
      }

    } catch (e) {
      print('❌ ERRO: $e');
      setState(() {
        errorMessage = 'Erro ao carregar dados';
        detalhesErro = e.toString();
        isLoading = false;
        heatCircles = [];
      });
    }
  }

  Future<LatLng?> geocodeCep(String cep, Map<String, String>? info) async {
    // Tentativa 1: ViaCEP + Nominatim
    try {
      final viaCepUrl = 'https://viacep.com.br/ws/$cep/json/';
      final response = await http.get(Uri.parse(viaCepUrl)).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (!data.containsKey('erro')) {
          final cidade = data['localidade'] ?? '';
          final uf = data['uf'] ?? '';
          final bairro = data['bairro'] ?? '';
          final logradouro = data['logradouro'] ?? '';
          
          if (cidade.isNotEmpty) {
            // Tentar com endereço completo
            if (logradouro.isNotEmpty && logradouro != 'null') {
              String query = '$logradouro, $bairro, $cidade, $uf, Brasil';
              LatLng? coord = await buscarNominatim(query);
              if (coord != null) return coord;
            }
            
            // Tentar com cidade e estado
            String query = '$cidade, $uf, Brasil';
            LatLng? coord = await buscarNominatim(query);
            if (coord != null) return coord;
          }
        }
      }
    } catch (e) {
      print('⚠️ ViaCEP erro: $e');
    }
    
    // Tentativa 2: Usar informações do banco
    if (info != null) {
      final cidade = info['cidade'] ?? '';
      final bairro = info['bairro'] ?? '';
      final logradouro = info['logradouro'] ?? '';
      
      if (cidade.isNotEmpty) {
        // Tentar com endereço completo
        if (logradouro.isNotEmpty && bairro.isNotEmpty) {
          String query = '$logradouro, $bairro, $cidade, Brasil';
          LatLng? coord = await buscarNominatim(query);
          if (coord != null) return coord;
        }
        
        // Tentar com cidade e bairro
        if (bairro.isNotEmpty) {
          String query = '$bairro, $cidade, Brasil';
          LatLng? coord = await buscarNominatim(query);
          if (coord != null) return coord;
        }
        
        // Tentar só com a cidade
        LatLng? coord = await buscarNominatim(cidade);
        if (coord != null) return coord;
      }
    }
    
    return null;
  }
  
  Future<LatLng?> buscarNominatim(String query) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      
      // Tentativa 1: Nominatim principal
      String url = 'https://nominatim.openstreetmap.org/search?q=$encodedQuery&format=json&limit=1&countrycodes=br';
      
      var response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept': 'application/json',
          'Accept-Language': 'pt-BR,pt;q=0.9',
        },
      ).timeout(const Duration(seconds: 8));
      
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final lat = double.tryParse(data[0]['lat'].toString());
          final lon = double.tryParse(data[0]['lon'].toString());
          if (lat != null && lon != null) {
            print('✅ Nominatim: $query → ($lat, $lon)');
            return LatLng(lat, lon);
          }
        }
      }
      
      // Tentativa 2: Nominatim europeu (fallback)
      url = 'https://eu1.nominatim.openstreetmap.org/search?q=$encodedQuery&format=json&limit=1&countrycodes=br';
      
      response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));
      
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final lat = double.tryParse(data[0]['lat'].toString());
          final lon = double.tryParse(data[0]['lon'].toString());
          if (lat != null && lon != null) {
            print('✅ Nominatim EU: $query → ($lat, $lon)');
            return LatLng(lat, lon);
          }
        }
      }
      
    } catch (e) {
      print('⚠️ Nominatim erro: $e');
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
          'Mapa de Calor',
          style: TextStyle(color: kDarkGray, fontWeight: FontWeight.w600, fontSize: 16),
        ),
        centerTitle: true,
        actions: [
          if (!isLoading && totalClientes > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '$totalClientes leads',
                style: const TextStyle(color: kRed, fontWeight: FontWeight.w500),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          
          // Botão de Filtros
          if (!isLoading && heatCircles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: _mostrarFiltros,
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
          
          if (!isLoading && heatCircles.isNotEmpty) 
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
          
          // Legenda
          if (!isLoading && heatCircles.isNotEmpty)
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
                  _buildLegendaItem(Colors.red, 'Muito Alta', '10+'),
                  _buildLegendaItem(Colors.deepOrange, 'Alta', '5-9'),
                  _buildLegendaItem(Colors.orange, 'Média', '3-4'),
                  _buildLegendaItem(Colors.yellow.shade700, 'Baixa', '1-2'),
                ],
              ),
            ),
          
          const SizedBox(height: 8),
        ],
      ),
    );
  }
  
  Widget _buildMapa() {
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            if (errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  errorMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
      );
    }
    
    if (errorMessage.isNotEmpty && heatCircles.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              if (detalhesErro.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    detalhesErro,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: carregarClientes,
                icon: const Icon(Icons.refresh),
                label: const Text("Tentar Novamente"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kRed,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    if (heatCircles.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text("Nenhum ponto para exibir no mapa"),
            SizedBox(height: 8),
            Text(
              "Tente novamente mais tarde",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    // Aplicar filtros
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
  
  Widget _buildLegendaItem(Color cor, String texto, String quantidade) {
    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: cor.withOpacity(0.6),
            shape: BoxShape.circle,
            border: Border.all(color: cor, width: 2),
          ),
        ),
        const SizedBox(height: 4),
        Text(texto, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
        Text(quantidade, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}