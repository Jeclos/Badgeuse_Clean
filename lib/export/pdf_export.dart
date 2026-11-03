import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../data/models.dart';
import '../domain/calculators.dart';

class PdfExport {
  static Future<void> generateAndPrintPdf(List<PresenceEntity> presences, {SettingsEntity? settings}) async {
    final pdf = pw.Document();

    final now = DateTime.now();
    final employeeName = settings?.employeeName.isNotEmpty == true ? settings!.employeeName : 'Employé';
    final employeeAddress = settings?.employeeAddress ?? '';
    final employerName = settings?.employerName.isNotEmpty == true ? settings!.employerName : 'Employeur';
    final employerAddress = settings?.employerAddress ?? '';

    // Group presences by day
    final Map<String, List<PresenceEntity>> daysMap = {};
    for (var p in presences) {
      final date = DateTime.fromMillisecondsSinceEpoch(p.timestamp);
      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      daysMap.putIfAbsent(key, () => []).add(p);
    }

    final sortedKeys = daysMap.keys.toList()..sort();

    int totalPeriodMillis = 0;

    List<List<String>> tableData = [];
    for (var dayKey in sortedKeys) {
      final dayPresences = daysMap[dayKey]!;
      dayPresences.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      
      final dateParts = dayKey.split('-');
      final dateStr = '${dateParts[2]}/${dateParts[1]}/${dateParts[0]}';

      final detailsBuilder = StringBuffer();
      for (var p in dayPresences) {
        final d = DateTime.fromMillisecondsSinceEpoch(p.timestamp);
        final timeStr = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
        detailsBuilder.write('${p.type} à $timeStr (${p.locationName})\n');
      }

      final workedMillis = WorkTimeCalculator.calculateWorkedTime(dayPresences, settings: settings);
      totalPeriodMillis += workedMillis;
      final durationStr = WorkTimeCalculator.formatDuration(workedMillis);

      tableData.add([dateStr, detailsBuilder.toString().trim(), durationStr]);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Title
            pw.Center(
              child: pw.Text(
                'RELEVÉ D’HEURES',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 20),

            // Employee / Employer info
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(employeeName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    if (employeeAddress.isNotEmpty) pw.Text(employeeAddress),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('À l’attention de :', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(employerName),
                    if (employerAddress.isNotEmpty) pw.Text(employerAddress),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            pw.Text('Fait le ${now.day}/${now.month}/${now.year}'),
            pw.SizedBox(height: 15),

            // Table of records
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Pointages', 'Durée'],
              data: tableData,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
              cellPadding: const pw.EdgeInsets.all(8),
              columnWidths: {
                0: const pw.FixedColumnWidth(80),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FixedColumnWidth(80),
              },
            ),
            pw.SizedBox(height: 20),

            // Total period
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text(
                  'TOTAL PÉRIODE : ${WorkTimeCalculator.formatDuration(totalPeriodMillis)}',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ];
        },
      ),
    );

    final bytes = await pdf.save();
    await Printing.sharePdf(bytes: bytes, filename: 'releve_heures.pdf');
  }
}
