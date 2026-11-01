import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapPickerScreen extends StatefulWidget {
  final double initialLat;
  final double initialLon;

  const MapPickerScreen({
    super.key,
    this.initialLat = 48.8566,
    this.initialLon = 2.3522,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  late LatLng _selectedPoint;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _selectedPoint = LatLng(widget.initialLat, widget.initialLon);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sélectionner le lieu sur la carte'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              Navigator.pop(context, _selectedPoint);
            },
          ),
        ],
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _selectedPoint,
          initialZoom: 15.0,
          onTap: (tapPosition, point) {
            setState(() {
              _selectedPoint = point;
            });
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.badgeuse_auto',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: _selectedPoint,
                width: 80,
                height: 80,
                child: const Icon(
                  Icons.location_pin,
                  color: Colors.red,
                  size: 40,
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16.0),
        color: Colors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Lat: ${_selectedPoint.latitude.toStringAsFixed(5)}\nLon: ${_selectedPoint.longitude.toStringAsFixed(5)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, _selectedPoint),
              icon: const Icon(Icons.check),
              label: const Text('Valider ce lieu'),
            ),
          ],
        ),
      ),
    );
  }
}
