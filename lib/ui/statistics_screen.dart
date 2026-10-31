import 'package:flutter/material.dart';
import '../data/database_helper.dart';
import '../data/models.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  List<PresenceEntity> _presences = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPresences();
  }

  Future<void> _loadPresences() async {
    final presences = await DatabaseHelper.instance.getAllPresences();
    setState(() {
      _presences = presences;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiques & Rapports'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text(
                            'Total des pointages enregistrés',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${_presences.length}',
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Résumé des activités',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _presences.isEmpty
                        ? const Center(child: Text('Aucune donnée statistique disponible'))
                        : ListView.builder(
                            itemCount: _presences.length,
                            itemBuilder: (context, index) {
                              final item = _presences[index];
                              final date = DateTime.fromMillisecondsSinceEpoch(item.timestamp);
                              return ListTile(
                                leading: Icon(
                                  item.type == 'ENTRÉE' ? Icons.login : Icons.logout,
                                  color: item.type == 'ENTRÉE' ? Colors.green : Colors.red,
                                ),
                                title: Text('${item.type} - ${item.locationName}'),
                                subtitle: Text('${date.day}/${date.month}/${date.year} à ${date.hour}:${date.minute.toString().padLeft(2, '0')}'),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
