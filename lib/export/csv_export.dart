import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import '../data/models.dart';

class CsvExport {
  static String generateCsv(List<PresenceEntity> presences) {
    List<List<dynamic>> rows = [];
    // Header
    rows.add(['ID', 'Timestamp', 'Date', 'Type', 'Lieu']);

    for (var p in presences) {
      final date = DateTime.fromMillisecondsSinceEpoch(p.timestamp);
      final dateStr = '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      rows.add([p.id, p.timestamp, dateStr, p.type, p.locationName]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  static void exportCsv(List<PresenceEntity> presences) {
    final csvData = generateCsv(presences);
    if (kDebugMode) {
      print(csvData);
    }
  }
}
