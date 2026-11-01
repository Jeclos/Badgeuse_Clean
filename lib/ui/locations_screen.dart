import 'package:flutter/material.dart';
import '../data/database_helper.dart';
import '../data/models.dart';
import '../services/location_service.dart';

class LocationsScreen extends StatefulWidget {
  const LocationsScreen({super.key});

  @override
  State<LocationsScreen> createState() => _LocationsScreenState();
}

class _LocationsScreenState extends State<LocationsScreen> {
  List<WorkLocationEntity> _locations = [];
  bool _isLoading = true;

  final _nameController = TextEditingController();
  final _latController = TextEditingController();
  final _lonController = TextEditingController();
  final _radiusController = TextEditingController(text: '300');

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

  Future<void> _getCurrentPosition() async {
    final pos = await LocationService.instance.getCurrentPosition();
    if (pos != null) {
      setState(() {
        _latController.text = pos.latitude.toStringAsFormatted();
        _lonController.text = pos.longitude.toStringAsFormatted();
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Position GPS actuelle récupérée avec succès')),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'obtenir la position GPS. Vérifiez les permissions.')),
      );
    }
  }

  Future<void> _addLocation() async {
    final name = _nameController.text.trim();
    final lat = double.tryParse(_latController.text) ?? 0.0;
    final lon = double.tryParse(_lonController.text) ?? 0.0;
    final radius = double.tryParse(_radiusController.text) ?? 300.0;

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
      _nameController.clear();
      _latController.clear();
      _lonController.clear();
      await _loadLocations();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lieu ajouté avec succès')),
      );
    }
  }

  Future<void> _toggleActive(WorkLocationEntity loc) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'work_locations',
      {'isActive': loc.isActive ? 0 : 1},
      where: 'id = ?',
      whereArgs: [loc.id],
    );
    await _loadLocations();
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                const Text(
                  'Lieux enregistrés',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                _locations.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: Text('Aucun lieu enregistré')),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _locations.length,
                        itemBuilder: (context, index) {
                          final loc = _locations[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: ListTile(
                              title: Text(loc.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('${loc.latitude.toStringAsFixed(6)}, ${loc.longitude.toStringAsFixed(6)}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Switch(
                                    value: loc.isActive,
                                    onChanged: (val) => _toggleActive(loc),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteLocation(loc.id!),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                const SizedBox(height: 30),
                const Text(
                  'Ajouter un nouveau lieu',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Nom du lieu'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _latController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Latitude'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _lonController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Longitude'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                OutlinedButton.icon(
                  onPressed: _getCurrentPosition,
                  icon: const Icon(Icons.my_location),
                  label: const Text('Utiliser ma position actuelle'),
                ),
                const SizedBox(height: 15),
                ElevatedButton.icon(
                  onPressed: _addLocation,
                  icon: const Icon(Icons.add_location),
                  label: const Text('Ajouter le lieu'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(14),
                  ),
                ),
              ],
            ),
    );
  }
}

extension on double {
  String toStringAsFormatted() => toStringAsFixed(6);
}
