import 'package:flutter/material.dart';
import 'data/database_helper.dart';
import 'data/models.dart';
import 'ui/locations_screen.dart';
import 'ui/statistics_screen.dart';
import 'domain/calculators.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BadgeuseApp());
}

class BadgeuseApp extends StatelessWidget {
  const BadgeuseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Badgeuse Auto',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const MainScreen(),
    const LocationsScreen(),
    const StatisticsScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.location_on),
            label: 'Lieux',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart),
            label: 'Stats',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Réglages',
          ),
        ],
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  List<PresenceEntity> _presences = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final presences = await DatabaseHelper.instance.getAllPresences();
    if (!mounted) return;
    setState(() {
      _presences = presences;
      _isLoading = false;
    });
  }

  Future<void> _badgeManual(String type, String locationName) async {
    await DatabaseHelper.instance.insertPresence(
      PresenceEntity(
        timestamp: DateTime.now().millisecondsSinceEpoch,
        type: type,
        locationName: locationName,
      ),
    );
    await _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Pointage réussi : $type ($locationName)')),
    );
  }

  Future<void> _deletePresence(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('presence', where: 'id = ?', whereArgs: [id]);
    await _loadData();
  }

  void _showEditPresenceDialog(PresenceEntity presence) {
    final typeController = TextEditingController(text: presence.type);
    final locationController = TextEditingController(text: presence.locationName);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Modifier le pointage'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: typeController,
              decoration: const InputDecoration(labelText: 'Type (ENTRÉE / SORTIE)'),
            ),
            TextField(
              controller: locationController,
              decoration: const InputDecoration(labelText: 'Lieu'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final nav = Navigator.of(dialogContext);
              final db = await DatabaseHelper.instance.database;
              await db.update(
                'presence',
                {
                  'type': typeController.text.trim(),
                  'locationName': locationController.text.trim(),
                },
                where: 'id = ?',
                whereArgs: [presence.id],
              );
              if (!mounted) return;
              nav.pop();
              await _loadData();
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalWorkedMillis = WorkTimeCalculator.calculateWorkedTime(_presences);
    final workedTimeStr = WorkTimeCalculator.formatDuration(totalWorkedMillis);
    final isWorking = _presences.isNotEmpty && _presences.first.type == 'ENTRÉE';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Badgeuse Auto'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 3,
                    color: isWorking ? Colors.green.shade50 : Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Chip(
                              backgroundColor: isWorking ? Colors.green : Colors.red.shade800,
                              label: Text(
                                isWorking ? 'EN SERVICE' : 'HORS TRAVAIL',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Temps aujourd’hui : $workedTimeStr',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Lieu : ${isWorking ? _presences.first.locationName : "Hors travail"}',
                            style: const TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          const SizedBox(height: 15),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => _badgeManual('ENTRÉE', 'Bureau Principal'),
                                icon: const Icon(Icons.login),
                                label: const Text('Entrée'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade100,
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () => _badgeManual('SORTIE', 'Bureau Principal'),
                                icon: const Icon(Icons.logout),
                                label: const Text('Sortie'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade100,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Historique des pointages',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _presences.isEmpty
                        ? const Center(
                            child: Text('Aucun pointage pour le moment'),
                          )
                        : ListView.builder(
                            itemCount: _presences.length,
                            itemBuilder: (context, index) {
                              final item = _presences[index];
                              final date = DateTime.fromMillisecondsSinceEpoch(
                                  item.timestamp);
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: ListTile(
                                  leading: Icon(
                                    item.type == 'ENTRÉE'
                                        ? Icons.arrow_downward
                                        : Icons.arrow_upward,
                                    color: item.type == 'ENTRÉE'
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                  title: Text('${item.type} (${item.locationName})',
                                      style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text(
                                      '${date.day}/${date.month}/${date.year} à ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 20),
                                        onPressed: () => _showEditPresenceDialog(item),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                        onPressed: () => _deletePresence(item.id!),
                                      ),
                                    ],
                                  ),
                                ),
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

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _enterDistance = 300.0;
  int _enterDelaySec = 60;
  int _exitDelaySec = 60;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await DatabaseHelper.instance.getSettings();
    if (!mounted) return;
    setState(() {
      _enterDistance = settings.enterDistance;
      _enterDelaySec = settings.enterDelaySec;
      _exitDelaySec = settings.exitDelaySec;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    await DatabaseHelper.instance.updateSettings(
      SettingsEntity(
        enterDistance: _enterDistance,
        enterDelaySec: _enterDelaySec,
        exitDelaySec: _exitDelaySec,
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Paramètres enregistrés avec succès')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuration'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                const ExpansionTile(
                  leading: Icon(Icons.badge),
                  title: Text('Identité'),
                  children: [
                    ListTile(title: Text('Nom d\'utilisateur / Appareil')),
                  ],
                ),
                const ExpansionTile(
                  leading: Icon(Icons.tune),
                  title: Text('Mode de badgeage'),
                  children: [
                    ListTile(title: Text('Mode automatique / Manuel')),
                  ],
                ),
                ExpansionTile(
                  leading: const Icon(Icons.location_on),
                  title: const Text('Détection'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Rayon de détection: ${_enterDistance.toInt()}m'),
                          Slider(
                            value: _enterDistance,
                            min: 50,
                            max: 2000,
                            divisions: 39,
                            label: '${_enterDistance.toInt()}m',
                            onChanged: (val) {
                              setState(() {
                                _enterDistance = val;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                ExpansionTile(
                  leading: const Icon(Icons.timer),
                  title: const Text('Temporisation'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Délai d\'entrée: $_enterDelaySec s'),
                          Slider(
                            value: _enterDelaySec.toDouble(),
                            min: 0,
                            max: 300,
                            divisions: 30,
                            onChanged: (val) {
                              setState(() {
                                _enterDelaySec = val.toInt();
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                          Text('Délai de sortie: $_exitDelaySec s'),
                          Slider(
                            value: _exitDelaySec.toDouble(),
                            min: 0,
                            max: 300,
                            divisions: 30,
                            onChanged: (val) {
                              setState(() {
                                _exitDelaySec = val.toInt();
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const ExpansionTile(
                  leading: Icon(Icons.restaurant),
                  title: Text('Pause déjeuner'),
                  children: [
                    ListTile(title: Text('Gestion automatique de la pause')),
                  ],
                ),
                const ExpansionTile(
                  leading: Icon(Icons.work),
                  title: Text('Lieux de travail'),
                  children: [
                    ListTile(title: Text('Gérer les lieux de travail')),
                  ],
                ),
                const ExpansionTile(
                  leading: Icon(Icons.palette),
                  title: Text('Apparence'),
                  children: [
                    ListTile(title: Text('Thème sombre / clair')),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _saveSettings,
                  icon: const Icon(Icons.save),
                  label: const Text('Enregistrer les modifications'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ],
            ),
    );
  }
}
