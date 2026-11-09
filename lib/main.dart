import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'data/database_helper.dart';
import 'data/models.dart';
import 'ui/locations_screen.dart';
import 'ui/statistics_screen.dart';
import 'domain/calculators.dart';
import 'services/background_geofence_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BackgroundGeofenceService.initializeService();
  runApp(const BadgeuseApp());
}

class BadgeuseApp extends StatelessWidget {
  const BadgeuseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Badgeuse Auto',
      debugShowCheckedModeBanner: false,
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

  @override
  Widget build(BuildContext context) {
    final screens = [
      const MainScreen(),
      const LocationsScreen(),
      const StatisticsScreen(),
      const SettingsScreen(),
    ];
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
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
  List<WorkLocationEntity> _workLocations = [];
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final presences = await DatabaseHelper.instance.getAllPresences();
    final locations = await DatabaseHelper.instance.getAllWorkLocations();
    if (!mounted) return;
    setState(() {
      _presences = presences;
      _workLocations = locations;
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

  Future<void> _handleEntryPressed() async {
    final locations = await DatabaseHelper.instance.getAllWorkLocations();
    final activeLocations = locations.where((l) => l.isActive).toList();
    if (!mounted) return;
    if (activeLocations.isEmpty) {
      await _badgeManual('ENTRÉE', 'Bureau Principal');
    } else if (activeLocations.length == 1) {
      await _badgeManual('ENTRÉE', activeLocations.first.name);
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Choisir le lieu d\'entrée'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: activeLocations.map((loc) => ListTile(
              title: Text(loc.name),
              onTap: () {
                Navigator.pop(context);
                _badgeManual('ENTRÉE', loc.name);
              },
            )).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _handleExitPressed() async {
    final locations = await DatabaseHelper.instance.getAllWorkLocations();
    final activeLocations = locations.where((l) => l.isActive).toList();
    String locationName = 'Bureau Principal';
    if (_presences.isNotEmpty) {
      locationName = _presences.first.locationName;
    } else if (activeLocations.isNotEmpty) {
      locationName = activeLocations.first.name;
    }
    await _badgeManual('SORTIE', locationName);
  }

  Future<void> _deletePresence(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('presence', where: 'id = ?', whereArgs: [id]);
    await _loadData();
  }

  void _showDayDetailsDialog(String dayKey, List<PresenceEntity> dayPresences) {
    dayPresences.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final dateParts = dayKey.split('-');
    final titleDate = '${dateParts[2]}/${dateParts[1]}/${dateParts[0]}';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pointages du $titleDate'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: dayPresences.length,
            itemBuilder: (context, index) {
              final item = dayPresences[index];
              final date = DateTime.fromMillisecondsSinceEpoch(item.timestamp);
              return ListTile(
                leading: Icon(
                  item.type == 'ENTRÉE' ? Icons.arrow_downward : Icons.arrow_upward,
                  color: item.type == 'ENTRÉE' ? Colors.green : Colors.red,
                ),
                title: Text('${item.type} (${item.locationName})', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () {
                        Navigator.pop(context);
                        _showEditPresenceDialog(item);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                      onPressed: () async {
                        Navigator.pop(context);
                        await _deletePresence(item.id!);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
  void _showEditPresenceDialog(PresenceEntity presence) {
    DateTime selectedDate = DateTime.fromMillisecondsSinceEpoch(presence.timestamp);
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(selectedDate);
    String selectedLocation = presence.locationName;
    if (_workLocations.isNotEmpty && !_workLocations.any((l) => l.name == selectedLocation)) {
      selectedLocation = _workLocations.first.name;
    }
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
                DropdownButtonFormField<String>(
                  initialValue: _workLocations.any((l) => l.name == selectedLocation) ? selectedLocation : (_workLocations.isNotEmpty ? _workLocations.first.name : null),
                  decoration: const InputDecoration(labelText: 'Lieu'),
                  items: _workLocations.map((loc) => DropdownMenuItem(
                    value: loc.name,
                    child: Text(loc.name),
                  )).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        selectedLocation = val;
                      });
                    }
                  },
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
                    'locationName': selectedLocation,
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
    final now = DateTime.now();
    final todayPresences = _presences.where((p) {
      final date = DateTime.fromMillisecondsSinceEpoch(p.timestamp);
      return date.year == now.year && date.month == now.month && date.day == now.day;
    }).toList();

    final todayWorkedMillis = WorkTimeCalculator.calculateWorkedTime(todayPresences);
    final workedTimeStr = WorkTimeCalculator.formatDuration(todayWorkedMillis);
    final isWorking = _presences.isNotEmpty && _presences.first.type == 'ENTRÉE';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Badgeuse Auto'),
        actions: [
          FutureBuilder<bool>(
            future: Geolocator.isLocationServiceEnabled(),
            builder: (context, snapshot) {
              final isGpsOn = snapshot.data ?? false;
              return IconButton(
                icon: Icon(
                  isGpsOn ? Icons.gps_fixed : Icons.gps_off,
                  color: isGpsOn ? Colors.green : Colors.red,
                ),
                tooltip: isGpsOn ? 'Signal GPS OK' : 'GPS Inactif',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isGpsOn ? 'Signal GPS : OK (Actif)' : 'Signal GPS : Inactif / Désactivé'),
                    ),
                  );
                },
              );
            },
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
                                onPressed: _handleEntryPressed,
                                icon: const Icon(Icons.login),
                                label: const Text('Entrée'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade100,
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: _handleExitPressed,
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
                    child: () {
                      final Map<String, List<PresenceEntity>> daysMap = {};
                      for (var p in _presences) {
                        final date = DateTime.fromMillisecondsSinceEpoch(p.timestamp);
                        final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                        daysMap.putIfAbsent(key, () => []).add(p);
                      }
                      final sortedDays = daysMap.keys.toList()..sort((a, b) => b.compareTo(a));

                      if (sortedDays.isEmpty) {
                        return const Center(child: Text('Aucun pointage pour le moment'));
                      }

                      return ListView.builder(
                        itemCount: sortedDays.length,
                        itemBuilder: (context, index) {
                          final dayKey = sortedDays[index];
                          final dayPresences = daysMap[dayKey]!;
                          dayPresences.sort((a, b) => a.timestamp.compareTo(b.timestamp));

                          final dateParts = dayKey.split('-');
                          final dateStr = '${dateParts[2]}/${dateParts[1]}/${dateParts[0]}';
                          
                          final workedMillis = WorkTimeCalculator.calculateWorkedTime(dayPresences);
                          final durationStr = WorkTimeCalculator.formatDuration(workedMillis);

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: ListTile(
                              leading: const Icon(Icons.calendar_today, color: Colors.blue),
                              title: Text('Journée du $dateStr', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('Temps travaillé : $durationStr (${dayPresences.length} pointage${dayPresences.length > 1 ? 's' : ''})'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _showDayDetailsDialog(dayKey, dayPresences),
                            ),
                          );
                        },
                      );
                    }(),
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

  void _showModeInfo(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
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
                    ListTile(
                      title: const Text('Bureau / Multi-lieux'),
                      leading: Radio<String>(
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
                      trailing: IconButton(
                        icon: const Icon(Icons.info_outline, color: Colors.blue),
                        onPressed: () => _showModeInfo(
                          'Mode OFFICE',
                          'Mode multi-lieux classique.\n\nChaque lieu est géré indépendamment.\n\nFonctionnement :\n• Entrée automatique à l\'arrivée sur un lieu\n• Sortie automatique au départ du lieu\n• Plusieurs lieux possibles dans la même journée\n• Les temps sont calculés séparément pour chaque lieu',
                        ),
                      ),
                    ),
                    ListTile(
                      title: const Text('Dépôt / Entrepôt'),
                      leading: Radio<String>(
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
                      trailing: IconButton(
                        icon: const Icon(Icons.info_outline, color: Colors.blue),
                        onPressed: () => _showModeInfo(
                          'Mode DEPOT',
                          'Mode dépôt / chantier (journée unique).\n\nFonctionnement :\n• Une seule journée de travail\n• L\'entrée correspond à la PREMIÈRE arrivée au dépôt\n• Les sorties avant l\'heure minimale sont ignorées\n• L\'heure de fin est une HEURE MINIMALE\n• La PREMIÈRE sortie APRÈS cette heure clôture la journée',
                        ),
                      ),
                    ),
                    ListTile(
                      title: const Text('Départ domicile'),
                      leading: Radio<String>(
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
                      trailing: IconButton(
                        icon: const Icon(Icons.info_outline, color: Colors.blue),
                        onPressed: () => _showModeInfo(
                          'Mode HOME_TRAVEL',
                          'Mode départ domicile.\n\nLa journée est calculée entre le domicile et le travail.\n\nFonctionnement :\n• Le départ du domicile démarre la journée\n• Le retour au domicile termine la journée\n• Le temps de trajet est automatiquement pris en compte',
                        ),
                      ),
                    ),
                    ListTile(
                      title: const Text('Manuel uniquement'),
                      leading: Radio<String>(
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
                      trailing: IconButton(
                        icon: const Icon(Icons.info_outline, color: Colors.blue),
                        onPressed: () => _showModeInfo(
                          'Mode MANUAL_ONLY',
                          'Mode manuel uniquement.\n\nAucune automatisation.\n\nFonctionnement :\n• Aucun badge automatique\n• Pas de détection GPS\n• Toutes les entrées et sorties sont manuelles',
                        ),
                      ),
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
                const ExpansionTile(
                  leading: Icon(Icons.work),
                  title: Text('Lieux de travail'),
                  children: [
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: SizedBox(
                        height: 400,
                        child: LocationsScreen(),
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
                          if (_settings.lunchBreakEnabled) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: TextEditingController(text: _settings.lunchStartHour.toString()),
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Début heure'),
                                    onChanged: (val) {
                                      final h = int.tryParse(val) ?? _settings.lunchStartHour;
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
                                        lunchBreakEnabled: _settings.lunchBreakEnabled,
                                        lunchStartHour: h,
                                        lunchStartMin: _settings.lunchStartMin,
                                        lunchEndHour: _settings.lunchEndHour,
                                        lunchEndMin: _settings.lunchEndMin,
                                        lunchDurationMin: _settings.lunchDurationMin,
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: TextEditingController(text: _settings.lunchStartMin.toString()),
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Début minute'),
                                    onChanged: (val) {
                                      final m = int.tryParse(val) ?? _settings.lunchStartMin;
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
                                        lunchBreakEnabled: _settings.lunchBreakEnabled,
                                        lunchStartHour: _settings.lunchStartHour,
                                        lunchStartMin: m,
                                        lunchEndHour: _settings.lunchEndHour,
                                        lunchEndMin: _settings.lunchEndMin,
                                        lunchDurationMin: _settings.lunchDurationMin,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: TextEditingController(text: _settings.lunchEndHour.toString()),
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Fin heure'),
                                    onChanged: (val) {
                                      final h = int.tryParse(val) ?? _settings.lunchEndHour;
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
                                        lunchBreakEnabled: _settings.lunchBreakEnabled,
                                        lunchStartHour: _settings.lunchStartHour,
                                        lunchStartMin: _settings.lunchStartMin,
                                        lunchEndHour: h,
                                        lunchEndMin: _settings.lunchEndMin,
                                        lunchDurationMin: _settings.lunchDurationMin,
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: TextEditingController(text: _settings.lunchEndMin.toString()),
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Fin minute'),
                                    onChanged: (val) {
                                      final m = int.tryParse(val) ?? _settings.lunchEndMin;
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
                                        lunchBreakEnabled: _settings.lunchBreakEnabled,
                                        lunchStartHour: _settings.lunchStartHour,
                                        lunchStartMin: _settings.lunchStartMin,
                                        lunchEndHour: _settings.lunchEndHour,
                                        lunchEndMin: m,
                                        lunchDurationMin: _settings.lunchDurationMin,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: TextEditingController(text: _settings.lunchDurationMin.toString()),
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Durée par défaut (minutes)'),
                              onChanged: (val) {
                                final d = int.tryParse(val) ?? _settings.lunchDurationMin;
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
                                  lunchBreakEnabled: _settings.lunchBreakEnabled,
                                  lunchStartHour: _settings.lunchStartHour,
                                  lunchStartMin: _settings.lunchStartMin,
                                  lunchEndHour: _settings.lunchEndHour,
                                  lunchEndMin: _settings.lunchEndMin,
                                  lunchDurationMin: d,
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const ExpansionTile(
                  leading: Icon(Icons.palette),
                  title: Text('Apparence'),
                  children: [
                    ListTile(title: Text('Thème sombre / clair')),
                  ],
                ),
                const SizedBox(height: 30),
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
