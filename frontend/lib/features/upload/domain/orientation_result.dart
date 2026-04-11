/// Résultat d'une orientation d'impression retourné par GET /stl/{id}/orientation.
class OrientationResult {
  final int rank;           // 1 / 2 / 3
  final double rxDeg;       // rotation X en degrés
  final double ryDeg;       // rotation Y en degrés
  final double rzDeg;       // rotation Z en degrés
  final double score;       // 0.0–1.0
  final double overhangReductionPct;
  final double printHeightMm;

  const OrientationResult({
    required this.rank,
    required this.rxDeg,
    required this.ryDeg,
    required this.rzDeg,
    required this.score,
    required this.overhangReductionPct,
    required this.printHeightMm,
  });

  factory OrientationResult.fromJson(Map<String, dynamic> json) {
    return OrientationResult(
      rank: (json['rank'] as num).toInt(),
      rxDeg: (json['rx_deg'] as num).toDouble(),
      ryDeg: (json['ry_deg'] as num).toDouble(),
      rzDeg: (json['rz_deg'] as num).toDouble(),
      score: (json['score'] as num).toDouble(),
      overhangReductionPct:
          (json['overhang_reduction_pct'] as num).toDouble(),
      printHeightMm: (json['print_height_mm'] as num).toDouble(),
    );
  }

  /// Convertit en Map pour la compatibilité avec OrientationCard
  /// qui attend les clés 'rx', 'ry', 'rz', 'score', etc.
  Map<String, dynamic> toCardData() => {
        'rx': rxDeg,
        'ry': ryDeg,
        'rz': rzDeg,
        'score': score,
        'overhang_reduction_pct': overhangReductionPct,
        'print_height_mm': printHeightMm,
      };
}