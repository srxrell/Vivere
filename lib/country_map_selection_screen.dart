import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Класс для возврата данных о выбранной стране
class SelectedCountry {
  final String title;
  final LatLng location;

  SelectedCountry(this.title, this.location);
}

class CountryMapSelectionScreen extends StatefulWidget {
  const CountryMapSelectionScreen({super.key});

  @override
  State<CountryMapSelectionScreen> createState() => _CountryMapSelectionScreenState();
}

class _CountryMapSelectionScreenState extends State<CountryMapSelectionScreen> {
  final List<Marker> initialMarkers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeMarkers();
  }

  void _initializeMarkers() {
    // Список городов, которые будут отображаться на карте
    final cities = {
      'Tokyo': LatLng(35.6895, 139.6917),
      'London': LatLng(51.5074, 0.1278),
      'Rio de Janeiro': LatLng(-22.9068, -43.1729),
      'Cairo': LatLng(30.0444, 31.2357),
      'Sydney': LatLng(-33.8688, 151.2093),
      'Moscow': LatLng(55.7558, 37.6173),
      'Ashgabat': LatLng(37.9601, 58.3261), // Добавим для примера
      'Paris': LatLng(48.8566, 2.3522),
    };

    cities.forEach((title, location) {
      initialMarkers.add(
        Marker(
          width: 40,
          height: 40,
          point: location,
          child: GestureDetector(
            // ПРИ ВЫБОРЕ МАРКЕРА: Возвращаем данные
            onTap: () => _returnSelectedCity(context, title, location),
            child: Icon(Icons.location_on, color: _getCityColor(title), size: 40),
          ),
        ),
      );
    });
  }

  Color _getCityColor(String city) {
    switch (city) {
      case 'Tokyo': return Colors.red;
      case 'London': return Colors.blue;
      case 'Rio de Janeiro': return Colors.green;
      case 'Cairo': return Colors.purple;
      case 'Sydney': return Colors.orange;
      case 'Moscow': return Colors.brown;
      case 'Paris': return Colors.pink;
      default: return const Color(0xFF2C3DBF);
    }
  }
  
  // *** КЛЮЧЕВОЙ МЕТОД: Возвращает выбранный город ***
  void _returnSelectedCity(BuildContext context, String title, LatLng location) {
    Navigator.pop(context, SelectedCountry(title, location));
  }

  // --- Функция геокодирования OpenStreetMap (Nominatim) ---
  Future<LatLng?> _geocodeCity(String city) async {
    final encodedCity = Uri.encodeComponent(city.trim());
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

  // --- Обработка поиска и навигации (с возвратом) ---
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
      // ПРИ ПОИСКЕ: Возвращаем данные
      _returnSelectedCity(context, city, location);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('City "$city" not found. Please try another name.', style: const TextStyle(color: Colors.white)), 
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
              enabled: !_isLoading,
              decoration: InputDecoration(
                hintText: 'Search city for comparison...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF2C3DBF)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.blueGrey.shade50,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onSubmitted: (value) {
                _handleSearch(context, value);
              },
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2C3DBF),
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
                    icon: const Icon(Icons.send, color: Colors.white),
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
    const center = LatLng(20.0, 0.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select City for Comparison', style: TextStyle(fontSize: 20, color: Colors.white)),
        backgroundColor: const Color(0xFF2C3DBF),
        toolbarHeight: 70,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white), // Цвет стрелки "назад"
      ),
      body: Column(
        children: [
          _buildSearchBar(context),
          Expanded(
            child: FlutterMap(
              options: const MapOptions(
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