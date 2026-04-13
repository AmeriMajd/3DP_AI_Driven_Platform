/// Résultat d'une orientation d'impression retourné par GET /stl/{id}/orientation.
class OrientationResult {
  final int rank;           // 1 / 2 / 3
  final double rxDeg;       // rotation X en degrés
  final double ryDeg;       // rotation Y en degrés
  final double rzDeg;       // rotation Z en degrés
  final double score;       // 0.0–1.0
  final double overhangReductionPct;
  final double printHeightMm;
  // Enriched fields — exclusive to GET /stl/{id}/orientation
  final double supportVolumeMm3;  // estimated support material volume
  final double contactAreaMm2;    // build-plate contact area
  final double buildHeightMm;     // Z extent in this orientation

  const OrientationResult({
    required this.rank,
    required this.rxDeg,
    required this.ryDeg,
    required this.rzDeg,
    required this.score,
    required this.overhangReductionPct,
    required this.printHeightMm,
    required this.supportVolumeMm3,
    required this.contactAreaMm2,
    required this.buildHeightMm,
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
      supportVolumeMm3: (json['support_volume_mm3'] as num).toDouble(),
      contactAreaMm2: (json['contact_area_mm2'] as num).toDouble(),
      buildHeightMm: (json['build_height_mm'] as num).toDouble(),
    );
  }

  /// Payload passed to the ML recommendation service when the user
  /// selects an orientation. Contains all orientation fields.
  Map<String, dynamic> toCardData() => {
        'rank': rank,
        'rx': rxDeg,
        'ry': ryDeg,
        'rz': rzDeg,
        'score': score,
        'overhang_reduction_pct': overhangReductionPct,
        'print_height_mm': printHeightMm,
        'support_volume_mm3': supportVolumeMm3,
        'contact_area_mm2': contactAreaMm2,
        'build_height_mm': buildHeightMm,
      };
}