import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class SelectedCountry {
  final String title;
  final LatLng location;

  SelectedCountry(this.title, this.location);
}

class CountrySelectionScreenPlaceholder extends StatelessWidget {
  const CountrySelectionScreenPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Country for Comparison', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0B1E39),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                "Please choose a city to compare with (Simulated Selection):",
                style: TextStyle(color: Colors.white, fontSize: 18),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            _buildCountryButton(
              context,
              'Tokyo',
              LatLng(35.6895, 139.6917),
              Colors.red,
            ),
            const SizedBox(height: 10),
            _buildCountryButton(
              context,
              'Paris',
              LatLng(48.8566, 2.3522),
              Colors.blue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountryButton(BuildContext context, String title, LatLng location, Color color) {
    return ElevatedButton(
      onPressed: () {
        // Возвращаем выбранную страну обратному экрану
        Navigator.pop(context, SelectedCountry(title, location));
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, color: Colors.white),
      ),
    );
  }
}