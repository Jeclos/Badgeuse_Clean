import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../data/models.dart';

class CsvExport {
  static Future<void> exportAndShareCsv(List<PresenceEntity> presences, {SettingsEntity? settings}) async {
    final directory = await getTemporaryDirectory();
    final now = DateTime.now();
    final file = File('${directory.path}/releve_heures_${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.csv');

    final buffer = StringBuffer();
    buffer.writeln('date,work_location,type,timestamp');

    for (var p in presences) {
      final date = DateTime.fromMillisecondsSinceEpoch(p.timestamp);
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      buffer.writeln('$dateStr,"${p.locationName}","${p.type}",${p.timestamp}');
    }

    await file.writeAsString(buffer.toString());

    await Share.shareXFiles([XFile(file.path)], text: 'Export CSV - Badgeuse Auto');
  }
}
