// Renamed from forecast_screen.dart to match the import in MapDetailScreen.
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';

// Этот виджет будет использоваться для отображения данных прогноза для конкретного города.
class ForecastScreen extends StatefulWidget {
  final String cityName;
  final LatLng cityLocation;
  final int selectedYear;
  final int selectedMonthIndex;

  const ForecastScreen({
    super.key,
    required this.cityName,
    required this.cityLocation,
    required this.selectedYear,
    required this.selectedMonthIndex,
  });

  @override
  State<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends State<ForecastScreen> {
  // --- Historical/Future Data Controls ---
  // Максимальная дата, доступная для прогноза в API (на основе предоставленного примера: 26-12-2026)
  final int _currentApiYear = 2027;
  final int _startYear = 2025; // Диапазон исторических данных
  final int _currentApiMonthIndex = 11; // Декабрь (0-indexed)

  final List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  // Эти переменные используются для ползунков внутри этого экрана, 
  // но инициализируются данными, переданными извне.
  late int _selectedYear;
  late int _selectedMonthIndex;

  late Future<Map<String, dynamic>> _forecastDataFuture;
  // --- End of Controls ---

  // Цветовая палитра из предоставленных изображений
  static const Color _darkBackground = Color(0xFF0B1E39);
  static const Color _infoBarBlue = Color(0xFF2C3DBF);

  @override
  void initState() {
    super.initState();
    // Инициализируем ползунки данными, переданными из MapDetailScreen
    _selectedYear = widget.selectedYear;
    _selectedMonthIndex = widget.selectedMonthIndex;

    _forecastDataFuture = _fetchForecastData();
  }
  
  // Вспомогательный метод для форматирования даты
  String get _currentDisplayDate {
    return '${_monthNames[_selectedMonthIndex]}, $_selectedYear';
  }

  // --- Функция для получения данных по API ---
  Future<Map<String, dynamic>> _fetchForecastData() async {
    // API ожидает формат YYYY-MM-DD
    final monthString = (_selectedMonthIndex + 1).toString().padLeft(2, '0');
    final date = '$_selectedYear-$monthString-26'; // Используем 26-е число для API

    // Используем динамические переменные для города и даты
    final apiUrl = "https://towards-project.onrender.com/weather?city=${widget.cityName}&date=$date";

    print('Fetching data for: $apiUrl');

    int maxRetries = 3;
    int currentRetry = 0;

    while (currentRetry < maxRetries) {
      try {
        final response = await http.get(Uri.parse(apiUrl));
        if (response.statusCode == 200) {
          return json.decode(response.body) as Map<String, dynamic>;
        } else {
          print('API Error: Failed to load data. Status: ${response.statusCode}. Date: $date');
          if (response.statusCode >= 500) {
            currentRetry++;
            await Future.delayed(Duration(milliseconds: 500 * (1 << (currentRetry - 1)))); // Exponential backoff
            continue;
          }
          break;
        }
      } catch (e) {
        print('Network Error: $e');
        currentRetry++;
        await Future.delayed(Duration(milliseconds: 500 * (1 << (currentRetry - 1)))); // Exponential backoff
      }
    }

    // Возвращаем данные об ошибке при окончательном сбое
    return {
      'city': widget.cityName,
      'temperature': 0,
      'air_purity': 0,
      'road_traffic': 0,
      'crime_risks': 0,
      'life_comfort_index': 0,
      'date': date,
      'error': 'Failed to load data after $maxRetries attempts.',
    };
  }
  // --- Конец функции получения данных ---

  // Виджет для создания полосы метрики с индикатором прогресса
  Widget _buildMetricBar(String label, String value, double percent) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _infoBarBlue,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 15)),
          ),
          Expanded(
            child: SliderTheme(
              data:  SliderThemeData(
                trackHeight: 2,
                thumbShape: SliderComponentShape.noThumb,
                overlayShape: SliderComponentShape.noOverlay,
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white38,
              ),
              child: Slider(
                value: percent.clamp(0.0, 1.0),
                onChanged: null, // Слайдер только для отображения
                min: 0,
                max: 1,
              ),
            ),
          ),
          Text("• $value", style: const TextStyle(color: Colors.white, fontSize: 15)),
        ],
      ),
    );
  }

  // Виджет, собирающий все информационные полосы
  Widget _buildInfoContainer(Map<String, dynamic> data) {
    // Безопасное извлечение данных
    final double temperature = (data['temperature'] as num? ?? 0.0).toDouble();
    final double airPurity = (data['air_purity'] as num? ?? 0.0).toDouble();
    final double roadTraffic = (data['road_traffic'] as num? ?? 0.0).toDouble();
    final double crimeRisks = (data['crime_risks'] as num? ?? 0.0).toDouble();
    final double lifeComfortIndex = (data['life_comfort_index'] as num? ?? 0.0).toDouble();
    final String? aiForecast = data['ai_forecast'] as String?; // Текст прогноза ИИ

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _darkBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "${widget.cityName} ($_currentDisplayDate)",
            style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            data.containsKey('error')
                ? 'Error: ${data['error']}'
                : "Historical and actual information about this global city",
            style: TextStyle(color: data.containsKey('error') ? Colors.redAccent : Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 20),
          // Метрики
          _buildMetricBar("Temperature", "${temperature.toStringAsFixed(1)}°C", temperature.clamp(0, 60) / 60),
          _buildMetricBar("Air purity", "${airPurity.round()}%", airPurity.clamp(0, 100) / 100),
          _buildMetricBar("Road traffic", "${roadTraffic.round()}%", roadTraffic.clamp(0, 100) / 100),
          _buildMetricBar("Crime risks", "${crimeRisks.round()}%", crimeRisks.clamp(0, 100) / 100),
          _buildMetricBar("Life comfort index", "${lifeComfortIndex.round()}%", lifeComfortIndex.clamp(0, 100) / 100),

          // Отображение прогноза ИИ, если он доступен (дата в будущем)
          if (aiForecast != null && aiForecast.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              "AI Forecast:",
              style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              aiForecast,
              style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 15, fontStyle: FontStyle.italic),
            ),
          ]
        ],
      ),
    );
  }

  // --- Методы для построения слайдеров (оставлены здесь, чтобы пользователь мог изменить дату в ForecastScreen) ---

  Widget _buildHistoryControls() {
      return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 16, bottom: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: _darkBackground,
              borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  const Text(
                      "Change Date (Historical/Future)",
                      style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const Divider(color: Colors.white12, height: 20),
                  _buildYearSlider(), // Год
                  _buildMonthSlider(), // Месяц
                  const SizedBox(height: 10),
                  Center(
                    child: ElevatedButton(
                      onPressed: () {
                        // Явный вызов fetchData после изменения слайдеров
                        setState(() {
                           _forecastDataFuture = _fetchForecastData();
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _infoBarBlue,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text('Confirm New Date', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  )
              ]
          ),
      );
  }

  Widget _buildYearSlider() {
    final int yearCount = _currentApiYear - _startYear;
    final double minYear = _startYear.toDouble();
    final double maxYear = _currentApiYear.toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
          child: Text(
            "Year: $_selectedYear",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 20.0,
            trackShape: const RoundedRectSliderTrackShape(),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10.0),
            overlayShape: SliderComponentShape.noOverlay,
            activeTrackColor: _infoBarBlue,
            inactiveTrackColor: Colors.white30,
            thumbColor: _infoBarBlue,
          ),
          child: Slider(
            value: _selectedYear.toDouble(),
            onChanged: (double newYearValue) {
              final newYear = newYearValue.round();
              if (_selectedYear != newYear) {
                setState(() {
                  _selectedYear = newYear;
                  if (_selectedYear == _currentApiYear && _selectedMonthIndex > _currentApiMonthIndex) {
                      _selectedMonthIndex = _currentApiMonthIndex;
                  }
                  // Не вызываем _fetchData здесь, чтобы пользователь мог подтвердить нажатием кнопки
                });
              }
            },
            min: minYear,
            max: maxYear,
            divisions: yearCount,
          ),
        ),
      ],
    );
  }

  Widget _buildMonthSlider() {
    int maxMonthIndex = _selectedYear == _currentApiYear ? _currentApiMonthIndex : 11;
    final int divisions = 11;

    final double monthSliderValue = _selectedMonthIndex.toDouble().clamp(0.0, maxMonthIndex.toDouble());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 16.0, bottom: 8.0),
          child: Text(
            "Month: ${_monthNames[_selectedMonthIndex]}",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 20.0,
            trackShape: const RoundedRectSliderTrackShape(),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10.0),
            overlayShape: SliderComponentShape.noOverlay,
            activeTrackColor: _infoBarBlue,
            inactiveTrackColor: Colors.white30,
            thumbColor: _infoBarBlue,
          ),
          child: Slider(
            value: monthSliderValue,
            onChanged: (double newMonthValue) {
              final newMonthIndex = newMonthValue.round().clamp(0, maxMonthIndex);

              if (_selectedMonthIndex != newMonthIndex) {
                setState(() {
                  _selectedMonthIndex = newMonthIndex;
                  // Не вызываем _fetchData здесь
                });
              }
            },
            min: 0.0,
            max: 11.0,
            divisions: divisions,
          ),
        ),
      ],
    );
  }
  // --- Конец методов для построения слайдеров ---


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Карта
            SizedBox(
              height: 200,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: widget.cityLocation,
                  initialZoom: 13.0,
                  maxZoom: 18.0,
                  minZoom: 5.0,
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.app',
                  ),
                  MarkerLayer(markers: [
                    Marker(
                      width: 40,
                      height: 40,
                      point: widget.cityLocation,
                      child: const Icon(Icons.location_pin, color: Color(0xFF2C3DBF), size: 40),
                    ),
                  ]),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    // Основной контейнер с информацией о прогнозе, завернутый в FutureBuilder
                    FutureBuilder<Map<String, dynamic>>(
                      future: _forecastDataFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: CircularProgressIndicator(color: _infoBarBlue),
                          ));
                        } else if (snapshot.hasError || (snapshot.hasData && snapshot.data!.containsKey('error'))) {
                            final error = snapshot.hasError ? snapshot.error.toString() : snapshot.data!['error'];
                          return Center(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10)),
                                child: Text('Error loading data: $error', style: const TextStyle(color: Colors.red)),
                            )
                          );
                        } else if (snapshot.hasData) {
                          return Column(
                            children: [
                              _buildInfoContainer(snapshot.data!), // Контейнер характеристик
                              const SizedBox(height: 24),
                              _buildHistoryControls(), // Ползунки Года/Месяца
                            ],
                          );
                        } else {
                          return const SizedBox();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
