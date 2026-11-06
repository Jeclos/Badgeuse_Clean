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
                            initialValue: _selectedPeriod,
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
                            initialValue: _selectedLocation,
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
                  const Text('Détail des pointages', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  filtered.isEmpty
                      ? const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('Aucun pointage pour cette période')))
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            final date = DateTime.fromMillisecondsSinceEpoch(item.timestamp);
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                leading: Icon(
                                  item.type == 'ENTRÉE' ? Icons.arrow_downward : Icons.arrow_upward,
                                  color: item.type == 'ENTRÉE' ? Colors.green : Colors.red,
                                ),
                                title: Text('${item.type} (${item.locationName})', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('${date.day}/${date.month}/${date.year} à ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'),
                              ),
                            );
                          },
                        ),
                  const SizedBox(height: 20),
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
