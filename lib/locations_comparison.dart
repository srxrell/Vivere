import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class LocationsComparisonScreen extends StatefulWidget {
  final String title1;
  final LatLng location1;
  // Второй город теперь опционален, чтобы отображать "Добавить страну"
  final String? title2; 
  final LatLng? location2;
  // Callback для перехода на экран выбора
  final VoidCallback onAddCountryTap;

  const LocationsComparisonScreen({
    super.key,
    required this.title1,
    required this.location1,
    this.title2, // Опциональный
    this.location2, // Опциональный
    required this.onAddCountryTap,
  });

  @override
  State<LocationsComparisonScreen> createState() => _LocationsComparisonScreenState();
}

class _LocationsComparisonScreenState extends State<LocationsComparisonScreen> {
  // Текущий год, который будем использовать для лимита
  final int _currentYear = 2025; 
  // Лимит "в прошлое"
  final int _pastLimit = 10; 

  // Переменные состояния для хранения выбранных годов и месяцев
  late int _year1;
  late int _month1; // Новый: месяц для первого города
  late int _year2;
  late int _month2; // Новый: месяц для второго города

  @override
  void initState() {
    super.initState();
    // Изначально оба города сравниваются в текущем году и первом месяце (январь)
    _year1 = _currentYear; 
    _month1 = 1; 
    _year2 = _currentYear;
    _month2 = 1;
  }

  // Функция для форматирования месяца (добавление ведущего нуля)
  String _formatMonth(int month) {
    return month.toString().padLeft(2, '0');
  }

  // Функция для вычисления "общего индекса" (Total Index)
  double _calculateTotalIndex(Map<String, dynamic> data) {
    if (data.isEmpty) return 0.0;

    final fields = [
      'temperature', 
      'air_purity',
      'road_traffic',
      'crime_risks',
      'life_comfort_index'
    ];

    double sum = 0;
    int count = 0;
    for (var field in fields) {
      if (data.containsKey(field) && data[field] is num) {
        sum += (data[field] as num).toDouble();
        count++;
      }
    }

    if (count == 0) return 0.0;
    
    // Возвращаем среднее, деленное на 10, округленное до 2 знаков после запятой
    double averagePercentage = sum / count;
    return double.parse((averagePercentage / 10).toStringAsFixed(2)); 
  }

  // Обновленная функция для получения данных с учетом года и месяца
  Future<Map<String, dynamic>> fetchData(String city, int year, int month) async {
    final monthStr = _formatMonth(month);
    // API использует формат YYYY-MM-DD. Используем 01-е число месяца как заглушку.
    final apiUrl = "https://towards-project.onrender.com/weather?city=$city&date=$year-$monthStr-01";
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        print("Error loading data for $city ($year-$monthStr): ${response.statusCode}");
        return {};
      }
    } catch (e) {
      print("Network error for $city ($year-$monthStr): $e");
      return {};
    }
  }

  // --- МЕТОД ВЫБОРА ГОДА И МЕСЯЦА (МОДАЛЬНОЕ ОКНО) ---
  void _showYearMonthSelectionDialog(int initialYear, int initialMonth, bool isCity1) {
    final int minYear = _currentYear - _pastLimit;
    final int maxYear = _currentYear; 
    
    // Используем Map для хранения текущих значений ползунков внутри диалога
    Map<String, double> currentValues = {
      'year': initialYear.toDouble(),
      'month': initialMonth.toDouble(),
    };

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder( // Используем StatefulBuilder для обновления ползунков
          builder: (context, setStateInDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0B1E39),
              title: Text(
                "Select Date for ${isCity1 ? widget.title1 : widget.title2}", 
                style: const TextStyle(color: Colors.white)
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ползунок ГОДА
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      "Year: ${currentValues['year']!.round()}", 
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                  Slider(
                    value: currentValues['year']!,
                    min: minYear.toDouble(),
                    max: maxYear.toDouble(),
                    divisions: maxYear - minYear,
                    label: currentValues['year']!.round().toString(),
                    activeColor: const Color(0xFF2C3DBF),
                    inactiveColor: Colors.white38,
                    onChanged: (double value) {
                      setStateInDialog(() {
                        currentValues['year'] = value;
                      });
                    },
                  ),
                  
                  const Divider(color: Colors.white24),

                  // Ползунок МЕСЯЦА
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0, top: 8.0),
                    child: Text(
                      "Month: ${currentValues['month']!.round()} / 12", 
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                  Slider(
                    value: currentValues['month']!,
                    min: 1.0,
                    max: 12.0,
                    divisions: 11, // 12 месяцев -> 11 промежутков
                    label: currentValues['month']!.round().toString(),
                    activeColor: const Color(0xFF2C3DBF),
                    inactiveColor: Colors.white38,
                    onChanged: (double value) {
                      setStateInDialog(() {
                        currentValues['month'] = value;
                      });
                    },
                  ),

                  Text(
                    "Date range: $minYear-${_formatMonth(1)} - $maxYear-${_formatMonth(12)}",
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: const Text('Confirm', style: TextStyle(color: Color(0xFF2C3DBF), fontWeight: FontWeight.bold)),
                  onPressed: () {
                    // Обновляем состояние главного виджета и запускаем перерисовку
                    setState(() {
                      if (isCity1) {
                        _year1 = currentValues['year']!.round();
                        _month1 = currentValues['month']!.round();
                      } else {
                        _year2 = currentValues['year']!.round();
                        _month2 = currentValues['month']!.round();
                      }
                    });
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- BUILD WIDGETS ---

  // Обновленная карточка заголовка: теперь отображает год и месяц
  Widget _buildHeaderCard(String title, int year, int month, bool isPrimary) {
    bool isCity = title != "Add country";
    final dateStr = "$year-${_formatMonth(month)}";

    return Expanded(
      child: GestureDetector(
        // Если это не город, вызываем колбэк для добавления страны
        onTap: !isCity ? widget.onAddCountryTap : 
               // Если это город, открываем выбор даты
               () => _showYearMonthSelectionDialog(year, month, isPrimary),
        child: Container(
          height: 65,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isCity ? const Color(0xFF0B1E39) : const Color(0xFF2C3DBF), // Синий фон для кнопки "Add Country"
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: isCity
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Кнопка/индикатор выбора даты
                      GestureDetector(
                        onTap: () => _showYearMonthSelectionDialog(year, month, isPrimary), // Повторный вызов для выбора
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2C3DBF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            dateStr,
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      SizedBox(height: 6),
                    ],
                  )
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_location_alt_outlined, color: Colors.white, size: 24),
                      SizedBox(height: 8),
                      Text(
                        "Add Country",
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildComparisonRow(String label, dynamic value1, dynamic value2, {bool isComfortIndex = false, bool isData2Available = true}) {
    // Форматирование значений для первого города
    String value1Str = value1 != null 
        ? label == "Temperature" ? "${value1.round()}°C" : "${value1.round()}%"
        : "--";
        
    // Форматирование значений для второго города
    String value2Str = isData2Available && value2 != null 
        ? label == "Temperature" ? "${value2.round()}°C" : "${value2.round()}%"
        : "--"; // Если нет данных или город не выбран

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1E39),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildValueBox(value1Str),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
          ),
          _buildValueBox(value2Str),
        ],
      ),
    );
  }

  Widget _buildValueBox(String value) {
    return Container(
      width: 60,
      height: 28,
      decoration: BoxDecoration(
        color: const Color(0xFF2C3DBF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          value,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Проверяем, доступен ли второй город
    final bool isData2Available = widget.title2 != null && widget.location2 != null;

    // Определяем список Future для ожидания (теперь с учетом года и месяца)
    final List<Future<Map<String, dynamic>>> futures = [
      fetchData(widget.title1, _year1, _month1), // Город 1 с выбранной датой
      if (isData2Available) fetchData(widget.title2!, _year2, _month2), // Город 2 с выбранной датой (если выбран)
    ];
    
    // Определяем список точек для карты
    final List<LatLng> mapLocations = [
      widget.location1,
      if (isData2Available) widget.location2!,
    ];
    
    // Если есть только одна точка, центрируем карту по ней, иначе - по границам.
    final MapOptions mapOptions = mapLocations.length > 1
        ? MapOptions(
            initialCameraFit: CameraFit.bounds(
              bounds: LatLngBounds(mapLocations.first, mapLocations.last),
              padding: const EdgeInsets.all(40),
            ),
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
          )
        : MapOptions(
            initialCenter: widget.location1,
            initialZoom: 5.0,
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
          );


    return Scaffold( // Добавим фон для Scaffold
      body: FutureBuilder(
        // Future.wait будет перезапускаться при изменении _year или _month
        future: Future.wait(futures),
        builder: (context, AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF2C3DBF)));
          } else if (snapshot.hasError) {
            return const Center(
              child: Text("Error loading data", style: TextStyle(color: Colors.redAccent)),
            );
          } 

          final data1 = snapshot.data![0];
          // data2 будет доступна, только если второй город был выбран
          final data2 = isData2Available && snapshot.data!.length > 1 
            ? snapshot.data![1] 
            : <String, dynamic>{};
          
          final totalIndex1 = _calculateTotalIndex(data1);
          final totalIndex2 = isData2Available ? _calculateTotalIndex(data2) : 0.0;
          
          return Column(
            children: [
              // 🔹 Верхняя карта (Top Map)
              SizedBox(
                height: 230,
                child: FlutterMap(
                  options: mapOptions,
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: widget.location1,
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.location_pin, color: Color(0xFF2C3DBF), size: 36),
                        ),
                        if (isData2Available)
                          Marker(
                            point: widget.location2!,
                            width: 40,
                            height: 40,
                            child: const Icon(Icons.location_pin, color: Colors.red, size: 36),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // 🔹 Названия городов с датами (City Names with Date)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _buildHeaderCard(widget.title1, _year1, _month1, true), // Город 1
                    // Здесь используем логику "Add country" или Город 2
                    _buildHeaderCard(widget.title2 ?? "Add country", _year2, _month2, false), // Город 2
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // 🔹 Таблица с индексами (Table with Indices)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SingleChildScrollView(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B1E39),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF2C3DBF), width: 1.5)
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                      child: Column(
                        children: [
                          // ⭐️ Total Index Display (Общий индекс)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  data1['life_comfort_index'].toString(),
                                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                                ),
                                const Text(
                                  "LIFE COMFORT INDEX",
                                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  data2['life_comfort_index'].toString() ?? "--",
                                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          const Divider(color: Colors.white),

                          // ⭐️ Comparison Rows (Ряды сравнения)
                          _buildComparisonRow("Temperature", data1['temperature'], data2['temperature'], isData2Available: isData2Available),
                          _buildComparisonRow("Air purity", data1['air_purity'], data2['air_purity'], isData2Available: isData2Available),
                          _buildComparisonRow("Road traffic", data1['road_traffic'], data2['road_traffic'], isData2Available: isData2Available),
                          _buildComparisonRow("Crime risks", data1['crime_risks'], data2['crime_risks'], isData2Available: isData2Available),
                        //   _buildComparisonRow("Life comfort index", data1['life_comfort_index'], data2['life_comfort_index'], isComfortIndex: true, isData2Available: isData2Available),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}