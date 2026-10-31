import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../data/models.dart';

class PdfExport {
  static Future<void> generateAndPrintPdf(List<PresenceEntity> presences) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Rapport de Pointage - Badgeuse Auto',
                style: const pw.TextStyle(fontSize: 24),
              ),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headers: ['Date & Heure', 'Type', 'Lieu'],
                data: presences.map((p) {
                  final date = DateTime.fromMillisecondsSinceEpoch(p.timestamp);
                  final dateStr = '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
                  return [dateStr, p.type, p.locationName];
                }).toList(),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'rapport_pointage.pdf',
    );
  }
}
