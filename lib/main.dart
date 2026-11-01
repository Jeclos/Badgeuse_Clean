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
    DateTime selectedDate = DateTime.fromMillisecondsSinceEpoch(presence.timestamp);
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(selectedDate);
    final locationController = TextEditingController(text: presence.locationName);
    String selectedType = presence.type;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Modifier la présence'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(value: 'ENTRÉE', child: Text('Entrée')),
                    DropdownMenuItem(value: 'SORTIE', child: Text('Sortie')),
                    DropdownMenuItem(value: 'MANUAL', child: Text('Manuel')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        selectedType = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(labelText: 'Lieu'),
                ),
                const SizedBox(height: 15),
                const Text('Date', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                ListTile(
                  title: Text('${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (pickedDate != null) {
                      setDialogState(() {
                        selectedDate = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          selectedDate.hour,
                          selectedDate.minute,
                        );
                      });
                    }
                  },
                ),
                const SizedBox(height: 10),
                const Text('Heure', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                ListTile(
                  title: Text('${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}'),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final pickedTime = await showTimePicker(
                      context: context,
                      initialTime: selectedTime,
                    );
                    if (pickedTime != null) {
                      setDialogState(() {
                        selectedTime = pickedTime;
                        selectedDate = DateTime(
                          selectedDate.year,
                          selectedDate.month,
                          selectedDate.day,
                          selectedTime.hour,
                          selectedTime.minute,
                        );
                      });
                    }
                  },
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
                final nav = Navigator.of(dialogContext);
                final db = await DatabaseHelper.instance.database;
                await db.update(
                  'presence',
                  {
                    'timestamp': selectedDate.millisecondsSinceEpoch,
                    'type': selectedType,
                    'locationName': locationController.text.trim(),
                  },
                  where: 'id = ?',
                  whereArgs: [presence.id],
                );
                if (!mounted) return;
                nav.pop();
                await _loadData();
              },
              child: const Text('Valider'),
            ),
          ],
        ),
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
  bool _isLoading = true;
  SettingsEntity _settings = SettingsEntity(enterDistance: 300, enterDelaySec: 60, exitDelaySec: 60);

  final _empNameController = TextEditingController();
  final _empAddressController = TextEditingController();
  final _employerNameController = TextEditingController();
  final _employerAddressController = TextEditingController();
  final _cityPdfController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await DatabaseHelper.instance.getSettings();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _empNameController.text = settings.employeeName;
      _empAddressController.text = settings.employeeAddress;
      _employerNameController.text = settings.employerName;
      _employerAddressController.text = settings.employerAddress;
      _cityPdfController.text = settings.cityPdf;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final updated = SettingsEntity(
      enterDistance: _settings.enterDistance,
      enterDelaySec: _settings.enterDelaySec,
      exitDelaySec: _settings.exitDelaySec,
      employeeName: _empNameController.text.trim(),
      employeeAddress: _empAddressController.text.trim(),
      employerName: _employerNameController.text.trim(),
      employerAddress: _employerAddressController.text.trim(),
      cityPdf: _cityPdfController.text.trim(),
      badgeMode: _settings.badgeMode,
      lunchBreakEnabled: _settings.lunchBreakEnabled,
      lunchStartHour: _settings.lunchStartHour,
      lunchStartMin: _settings.lunchStartMin,
      lunchEndHour: _settings.lunchEndHour,
      lunchEndMin: _settings.lunchEndMin,
      lunchDurationMin: _settings.lunchDurationMin,
    );

    await DatabaseHelper.instance.updateSettings(updated);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Configuration enregistrée avec succès')),
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
                ExpansionTile(
                  leading: const Icon(Icons.badge),
                  title: const Text('Identité'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          TextField(
                            controller: _empNameController,
                            decoration: const InputDecoration(labelText: 'Nom employé'),
                          ),
                          TextField(
                            controller: _empAddressController,
                            decoration: const InputDecoration(labelText: 'Adresse employé'),
                          ),
                          TextField(
                            controller: _employerNameController,
                            decoration: const InputDecoration(labelText: 'Nom employeur'),
                          ),
                          TextField(
                            controller: _employerAddressController,
                            decoration: const InputDecoration(labelText: 'Adresse employeur'),
                          ),
                          TextField(
                            controller: _cityPdfController,
                            decoration: const InputDecoration(labelText: 'Ville (PDF)'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                ExpansionTile(
                  leading: const Icon(Icons.tune),
                  title: const Text('Mode de badgeage'),
                  children: [
                    RadioListTile<String>(
                      title: const Text('Bureau / Multi-lieux'),
                      value: 'OFFICE',
                      groupValue: _settings.badgeMode,
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _settings = SettingsEntity(
                              enterDistance: _settings.enterDistance,
                              enterDelaySec: _settings.enterDelaySec,
                              exitDelaySec: _settings.exitDelaySec,
                              employeeName: _empNameController.text,
                              employeeAddress: _empAddressController.text,
                              employerName: _employerNameController.text,
                              employerAddress: _employerAddressController.text,
                              cityPdf: _cityPdfController.text,
                              badgeMode: val,
                              lunchBreakEnabled: _settings.lunchBreakEnabled,
                              lunchStartHour: _settings.lunchStartHour,
                              lunchStartMin: _settings.lunchStartMin,
                              lunchEndHour: _settings.lunchEndHour,
                              lunchEndMin: _settings.lunchEndMin,
                              lunchDurationMin: _settings.lunchDurationMin,
                            );
                          });
                        }
                      },
                    ),
                    RadioListTile<String>(
                      title: const Text('Dépôt / Entrepôt'),
                      value: 'DEPOT',
                      groupValue: _settings.badgeMode,
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _settings = SettingsEntity(
                              enterDistance: _settings.enterDistance,
                              enterDelaySec: _settings.enterDelaySec,
                              exitDelaySec: _settings.exitDelaySec,
                              employeeName: _empNameController.text,
                              employeeAddress: _empAddressController.text,
                              employerName: _employerNameController.text,
                              employerAddress: _employerAddressController.text,
                              cityPdf: _cityPdfController.text,
                              badgeMode: val,
                              lunchBreakEnabled: _settings.lunchBreakEnabled,
                              lunchStartHour: _settings.lunchStartHour,
                              lunchStartMin: _settings.lunchStartMin,
                              lunchEndHour: _settings.lunchEndHour,
                              lunchEndMin: _settings.lunchEndMin,
                              lunchDurationMin: _settings.lunchDurationMin,
                            );
                          });
                        }
                      },
                    ),
                    RadioListTile<String>(
                      title: const Text('Départ domicile'),
                      value: 'HOME_TRAVEL',
                      groupValue: _settings.badgeMode,
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _settings = SettingsEntity(
                              enterDistance: _settings.enterDistance,
                              enterDelaySec: _settings.enterDelaySec,
                              exitDelaySec: _settings.exitDelaySec,
                              employeeName: _empNameController.text,
                              employeeAddress: _empAddressController.text,
                              employerName: _employerNameController.text,
                              employerAddress: _employerAddressController.text,
                              cityPdf: _cityPdfController.text,
                              badgeMode: val,
                              lunchBreakEnabled: _settings.lunchBreakEnabled,
                              lunchStartHour: _settings.lunchStartHour,
                              lunchStartMin: _settings.lunchStartMin,
                              lunchEndHour: _settings.lunchEndHour,
                              lunchEndMin: _settings.lunchEndMin,
                              lunchDurationMin: _settings.lunchDurationMin,
                            );
                          });
                        }
                      },
                    ),
                    RadioListTile<String>(
                      title: const Text('Manuel uniquement'),
                      value: 'MANUAL',
                      groupValue: _settings.badgeMode,
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _settings = SettingsEntity(
                              enterDistance: _settings.enterDistance,
                              enterDelaySec: _settings.enterDelaySec,
                              exitDelaySec: _settings.exitDelaySec,
                              employeeName: _empNameController.text,
                              employeeAddress: _empAddressController.text,
                              employerName: _employerNameController.text,
                              employerAddress: _employerAddressController.text,
                              cityPdf: _cityPdfController.text,
                              badgeMode: val,
                              lunchBreakEnabled: _settings.lunchBreakEnabled,
                              lunchStartHour: _settings.lunchStartHour,
                              lunchStartMin: _settings.lunchStartMin,
                              lunchEndHour: _settings.lunchEndHour,
                              lunchEndMin: _settings.lunchEndMin,
                              lunchDurationMin: _settings.lunchDurationMin,
                            );
                          });
                        }
                      },
                    ),
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
                          Text('Rayon de détection: ${_settings.enterDistance.toInt()}m'),
                          Slider(
                            value: _settings.enterDistance,
                            min: 50,
                            max: 2000,
                            divisions: 39,
                            label: '${_settings.enterDistance.toInt()}m',
                            onChanged: (val) {
                              setState(() {
                                _settings = SettingsEntity(
                                  enterDistance: val,
                                  enterDelaySec: _settings.enterDelaySec,
                                  exitDelaySec: _settings.exitDelaySec,
                                  employeeName: _empNameController.text,
                                  employeeAddress: _empAddressController.text,
                                  employerName: _employerNameController.text,
                                  employerAddress: _employerAddressController.text,
                                  cityPdf: _cityPdfController.text,
                                  badgeMode: _settings.badgeMode,
                                  lunchBreakEnabled: _settings.lunchBreakEnabled,
                                  lunchStartHour: _settings.lunchStartHour,
                                  lunchStartMin: _settings.lunchStartMin,
                                  lunchEndHour: _settings.lunchEndHour,
                                  lunchEndMin: _settings.lunchEndMin,
                                  lunchDurationMin: _settings.lunchDurationMin,
                                );
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
                          Text('Délai d\'entrée: ${_settings.enterDelaySec} s'),
                          Slider(
                            value: _settings.enterDelaySec.toDouble(),
                            min: 0,
                            max: 300,
                            divisions: 30,
                            onChanged: (val) {
                              setState(() {
                                _settings = SettingsEntity(
                                  enterDistance: _settings.enterDistance,
                                  enterDelaySec: val.toInt(),
                                  exitDelaySec: _settings.exitDelaySec,
                                  employeeName: _empNameController.text,
                                  employeeAddress: _empAddressController.text,
                                  employerName: _employerNameController.text,
                                  employerAddress: _employerAddressController.text,
                                  cityPdf: _cityPdfController.text,
                                  badgeMode: _settings.badgeMode,
                                  lunchBreakEnabled: _settings.lunchBreakEnabled,
                                  lunchStartHour: _settings.lunchStartHour,
                                  lunchStartMin: _settings.lunchStartMin,
                                  lunchEndHour: _settings.lunchEndHour,
                                  lunchEndMin: _settings.lunchEndMin,
                                  lunchDurationMin: _settings.lunchDurationMin,
                                );
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                          Text('Délai de sortie: ${_settings.exitDelaySec} s'),
                          Slider(
                            value: _settings.exitDelaySec.toDouble(),
                            min: 0,
                            max: 300,
                            divisions: 30,
                            onChanged: (val) {
                              setState(() {
                                _settings = SettingsEntity(
                                  enterDistance: _settings.enterDistance,
                                  enterDelaySec: _settings.enterDelaySec,
                                  exitDelaySec: val.toInt(),
                                  employeeName: _empNameController.text,
                                  employeeAddress: _empAddressController.text,
                                  employerName: _employerNameController.text,
                                  employerAddress: _employerAddressController.text,
                                  cityPdf: _cityPdfController.text,
                                  badgeMode: _settings.badgeMode,
                                  lunchBreakEnabled: _settings.lunchBreakEnabled,
                                  lunchStartHour: _settings.lunchStartHour,
                                  lunchStartMin: _settings.lunchStartMin,
                                  lunchEndHour: _settings.lunchEndHour,
                                  lunchEndMin: _settings.lunchEndMin,
                                  lunchDurationMin: _settings.lunchDurationMin,
                                );
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                ExpansionTile(
                  leading: const Icon(Icons.restaurant),
                  title: const Text('Pause déjeuner'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: const Text('Activer la pause'),
                            value: _settings.lunchBreakEnabled,
                            onChanged: (val) {
                              setState(() {
                                _settings = SettingsEntity(
                                  enterDistance: _settings.enterDistance,
                                  enterDelaySec: _settings.enterDelaySec,
                                  exitDelaySec: _settings.exitDelaySec,
                                  employeeName: _empNameController.text,
                                  employeeAddress: _empAddressController.text,
                                  employerName: _employerNameController.text,
                                  employerAddress: _employerAddressController.text,
                                  cityPdf: _cityPdfController.text,
                                  badgeMode: _settings.badgeMode,
                                  lunchBreakEnabled: val,
                                  lunchStartHour: _settings.lunchStartHour,
                                  lunchStartMin: _settings.lunchStartMin,
                                  lunchEndHour: _settings.lunchEndHour,
                                  lunchEndMin: _settings.lunchEndMin,
                                  lunchDurationMin: _settings.lunchDurationMin,
                                );
                              });
                            },
                          ),
                        ],
                      ),
                    ),
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
