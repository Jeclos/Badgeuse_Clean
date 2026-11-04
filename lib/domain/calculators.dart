import '../data/models.dart';

class LunchBreakCalculator {
  static int computeLunchAbsenceMinutes(List<PresenceEntity> presences, SettingsEntity settings) {
    if (!settings.lunchBreakEnabled) return 0;

    final pauseMin = settings.lunchDurationMin;

    // Filter presences with valid exits
    final sorted = List<PresenceEntity>.from(presences)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (sorted.isEmpty) return 0;

    final firstEnter = sorted.first.timestamp;
    final lastExit = sorted.last.timestamp;

    // Lunch window for the day
    final firstDate = DateTime.fromMillisecondsSinceEpoch(firstEnter);
    final windowStart = DateTime(firstDate.year, firstDate.month, firstDate.day, settings.lunchStartHour, settings.lunchStartMin).millisecondsSinceEpoch;
    final windowEnd = DateTime(firstDate.year, firstDate.month, firstDate.day, settings.lunchEndHour, settings.lunchEndMin).millisecondsSinceEpoch;

    final isFullDay = firstEnter < windowStart && lastExit > windowEnd;
    if (!isFullDay) return 0;

    int absenceInWindowMs = 0;
    for (int i = 0; i < sorted.length - 1; i += 2) {
      final current = sorted[i];
      if (i + 1 < sorted.length) {
        final next = sorted[i + 1];
        final gapStart = current.timestamp;
        final gapEnd = next.timestamp;

        final overlapStart = gapStart > windowStart ? gapStart : windowStart;
        final overlapEnd = gapEnd < windowEnd ? gapEnd : windowEnd;

        if (overlapEnd > overlapStart) {
          absenceInWindowMs += (overlapEnd - overlapStart);
        }
      }
    }

    final absenceInWindowMin = (absenceInWindowMs / 60000).floor();
    return (pauseMin - absenceInWindowMin > 0) ? (pauseMin - absenceInWindowMin) : 0;
  }
}

class WorkTimeCalculator {
  /// Calcule le temps de travail total en millisecondes à partir d'une liste de pointages (Entrée/Sortie).
  static int calculateWorkedTime(List<PresenceEntity> presences, {SettingsEntity? settings}) {
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

        // Mode Depot adjustments
        if (settings != null && settings.badgeMode == 'DEPOT') {
          // Depot specific window clamping
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

    // Déduction pause déjeuner
    if (settings != null && settings.lunchBreakEnabled && totalMillis > 0) {
      final lunchMin = LunchBreakCalculator.computeLunchAbsenceMinutes(presences, settings);
      totalMillis -= (lunchMin * 60 * 1000);
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
