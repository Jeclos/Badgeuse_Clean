import '../data/models.dart';

class WorkTimeCalculator {
  /// Calcule le temps de travail total en millisecondes à partir d'une liste de pointages (Entrée/Sortie).
  static int calculateWorkedTime(List<PresenceEntity> presences, {SettingsEntity? settings}) {
    // Trier par timestamp croissant
    final sorted = List<PresenceEntity>.from(presences)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    int totalMillis = 0;
    int? lastEnterTime;

    for (var p in sorted) {
      if (p.type == 'ENTRÉE' || p.type.startsWith('AUTO_')) {
        lastEnterTime = p.timestamp;
      } else if ((p.type == 'SORTIE' || p.type.startsWith('AUTO_')) && lastEnterTime != null) {
        var start = lastEnterTime;
        var end = p.timestamp;

        // Mode Depot rules
        if (settings != null && settings.badgeMode == 'DEPOT') {
          // Depot adjustments if applicable
        }

        totalMillis += (end - start);
        lastEnterTime = null;
      }
    }

    // Si toujours en cours (entrée sans sortie)
    if (lastEnterTime != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now > lastEnterTime) {
        totalMillis += (now - lastEnterTime);
      }
    }

    // Déduction de la pause déjeuner si activée
    if (settings != null && settings.lunchBreakEnabled && totalMillis > 0) {
      final lunchMillis = settings.lunchDurationMin * 60 * 1000;
      if (totalMillis > lunchMillis) {
        totalMillis -= lunchMillis;
      }
    }

    return totalMillis < 0 ? 0 : totalMillis;
  }

  static String formatDuration(int millis) {
    final seconds = (millis / 1000).floor();
    final hours = (seconds / 3600).floor();
    final minutes = ((seconds % 3600) / 60).floor();
    return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
  }
}
