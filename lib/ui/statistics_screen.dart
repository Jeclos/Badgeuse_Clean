import 'package:flutter/material.dart';
import '../data/database_helper.dart';
import '../data/models.dart';
import '../export/pdf_export.dart';
import '../export/csv_export.dart';
import '../domain/calculators.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  List<PresenceEntity> _presences = [];
  List<WorkLocationEntity> _locations = [];
  bool _isLoading = true;

  String _selectedPeriod = 'Cette semaine';
  String _selectedLocation = 'Tous les lieux';
  DateTime? _startDate;
  DateTime? _endDate;

  final List<String> _periods = [
    'Cette semaine',
    'Semaine précédente',
    'Ce mois',
    'Mois précédent',
    'Personnalisé'
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final presences = await DatabaseHelper.instance.getAllPresences();
    final locations = await DatabaseHelper.instance.getAllWorkLocations();
    if (!mounted) return;
    setState(() {
      _presences = presences;
      _locations = locations;
      _isLoading = false;
    });
  }

  List<PresenceEntity> get _filteredPresences {
    return _presences.where((p) {
      if (_selectedLocation != 'Tous les lieux' && p.locationName != _selectedLocation) {
        return false;
      }
      final date = DateTime.fromMillisecondsSinceEpoch(p.timestamp);
      final now = DateTime.now();

      if (_selectedPeriod == 'Cette semaine') {
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        return date.isAfter(DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day));
      } else if (_selectedPeriod == 'Semaine précédente') {
        final startOfLastWeek = now.subtract(Duration(days: now.weekday + 6));
        final endOfLastWeek = now.subtract(Duration(days: now.weekday));
        return date.isAfter(startOfLastWeek) && date.isBefore(endOfLastWeek);
      } else if (_selectedPeriod == 'Ce mois') {
        return date.year == now.year && date.month == now.month;
      } else if (_selectedPeriod == 'Mois précédent') {
        final prevMonth = DateTime(now.year, now.month - 1, 1);
        return date.year == prevMonth.year && date.month == prevMonth.month;
      } else if (_selectedPeriod == 'Personnalisé') {
        if (_startDate != null && date.isBefore(DateTime(_startDate!.year, _startDate!.month, _startDate!.day))) {
          return false;
        }
        if (_endDate != null && date.isAfter(DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59))) {
          return false;
        }
        return true;
      }
      return true;
    }).toList();
  }

  Future<void> _exportCsv() async {
    final settings = await DatabaseHelper.instance.getSettings();
    await CsvExport.exportAndShareCsv(_filteredPresences, settings: settings);
  }

  Future<void> _exportPdf() async {
    final settings = await DatabaseHelper.instance.getSettings();
    await PdfExport.showPdfPreview(context, _filteredPresences, settings: settings);
  }

  Future<void> _deletePresence(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('presence', where: 'id = ?', whereArgs: [id]);
    await _loadData();
  }

  void _showEditPresenceDialog(PresenceEntity presence) {
    DateTime selectedDate = DateTime.fromMillisecondsSinceEpoch(presence.timestamp);
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(selectedDate);
    String selectedLocation = presence.locationName;
    if (_locations.isNotEmpty && !_locations.any((l) => l.name == selectedLocation)) {
      selectedLocation = _locations.first.name;
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
                  initialValue: _locations.any((l) => l.name == selectedLocation) ? selectedLocation : (_locations.isNotEmpty ? _locations.first.name : null),
                  decoration: const InputDecoration(labelText: 'Lieu'),
                  items: _locations.map((loc) => DropdownMenuItem(
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

  void _showDayDetailsDialog(String dayKey, List<PresenceEntity> dayPresences) {
    dayPresences.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final dateParts = dayKey.split('-');
    final titleDate = '${dateParts[2]}/${dateParts[1]}/${dateParts[0]}';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pointages du $titleDate'),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.85,
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
                title: Text(
                  '${item.type} (${item.locationName})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
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

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredPresences;
    final totalWorkedMillis = WorkTimeCalculator.calculateWorkedTime(filtered);
    final workedTimeStr = WorkTimeCalculator.formatDuration(totalWorkedMillis);

    const overtimeMillis = 0;
    final overtimeStr = WorkTimeCalculator.formatDuration(overtimeMillis);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiques'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Temps total', style: TextStyle(color: Colors.grey, fontSize: 13)),
                                const SizedBox(height: 5),
                                Text(workedTimeStr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Heures sup.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                                const SizedBox(height: 5),
                                Text(overtimeStr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Période', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                          DropdownButtonFormField<String>(
                            value: _selectedPeriod,
                            decoration: const InputDecoration(border: UnderlineInputBorder()),
                            items: _periods.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedPeriod = val;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 15),
                          const Text('Emplacement', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                          DropdownButtonFormField<String>(
                            value: _selectedLocation,
                            decoration: const InputDecoration(border: UnderlineInputBorder()),
                            items: [
                              const DropdownMenuItem(value: 'Tous les lieux', child: Text('Tous les lieux')),
                              ..._locations.map((l) => DropdownMenuItem(value: l.name, child: Text(l.name))),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedLocation = val;
                                });
                              }
                            },
                          ),
                          if (_selectedPeriod == 'Personnalisé') ...[
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: _startDate ?? DateTime.now(),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2035),
                                      );
                                      if (picked != null) setState(() => _startDate = picked);
                                    },
                                    child: Text(_startDate == null ? 'Date de début' : '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: _endDate ?? DateTime.now(),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2035),
                                      );
                                      if (picked != null) setState(() => _endDate = picked);
                                    },
                                    child: Text(_endDate == null ? 'Date de fin' : '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Détail par jour', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  filtered.isEmpty
                      ? const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('Aucun pointage pour cette période')))
                      : () {
                          final Map<String, List<PresenceEntity>> daysMap = {};
                          for (var p in filtered) {
                            final date = DateTime.fromMillisecondsSinceEpoch(p.timestamp);
                            final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                            daysMap.putIfAbsent(key, () => []).add(p);
                          }
                          final sortedDays = daysMap.keys.toList()..sort((a, b) => b.compareTo(a));

                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
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
                  const SizedBox(height: 20),
                  Spacer(),
                  ElevatedButton.icon(
                    onPressed: filtered.isEmpty ? null : _exportCsv,
                    icon: const Icon(Icons.download),
                    label: const Text('Exporter en CSV'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade200, foregroundColor: Colors.black54),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: filtered.isEmpty ? null : _exportPdf,
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Exporter / Partager PDF'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade100, foregroundColor: Colors.blue.shade900),
                  ),
                ],
              ),
            ),
    );
  }
}
