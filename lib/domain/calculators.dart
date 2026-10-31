import '../data/models.dart';

class WorkTimeCalculator {
  /// Calcule le temps de travail total en millisecondes à partir d'une liste de pointages (Entrée/Sortie) pour une journée.
  static int calculateWorkedTime(List<PresenceEntity> presences) {
    // Trier par timestamp croissant
    final sorted = List<PresenceEntity>.from(presences)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    int totalMillis = 0;
    int? lastEnterTime;

    for (var p in sorted) {
      if (p.type == 'ENTRÉE') {
        lastEnterTime = p.timestamp;
      } else if (p.type == 'SORTIE' && lastEnterTime != null) {
        totalMillis += (p.timestamp - lastEnterTime);
        lastEnterTime = null;
      }
    }

    // Si toujours en cours (entrée sans sortie et fin de journée en cours)
    if (lastEnterTime != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now > lastEnterTime) {
        totalMillis += (now - lastEnterTime);
      }
    }

    return totalMillis;
  }

  static String formatDuration(int millis) {
    final seconds = (millis / 1000).floor();
    final hours = (seconds / 3600).floor();
    final minutes = ((seconds % 3600) / 60).floor();
    return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
  }
}
