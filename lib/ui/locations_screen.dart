import 'package:flutter/material.dart';
import '../data/database_helper.dart';
import '../data/models.dart';

class LocationsScreen extends StatefulWidget {
  const LocationsScreen({super.key});

  @override
  State<LocationsScreen> createState() => _LocationsScreenState();
}

class _LocationsScreenState extends State<LocationsScreen> {
  List<WorkLocationEntity> _locations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    final locations = await DatabaseHelper.instance.getAllWorkLocations();
    if (!mounted) return;
    setState(() {
      _locations = locations;
      _isLoading = false;
    });
  }

  void _showAddLocationDialog() {
    final nameController = TextEditingController();
    final latController = TextEditingController(text: '48.8566');
    final lonController = TextEditingController(text: '2.3522');
    final radiusController = TextEditingController(text: '300');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ajouter un lieu de travail'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nom du lieu (ex: Bureau)'),
              ),
              TextField(
                controller: latController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Latitude'),
              ),
              TextField(
                controller: lonController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Longitude'),
              ),
              TextField(
                controller: radiusController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Rayon (mètres)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final lat = double.tryParse(latController.text) ?? 0.0;
              final lon = double.tryParse(lonController.text) ?? 0.0;
              final radius = double.tryParse(radiusController.text) ?? 300.0;
              final navigator = Navigator.of(dialogContext);

              if (name.isNotEmpty) {
                await DatabaseHelper.instance.insertWorkLocation(
                  WorkLocationEntity(
                    name: name,
                    latitude: lat,
                    longitude: lon,
                    radius: radius,
                    isActive: true,
                    geofenceUid: 'geo_${DateTime.now().millisecondsSinceEpoch}',
                  ),
                );
                if (!mounted) return;
                navigator.pop();
                await _loadLocations();
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteLocation(int id) async {
    await DatabaseHelper.instance.deleteWorkLocation(id);
    await _loadLocations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lieux de travail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddLocationDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _locations.isEmpty
              ? const Center(
                  child: Text('Aucun lieu enregistré. Appuyez sur + pour en ajouter un.'),
                )
              : ListView.builder(
                  itemCount: _locations.length,
                  itemBuilder: (context, index) {
                    final loc = _locations[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(loc.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Lat: ${loc.latitude}, Lon: ${loc.longitude}\nRayon: ${loc.radius}m'),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteLocation(loc.id!),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddLocationDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
