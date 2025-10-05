import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'map_detail.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'forecast_test.dart';

void main() {
  runApp( MaterialApp(
    debugShowCheckedModeBanner: false,
    home: GlobalMapScreen(),
  ));
}

class GlobalMapScreen extends StatefulWidget {
  GlobalMapScreen({super.key});

  @override
  State<GlobalMapScreen> createState() => _GlobalMapScreenState();
}

class _GlobalMapScreenState extends State<GlobalMapScreen> {
  // Список маркеров
  final List<Marker> initialMarkers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeMarkers();
  }

  void _initializeMarkers() {
  final Map<String, LatLng> cities = {
    'Tokyo': LatLng(35.6895, 139.6917),
    'London': LatLng(51.5074, -0.1278),
    'Rio de Janeiro': LatLng(-22.9068, -43.1729),
    'Cairo': LatLng(30.0444, 31.2357),
    'Sydney': LatLng(-33.8688, 151.2093),
    'Moscow': LatLng(55.7558, 37.6173),
    'Mary': LatLng(37.6000, 61.8333),
    'Ashgabat': LatLng(37.9601, 58.3261),
    'Turkmenbashi': LatLng(40.0220, 52.9550),
    'Turkmenabat': LatLng(39.0696, 63.5783),
    'Dashoguz': LatLng(41.8339, 59.9650),
    'Balkanabat': LatLng(39.5100, 54.3600),
  };

  cities.forEach((title, location) {
    initialMarkers.add(
      Marker(
        width: 40,
        height: 40,
        point: location,
        child: GestureDetector(
          onTap: () => _showMarkerDetail(context, title, location),
          child: Icon(
            Icons.location_on,
            color: _getCityColor(title),
            size: 40,
          ),
        ),
      ),
    );
  });
}

Color _getCityColor(String city) {
  switch (city) {
    case 'Tokyo':
      return Colors.red;
    case 'London':
      return Colors.blue;
    case 'Rio de Janeiro':
      return Colors.pink;
    case 'Cairo':
      return Colors.purple;
    case 'Sydney':
      return Colors.orange;
    case 'Moscow':
      return Colors.brown;
    case 'Mary':
      return Colors.teal;
    case 'Ashgabat':
      return Colors.green;
    case 'Turkmenbashi':
      return Colors.cyan;
    case 'Turkmenabat':
      return Colors.indigo;
    case 'Dashoguz':
      return Colors.amber;
    case 'Balkanabat':
      return Colors.lime;
    default:
      return const Color(0xFF2C3DBF);
  }
}


  void _showMarkerDetail(BuildContext context, String title, LatLng location) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: Duration(milliseconds: 350),
        pageBuilder: (_, __, ___) => MapDetailScreen(title: title, location: location),
        transitionsBuilder: (_, animation, __, child) {
          final offsetAnimation = Tween<Offset>(
            begin: Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
          return SlideTransition(
            position: offsetAnimation,
            child: child,
          );
        },
      ),
    );
  }

  // --- Функция геокодирования OpenStreetMap (Nominatim) ---
  Future<LatLng?> _geocodeCity(String city) async {
    // Кодируем запрос для URL
    final encodedCity = Uri.encodeComponent(city.trim());
    // Nominatim URL для поиска (возвращает JSON, лимит 1 результат)
    final apiUrl = 'https://nominatim.openstreetmap.org/search?q=$encodedCity&format=json&limit=1';

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        if (data.isNotEmpty) {
          final Map<String, dynamic> result = data.first;
          final double lat = double.parse(result['lat']);
          final double lon = double.parse(result['lon']);
          return LatLng(lat, lon);
        }
      }
    } catch (e) {
      print('Geocoding API Error: $e');
    }
    return null;
  }

  // --- Обработка поиска и навигации ---
  void _handleSearch(BuildContext context, String city) async {
    if (city.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    final LatLng? location = await _geocodeCity(city);

    setState(() {
      _isLoading = false;
    });

    if (location != null) {
      _showMarkerDetail(context, city, location);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('City "$city" not found. Please try another name.', style: TextStyle(color: Colors.white)), 
          backgroundColor: Colors.red.shade700
        ),
      );
    }
  }

  // --- Поле поиска для ввода города ---
  Widget _buildSearchBar(BuildContext context) {
    TextEditingController controller = TextEditingController();
    return Container(
      padding: const EdgeInsets.all(12.0),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !_isLoading, // Отключаем ввод во время загрузки
              decoration: InputDecoration(
                hintText: 'Search any city in the world...',
                prefixIcon: Icon(Icons.search, color: Color(0xFF2C3DBF)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.blueGrey.shade50,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
              onSubmitted: (value) {
                _handleSearch(context, value);
              },
            ),
          ),
          SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: Color(0xFF2C3DBF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _isLoading 
                ? Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                    ),
                  )
                : IconButton(
                    icon: Icon(Icons.send, color: Colors.white),
                    onPressed: () {
                      _handleSearch(context, controller.text);
                    },
                  ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final center = LatLng(20.0, 0.0);

    return Scaffold(
      appBar: AppBar(
        title: Text('Global City Explorer', style: TextStyle(fontSize: 20, color: Colors.white)),
        backgroundColor: Color(0xFF2C3DBF),
        toolbarHeight: 70,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSearchBar(context),
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: 2.0, 
                maxZoom: 25.0, 
                minZoom: 2.0, 
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.app',
                ),
                MarkerLayer(markers: initialMarkers),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
