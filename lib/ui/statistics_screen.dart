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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPresences();
  }

  Future<void> _loadPresences() async {
    final presences = await DatabaseHelper.instance.getAllPresences();
    if (!mounted) return;
    setState(() {
      _presences = presences;
      _isLoading = false;
    });
  }

  void _exportCsv() {
    final csv = CsvExport.generateCsv(_presences);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export CSV'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Text(csv),
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
    final totalWorkedMillis = WorkTimeCalculator.calculateWorkedTime(_presences);
    final workedTimeStr = WorkTimeCalculator.formatDuration(totalWorkedMillis);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiques & Rapports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Exporter en PDF',
            onPressed: _presences.isEmpty
                ? null
                : () => PdfExport.generateAndPrintPdf(_presences),
          ),
          IconButton(
            icon: const Icon(Icons.table_chart),
            tooltip: 'Exporter en CSV',
            onPressed: _presences.isEmpty ? null : _exportCsv,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Card(
                          elevation: 3,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                const Text(
                                  'Pointages',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '${_presences.length}',
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Card(
                          elevation: 3,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                const Text(
                                  'Temps Total',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  workedTimeStr,
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _presences.isEmpty
                              ? null
                              : () => PdfExport.generateAndPrintPdf(_presences),
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('Rapport PDF'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _presences.isEmpty ? null : _exportCsv,
                          icon: const Icon(Icons.table_chart),
                          label: const Text('Export CSV'),
                        ),
                      ),
                    ],
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
