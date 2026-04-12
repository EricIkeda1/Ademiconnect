
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

const Color kRed = Color(0xFFED3B2E);

class MapaPage extends StatefulWidget {
  MapaPage({super.key});

  @override
  State<MapaPage> createState() => _MapaPageState();
}

class _MapaPageState extends State<MapaPage> {
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
          statusBarBrightness: Brightness.light,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kRed),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Mapa Interativo',
          style: TextStyle(
            color: Color(0xFF231F20),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
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
              boxShadow: const [
                BoxShadow(color: Color(0x14000000), blurRadius: 6)
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.thermostat, color: kRed),
                const SizedBox(width: 8),

                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Mapa de Calor - Leads",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "10 leads encontrados",
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),

                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.filter_alt_outlined, size: 18),
                  label: const Text("Filtros"),
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
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(-25.4284, -49.2733),
                    initialZoom: 13,
                  ),
                  children: [

                  TileLayer(
                    urlTemplate: "https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png",
                    subdomains: ['a', 'b', 'c'],
                    userAgentPackageName: 'com.example.leadmanager',
                  ),

                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: LatLng(-25.4284, -49.2733),
                          radius: 80,
                          color: Colors.red.withOpacity(0.3),
                        ),
                        CircleMarker(
                          point: LatLng(-25.45, -49.25),
                          radius: 60,
                          color: Colors.orange.withOpacity(0.3),
                        ),
                        CircleMarker(
                          point: LatLng(-25.40, -49.30),
                          radius: 40,
                          color: Colors.yellow.withOpacity(0.3),
                        ),
                      ],
                    ),

                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(-25.4284, -49.2733),
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.location_pin,
                            color: Colors.red,
                            size: 40,
                          ),
                        )
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
