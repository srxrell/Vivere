import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:towards_proj/ai_chat.dart';
import 'package:towards_proj/forecast_test.dart';
import 'locations_comparison.dart';
import 'country_map_selection_screen.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown/flutter_markdown.dart'; // Markdown

enum ContentSegment { forecast, askAI, compare }

class MapDetailScreen extends StatefulWidget {
  final String title;
  final LatLng location;

  const MapDetailScreen({
    super.key,
    required final this.title,
    required final this.location,
  });

  @override
  State<MapDetailScreen> createState() => _MapDetailScreenState();
}

class _MapDetailScreenState extends State<MapDetailScreen> {
  ContentSegment _selectedSegment = ContentSegment.forecast;
  String? _compareTitle;
  LatLng? _compareLocation;

  late int _confirmedYear;
  late int _confirmedMonthIndex;
  bool _showConfirmButton = false;

  final int _currentYear = 2025;
  final int _startYear = 2015;
  final int _currentMonthIndex = 9;

  final List<String> _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];

  late int _selectedYear;
  late int _selectedMonthIndex;

  late Future<Map<String, dynamic>> _weatherDataFuture;

  String? _aiImprovementSuggestion;
  bool _isFetchingImprovement = false;

  @override
  void initState() {
    super.initState();
    _selectedYear = _currentYear;
    _selectedMonthIndex = _currentMonthIndex;

    _confirmedYear = _selectedYear;
    _confirmedMonthIndex = _selectedMonthIndex;

    _weatherDataFuture = _fetchData();
  }

  Future<Map<String, dynamic>> _fetchData() async {
    // Correctly forms the YYYY-MM-DD string as the API requires
    final monthString = (_confirmedMonthIndex + 1).toString().padLeft(2, '0');
    final date = '$_confirmedYear-$monthString-01'; 
    final apiUrl =
        "https://towards-project.onrender.com/weather?city=${widget.title}&date=$date";

    int maxRetries = 3;
    int currentRetry = 0;

    while (currentRetry < maxRetries) {
      try {
        final response = await http.get(Uri.parse(apiUrl));
        if (response.statusCode == 200) {
          return json.decode(response.body) as Map<String, dynamic>;
        } else {
          print(
              'API Error (Weather): Failed to load data for ${widget.title}. Status: ${response.statusCode}. Date: $date');
          if (response.statusCode >= 500) {
            currentRetry++;
            await Future.delayed(Duration(seconds: 1 << (currentRetry - 1)));
            continue;
          }
          break;
        }
      } catch (e) {
        print('Network Error (Weather): $e');
        currentRetry++;
        await Future.delayed(Duration(seconds: 1 << (currentRetry - 1)));
      }
    }

    // Fallback/Mock data (Now using the correct YYYY-MM-DD format for the mock date)
    final mockDate = '$_confirmedYear-$monthString-01'; 
    return {
      'city': widget.title,
      'temperature': 26,
      'conditions': 'Partially cloudy',
      'air_purity': 30,
      'road_traffic': 46,
      'crime_risks': 41,
      'life_comfort_index': 54.5,
      'pressure': 1024,
      'date': mockDate, // Use consistent YYYY-MM-DD format for mock
      'temp_max': 26,
      'temp_min': 12,
      'humidity': 21,
      'wind_speed': 3.6,
      'ai_forecast': "Expect 26.0°C with partially cloudy skies, low humidity at 21.0% and a light breeze of 3.6 m/s; consider sunglasses and light layers for a comfortable day.",
    };
  }

  Future<void> _fetchImprovementSuggestion(Map<String, dynamic> data) async {
    setState(() {
      _isFetchingImprovement = true;
      _aiImprovementSuggestion = null;
    });

    final monthString = (_confirmedMonthIndex + 1).toString().padLeft(2, '0');
    final date = '$_confirmedYear-$monthString-01';
    const url = "https://towards-project.onrender.com/improve";

    final body = {
      "city": widget.title,
      "date": date,
      "metrics": data,
    };

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: json.encode(body),
      );

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        try {
          // ignore: unused_local_variable
          var d = json.decode(response.body);
          setState(() {
            _aiImprovementSuggestion = json.decode(response.body)['suggestions'] ??
                "AI did not return a specific suggestion.";
          });
        } catch (e) {
          setState(() {
            _aiImprovementSuggestion = "Error decoding response: $e";
          });
        }
      } else {
        setState(() {
          _aiImprovementSuggestion = "Error: ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        _aiImprovementSuggestion =
            "Network Error: Could not connect to the improvement service. Check server address: $e";
      });
    } finally {
      setState(() {
        _isFetchingImprovement = false;
      });
    }
  }

  Widget _buildYearSlider() {
    final double minYear = _startYear.toDouble();
    final double maxYear = _currentYear.toDouble();
    final int yearCount = _currentYear - _startYear;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
          child: Text(
            "Year: $_selectedYear",
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 20.0,
            trackShape: const RoundedRectSliderTrackShape(),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10.0),
            overlayShape: SliderComponentShape.noOverlay,
            activeTrackColor: const Color(0xFF2C3DBF),
            inactiveTrackColor: Colors.white30,
            thumbColor: const Color(0xFF2C3DBF),
          ),
          child: Slider(
            value: _selectedYear.toDouble(),
            onChanged: (double newYearValue) {
              final newYear = newYearValue.round();
              if (_selectedYear != newYear) {
                setState(() {
                  _selectedYear = newYear;
                  if (_selectedYear == _currentYear &&
                      _selectedMonthIndex > _currentMonthIndex) {
                    _selectedMonthIndex = _currentMonthIndex;
                  }
                  _showConfirmButton = true;
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
    int maxMonthIndex =
        _selectedYear == _currentYear ? _currentMonthIndex : 11;
    final double monthSliderValue =
        _selectedMonthIndex.toDouble().clamp(0.0, maxMonthIndex.toDouble());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              const EdgeInsets.only(left: 16.0, top: 16.0, bottom: 8.0),
          child: Text(
            "Month: ${_monthNames[_selectedMonthIndex]}",
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 20.0,
            trackShape: const RoundedRectSliderTrackShape(),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10.0),
            overlayShape: SliderComponentShape.noOverlay,
            activeTrackColor: const Color(0xFF2C3DBF),
            inactiveTrackColor: Colors.white30,
            thumbColor: const Color(0xFF2C3DBF),
          ),
          child: Slider(
            value: monthSliderValue,
            onChanged: (double newMonthValue) {
              final newMonthIndex =
                  newMonthValue.round().clamp(0, maxMonthIndex);
              if (_selectedMonthIndex != newMonthIndex) {
                setState(() {
                  _selectedMonthIndex = newMonthIndex;
                  _showConfirmButton = true;
                });
              }
            },
            min: 0.0,
            max: 11.0,
            divisions: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryControls() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16, bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1E39),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "View Historical Data",
            style: TextStyle(
                fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const Divider(color: Colors.white12, height: 20),
          _buildYearSlider(),
          _buildMonthSlider(),
          if (_showConfirmButton)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2C3DBF),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      _confirmedYear = _selectedYear;
                      _confirmedMonthIndex = _selectedMonthIndex;
                      _aiImprovementSuggestion = null;
                      _weatherDataFuture = _fetchData();
                      _showConfirmButton = false;
                    });
                  },
                  child: const Text(
                    "Confirm",
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNavButton(String label, VoidCallback onTap, bool isActive) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.white70,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForecastSummary(Map<String, dynamic> data) {
    // Determine the displayed date based on the confirmed selection (always the 1st of the month).
    // This avoids relying on the format of the 'date' field in the API response,
    // which may be poorly formatted or cause client-side parsing errors.
    final String dateString =
        "${_monthNames[_confirmedMonthIndex]} 1, $_confirmedYear";

    final String conditions = data['conditions'] ?? 'N/A';
    final String aiForecast = data['ai_forecast'] ?? 'No AI forecast available.';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF2C3DBF).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2C3DBF), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                conditions,
                style: const TextStyle(
                    fontSize: 24,
                    color: Color(0xFF0B1E39),
                    fontWeight: FontWeight.w600),
              ),
              Text(
                dateString,
                style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF0B1E39),
                    fontWeight: FontWeight.w400),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            "AI Summary:",
            style: TextStyle(
                fontSize: 16,
                color: Color(0xFF0B1E39),
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            aiForecast,
            style: const TextStyle(fontSize: 14, color: Color(0xFF0B1E39)),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherDetailRow(
      String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

    Widget _buildQuakeAccordion(Map<String, dynamic> quake) {
    final mag = quake['mag'] ?? 0.0;
    final place = quake['place'] ?? "Unknown location";
    final timeMs = quake['time'] ?? 0;

    // Преобразуем timestamp в дату
    final date = DateTime.fromMillisecondsSinceEpoch(timeMs);
    final formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(date);

    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: ExpansionTile(
        collapsedIconColor: Colors.white70,
        iconColor: Colors.white,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Row(
          children: [
            Icon(Icons.waves, color: Colors.redAccent, size: 20),
            const SizedBox(width: 8),
            Text("M $mag", style: const TextStyle(color: Colors.white, fontSize: 15)),
            const Spacer(),
            Text(formattedDate,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.place, color: Colors.blueAccent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  place,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget buildInfoContainer(Map<String, dynamic> data) {
    final tempMax = data['temp_max'] ?? 'N/A';
    final tempMin = data['temp_min'] ?? 'N/A';
    final humidity = data['humidity'] ?? 'N/A';
    final windSpeed = data['wind_speed'] ?? 'N/A';
    final pressure = data['pressure'] ?? 'N/A';
    // ignore: unused_local_variable
    final crimeRisks = data['crime_risks'] ?? 0;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1E39),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "${widget.title} (${_monthNames[_confirmedMonthIndex]}, $_confirmedYear)",
            style: const TextStyle(
                fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            "Historical and actual information about this global city",
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 20),

          // --- Detailed Weather Stats ---
          const Text("Weather Details",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const Divider(color: Colors.white12, height: 20),

          _buildWeatherDetailRow("Max Temp", "$tempMax°C",
              Icons.thermostat_auto, Colors.redAccent),
          _buildWeatherDetailRow("Min Temp", "$tempMin°C",
              Icons.thermostat_auto, Colors.lightBlueAccent),
          _buildWeatherDetailRow(
              "Humidity", "$humidity%", Icons.water_drop, Colors.cyan),
          _buildWeatherDetailRow(
              "Wind Speed", "$windSpeed m/s", Icons.air, Colors.greenAccent),
          _buildWeatherDetailRow(
              "Pressure", "$pressure hPa", Icons.speed, Colors.purpleAccent),

          const SizedBox(height: 20),

          // --- General Metrics (Bar View) ---
          const Text("City Metrics",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const Divider(color: Colors.white12, height: 20),

          _buildInfoBar(
  "Temperature",
  "${(data['temperature'] ?? 0)}°C",
  ((data['temperature'] ?? 0) as num).toDouble().clamp(0, 60) / 60,
),
_buildInfoBar(
  "Air purity",
  "${(data['air_purity'] ?? 0)}%",
  ((data['air_purity'] ?? 0) as num).toDouble() / 100,
),
_buildInfoBar(
  "Road traffic",
  "${(data['road_traffic'] ?? 0)}%",
  ((data['road_traffic'] ?? 0) as num).toDouble() / 100,
),
_buildInfoBar(
  "Life comfort index",
  "${((data['life_comfort_index'] ?? 0) as num).toDouble().round()}%",
  ((data['life_comfort_index'] ?? 0) as num).toDouble() / 100,
),
_buildInfoBar(
  "Population",
  "${((data['city_population'] ?? 0) as num).toDouble().round()}%",
  ((data['city_population'] ?? 0) as num).toDouble() / 100,
),

              const SizedBox(height: 20),

          // --- Earthquake Metrics ---
          const Text("Earthquake Info",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const Divider(color: Colors.white12, height: 20),

          _buildInfoBar(
              "Earthquake Risk",
              "${(data['earthquake_risk'])}%",
              (data['earthquake_risk'] as num).toDouble().clamp(0.0, 1.0)),

          _buildInfoBar("Earthquake Count", "${data['earthquake_count']}",
              ((data['earthquake_count'] as num) / 100).clamp(0.0, 1.0)),

          _buildInfoBar("Max Magnitude", "${data['earthquake_max_mag']}",
              ((data['earthquake_max_mag'] as num) / 10).clamp(0.0, 1.0)),

          const SizedBox(height: 20),

          // --- Recent Quakes ---
          const Text("Recent Quakes",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const Divider(color: Colors.white12, height: 20),

          ...(data['recent_quakes'] as List<dynamic>? ?? [])
              .map((quake) => _buildQuakeAccordion(quake))
              .toList(),

          Padding(
            padding: const EdgeInsets.only(top: 20.0),
            child: Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2C3DBF),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: _isFetchingImprovement
                    ? null
                    : () => _fetchImprovementSuggestion(data),
                child: _isFetchingImprovement
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        "Suggest Improvement",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBar(String label, String value, double percent) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2C3DBF),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: Colors.white)),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 2,
                valueIndicatorColor: Colors.white,
                thumbShape: SliderComponentShape.noThumb,
                overlayShape: SliderComponentShape.noOverlay,
                activeTrackColor: Colors.white,
                secondaryActiveTrackColor: Colors.white,
                inactiveTrackColor: Colors.white38,
              ),
              child: Slider(
                value: percent.clamp(0.0, 1.0),
                onChanged: null,
                min: 0,
                max: 1,
              ),
            ),
          ),
          Text("• $value", style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildAiSuggestion() {
    if (_aiImprovementSuggestion == null) return const SizedBox.shrink();

    final markdownStyleSheet =
        MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: const TextStyle(color: Color(0xFF0B1E39), fontSize: 14, height: 1.4),
      listBullet: const TextStyle(color: Color(0xFF0B1E39), fontSize: 14),
      strong: const TextStyle(
          color: Color(0xFF0B1E39), fontWeight: FontWeight.bold),
      h1: const TextStyle(
          color: Color(0xFF0B1E39), fontSize: 18, fontWeight: FontWeight.bold),
      h2: const TextStyle(
          color: Color(0xFF0B1E39), fontSize: 16, fontWeight: FontWeight.bold),
      a: const TextStyle(
          color: Color(0xFF2C3DBF), decoration: TextDecoration.underline),
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFE0E7FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2C3DBF), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "AI Improvement Suggestion",
            style: TextStyle(
                fontSize: 18,
                color: Color(0xFF0B1E39),
                fontWeight: FontWeight.bold),
          ),
          const Divider(color: Colors.grey, height: 20),
          MarkdownBody(
            data: _aiImprovementSuggestion!,
            selectable: true,
            styleSheet: markdownStyleSheet,
          ),
        ],
      ),
    );
  }

  void _navigateToComparison(BuildContext context) {
    if (_compareTitle != null && _compareLocation != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LocationsComparisonScreen(
            title1: widget.title,
            location1: widget.location,
            title2: _compareTitle!,
            location2: _compareLocation!,
            onAddCountryTap: () => _navigateToCountrySelection(context),
          ),
        ),
      );
    } else {
      _navigateToCountrySelection(context);
    }
  }

  void _navigateToCountrySelection(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute<SelectedCountry>(
        builder: (context) => const CountryMapSelectionScreen(),
      ),
    );

    if (result is SelectedCountry) {
      setState(() {
        _compareTitle = result.title;
        _compareLocation = result.location;
      });

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LocationsComparisonScreen(
              title1: widget.title,
              location1: widget.location,
              title2: _compareTitle,
              location2: _compareLocation,
              onAddCountryTap: () => _navigateToCountrySelection(context),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double xAlignment;
    switch (_selectedSegment) {
      case ContentSegment.forecast:
        xAlignment = -1.0;
        break;
      case ContentSegment.askAI:
        xAlignment = 0.0;
        break;
      case ContentSegment.compare:
        xAlignment = 1.0;
        break;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(left: 15, right: 15, top: 5, bottom: 10),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFF0B1E39),
            borderRadius: BorderRadius.circular(33333),
          ),
          child: Stack(
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                alignment: Alignment(xAlignment, 0.0),
                child: FractionallySizedBox(
                  widthFactor: 1 / 3,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF2C3DBF),
                      borderRadius: BorderRadius.all(Radius.circular(3333)),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  _buildNavButton(
                    'Forecast',
                    () {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => ForecastScreen(
                                cityName: widget.title,
                                cityLocation: widget.location,
                                selectedYear: _selectedYear,
                                selectedMonthIndex: _selectedMonthIndex,
                              )));
                      setState(() {
                        _selectedSegment = ContentSegment.forecast;
                      });
                    },
                    _selectedSegment == ContentSegment.forecast,
                  ),
                  _buildNavButton(
                    'Ask AI',
                    () {
                      Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const AiChat()));
                      // Note: We don't change _selectedSegment here, as we are navigating away.
                    },
                    _selectedSegment == ContentSegment.askAI,
                  ),
                  _buildNavButton(
                    'Compare',
                    () {
                      _navigateToComparison(context);
                      // Note: We don't change _selectedSegment here, as we are navigating away.
                    },
                    _selectedSegment == ContentSegment.compare,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 200,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: widget.location,
                  initialZoom: 13.0,
                  maxZoom: 18.0,
                  minZoom: 5.0,
                  interactionOptions:
                      const InteractionOptions(flags: InteractiveFlag.none),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        width: 40,
                        height: 40,
                        point: widget.location,
                        child: const Icon(Icons.location_pin,
                            color: Color(0xFF2C3DBF), size: 40),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: FutureBuilder<Map<String, dynamic>>(
                  future: _weatherDataFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF2C3DBF)),
                        ),
                      );
                    } else if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error loading data: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      );
                    } else if (snapshot.hasData) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildForecastSummary(snapshot.data!), // New Summary
                          buildInfoContainer(snapshot.data!),
                          _buildAiSuggestion(),
                          _buildHistoryControls(),
                        ],
                      );
                    } else {
                      return const SizedBox();
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
