import 'package:flutter/material.dart';
import 'data/database_helper.dart';
import 'data/models.dart';
import 'ui/locations_screen.dart';
import 'ui/statistics_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Badgeuse Auto (Android & iOS)'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Actions Rapides',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
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
                              return ListTile(
                                leading: Icon(
                                  item.type == 'ENTRÉE'
                                      ? Icons.arrow_downward
                                      : Icons.arrow_upward,
                                  color: item.type == 'ENTRÉE'
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                title: Text('${item.type} - ${item.locationName}'),
                                subtitle: Text(
                                    '${date.day}/${date.month}/${date.year} à ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'),
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
        title: const Text('Paramètres'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: [
                  Text(
                    'Rayon de détection (mètres): ${_enterDistance.toInt()}m',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
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
                  const SizedBox(height: 20),
                  Text(
                    'Délai d\'entrée (secondes): $_enterDelaySec s',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Slider(
                    value: _enterDelaySec.toDouble(),
                    min: 0,
                    max: 300,
                    divisions: 30,
                    label: '$_enterDelaySec s',
                    onChanged: (val) {
                      setState(() {
                        _enterDelaySec = val.toInt();
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Délai de sortie (secondes): $_exitDelaySec s',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Slider(
                    value: _exitDelaySec.toDouble(),
                    min: 0,
                    max: 300,
                    divisions: 30,
                    label: '$_exitDelaySec s',
                    onChanged: (val) {
                      setState(() {
                        _exitDelaySec = val.toInt();
                      });
                    },
                  ),
                  const SizedBox(height: 40),
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
            ),
    );
  }
}
