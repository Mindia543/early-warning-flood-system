import '../models/flood_warning.dart';

enum FloodRiskLevel { clear, watch, warning, emergency }

class FloodRiskAssessment {
  const FloodRiskAssessment({
    required this.score,
    required this.level,
    required this.factors,
  });

  final int score;
  final FloodRiskLevel level;
  final List<String> factors;

  bool get shouldAlert =>
      level == FloodRiskLevel.warning || level == FloodRiskLevel.emergency;

  WarningSeverity get warningSeverity => level == FloodRiskLevel.emergency
      ? WarningSeverity.severe
      : level == FloodRiskLevel.warning
      ? WarningSeverity.high
      : WarningSeverity.moderate;

  String get label => switch (level) {
    FloodRiskLevel.clear => 'Low risk',
    FloodRiskLevel.watch => 'Watch',
    FloodRiskLevel.warning => 'Warning',
    FloodRiskLevel.emergency => 'Emergency',
  };

  String get summary {
    if (factors.isEmpty) {
      return 'Conditions are below the alert thresholds.';
    }
    return factors.join(' • ');
  }
}

/// A transparent baseline model for early warning when sensor values are
/// available. It combines absolute water level, rainfall intensity, and the
/// rate at which water is rising instead of relying on a hidden prediction.
class FloodRiskService {
  const FloodRiskService._();

  static FloodRiskAssessment assess({
    required double waterLevelCm,
    required double rainfallMmPerHour,
    required double riseRateCmPerHour,
  }) {
    var score = 0;
    final factors = <String>[];

    if (waterLevelCm >= 80) {
      score += 40;
      factors.add('Water level is critically high');
    } else if (waterLevelCm >= 50) {
      score += 25;
      factors.add('Water level is high');
    } else if (waterLevelCm >= 25) {
      score += 12;
      factors.add('Water level is rising above normal');
    }

    if (rainfallMmPerHour >= 50) {
      score += 30;
      factors.add('Very heavy rainfall detected');
    } else if (rainfallMmPerHour >= 20) {
      score += 20;
      factors.add('Heavy rainfall detected');
    } else if (rainfallMmPerHour >= 10) {
      score += 10;
      factors.add('Sustained rainfall detected');
    }

    if (riseRateCmPerHour >= 10) {
      score += 35;
      factors.add('Water is rising rapidly');
    } else if (riseRateCmPerHour >= 5) {
      score += 22;
      factors.add('Water is rising quickly');
    } else if (riseRateCmPerHour >= 2) {
      score += 10;
      factors.add('Water level is increasing');
    }

    final level = score >= 90
        ? FloodRiskLevel.emergency
        : score >= 45
        ? FloodRiskLevel.warning
        : score >= 20
        ? FloodRiskLevel.watch
        : FloodRiskLevel.clear;

    return FloodRiskAssessment(score: score, level: level, factors: factors);
  }
}
