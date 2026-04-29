import 'dart:typed_data';

import '../domain/alternative_recommendation.dart';
import '../domain/recommend_request.dart';
import '../domain/recommendation_result.dart';
import '../domain/recommendation_repository.dart';

/// Offline mock — mirrors the backend stub prediction rules.
/// To use: change recommendationRepositoryProvider to return this class.
class RecommendationRepositoryMock implements RecommendationRepository {
  final List<RecommendationResult> _history = [
    RecommendationResult(
      id: 'mock-hist-bracket',
      stlFileId: 'mock-file-bracket',
      intendedUse: 'decorative',
      surfaceFinish: 'fine',
      needsFlexibility: false,
      strengthRequired: 'low',
      budgetPriority: 'quality',
      outdoorUse: false,
      technology: 'FDM',
      material: 'PLA',
      technologyConfidence: 0.91,
      materialConfidence: 0.88,
      confidenceTier: 'high',
      layerHeight: 0.11,
      infillDensity: 20,
      printSpeed: 45,
      wallCount: 2,
      coolingFan: 100,
      supportDensity: 10,
      costScore: 82,
      qualityScore: 91,
      speedScore: 74,
      needsClarification: false,
      userRating: 5,
      createdAt: DateTime(2026, 4, 28, 10, 24),
    ),
    RecommendationResult(
      id: 'mock-hist-dental',
      stlFileId: 'mock-file-dental',
      intendedUse: 'prototype',
      surfaceFinish: 'fine',
      needsFlexibility: false,
      strengthRequired: 'high',
      budgetPriority: 'quality',
      outdoorUse: false,
      technology: 'SLA',
      material: 'Resin-Std',
      technologyConfidence: 0.62,
      materialConfidence: 0.58,
      confidenceTier: 'medium',
      layerHeight: 0.05,
      infillDensity: 100,
      printSpeed: 30,
      wallCount: 0,
      coolingFan: 0,
      supportDensity: 10,
      costScore: 45,
      qualityScore: 92,
      speedScore: 40,
      needsClarification: false,
      createdAt: DateTime(2026, 4, 27, 15, 12),
    ),
    RecommendationResult(
      id: 'mock-hist-proto',
      stlFileId: 'mock-file-proto',
      intendedUse: 'functional',
      surfaceFinish: 'standard',
      needsFlexibility: false,
      strengthRequired: 'medium',
      budgetPriority: 'cost',
      outdoorUse: false,
      technology: 'FDM',
      material: 'PETG',
      technologyConfidence: 0.87,
      materialConfidence: 0.83,
      confidenceTier: 'high',
      layerHeight: 0.20,
      infillDensity: 40,
      printSpeed: 50,
      wallCount: 3,
      coolingFan: 80,
      supportDensity: 15,
      costScore: 65,
      qualityScore: 78,
      speedScore: 72,
      needsClarification: false,
      userRating: 3,
      createdAt: DateTime(2026, 4, 24, 9, 0),
    ),
    RecommendationResult(
      id: 'mock-hist-bracket2',
      stlFileId: 'mock-file-bracket2',
      intendedUse: 'functional',
      surfaceFinish: 'rough',
      needsFlexibility: true,
      strengthRequired: 'high',
      budgetPriority: 'speed',
      outdoorUse: true,
      technology: 'FDM',
      material: 'ABS',
      technologyConfidence: 0.45,
      materialConfidence: 0.40,
      confidenceTier: 'low',
      layerHeight: 0.30,
      infillDensity: 60,
      printSpeed: 60,
      wallCount: 4,
      coolingFan: 30,
      supportDensity: 20,
      costScore: 55,
      qualityScore: 60,
      speedScore: 80,
      needsClarification: false,
      createdAt: DateTime(2026, 4, 21, 14, 30),
    ),
  ];

  @override
  Future<RecommendationResult> createRecommendation(
      RecommendRequest request) async {
    await Future.delayed(const Duration(seconds: 2));

    double layerHeight;
    int infillDensity;
    int printSpeed;
    int wallCount;
    int coolingFan;
    int supportDensity;
    int costScore;
    int qualityScore;
    int speedScore;
    String technology;
    String material;
    double technologyConfidence;
    double materialConfidence;
    String confidenceTier;
    AlternativeRecommendation? alternative;

    switch (request.intendedUse) {
      case 'functional':
        technology = 'FDM';
        material = 'PETG';
        technologyConfidence = 0.87;
        materialConfidence = 0.83;
        confidenceTier = 'high';
        layerHeight = 0.20;
        infillDensity = 40;
        printSpeed = 50;
        wallCount = 3;
        coolingFan = 80;
        supportDensity = 15;
        costScore = 65;
        qualityScore = 78;
        speedScore = 72;
        alternative = null;
        break;
      case 'decorative':
        technology = 'FDM';
        material = 'PLA';
        technologyConfidence = 0.91;
        materialConfidence = 0.88;
        confidenceTier = 'high';
        layerHeight = 0.15;
        infillDensity = 20;
        printSpeed = 45;
        wallCount = 2;
        coolingFan = 100;
        supportDensity = 10;
        costScore = 82;
        qualityScore = 88;
        speedScore = 70;
        alternative = null;
        break;
      default: // prototype
        technology = 'FDM';
        material = 'PLA';
        technologyConfidence = 0.62;
        materialConfidence = 0.58;
        confidenceTier = 'medium';
        layerHeight = 0.20;
        infillDensity = 15;
        printSpeed = 55;
        wallCount = 2;
        coolingFan = 80;
        supportDensity = 10;
        costScore = 88;
        qualityScore = 65;
        speedScore = 82;
        alternative = const AlternativeRecommendation(
          technology: 'SLA',
          material: 'Resin-Std',
          confidence: 0.55,
          costScore: 45,
          qualityScore: 92,
          speedScore: 40,
        );
    }

    // Surface finish modifiers
    if (request.surfaceFinish == 'fine') {
      layerHeight = double.parse((layerHeight * 0.75).toStringAsFixed(3));
      qualityScore = (qualityScore + 8).clamp(0, 100);
    } else if (request.surfaceFinish == 'rough') {
      layerHeight = double.parse((layerHeight * 1.5).toStringAsFixed(3));
      speedScore = (speedScore + 5).clamp(0, 100);
    }

    final result = RecommendationResult(
      id: 'mock-${DateTime.now().millisecondsSinceEpoch}',
      stlFileId: request.fileId,
      orientationRank: request.orientationRank,
      intendedUse: request.intendedUse,
      surfaceFinish: request.surfaceFinish,
      needsFlexibility: request.needsFlexibility,
      strengthRequired: request.strengthRequired,
      budgetPriority: request.budgetPriority,
      outdoorUse: request.outdoorUse,
      technology: technology,
      material: material,
      technologyConfidence: technologyConfidence,
      materialConfidence: materialConfidence,
      confidenceTier: confidenceTier,
      layerHeight: layerHeight,
      infillDensity: infillDensity,
      printSpeed: printSpeed,
      wallCount: wallCount,
      coolingFan: coolingFan,
      supportDensity: supportDensity,
      costScore: costScore,
      qualityScore: qualityScore,
      speedScore: speedScore,
      needsClarification: false,
      alternative: alternative,
      createdAt: DateTime.now(),
    );

    _history.insert(0, result);
    return result;
  }

  @override
  Future<RecommendationResult> rateRecommendation(
      String id, int rating) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final idx = _history.indexWhere((r) => r.id == id);
    if (idx == -1) throw Exception('Recommendation not found');
    final updated = _history[idx].copyWith(userRating: rating);
    _history[idx] = updated;
    return updated;
  }

  @override
  Future<List<RecommendationResult>> getHistory() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return List<RecommendationResult>.from(_history);
  }
  @override
  Future<Uint8List> exportProfile(String id, String slicer) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final content = slicer == 'cura'
        ? '[general]\nversion = 4\nname = Mock_Profile\ndefinition = fdmprinter\n\n[metadata]\ntype = quality\nquality_type = normal\nglobal_quality = True\n\n[values]\nlayer_height = 0.200\ninfill_sparse_density = 20\nspeed_print = 50\nwall_line_count = 3\ncool_fan_enabled = True\nsupport_enable = False\n'
        : '# Mock PrusaSlicer profile\nlayer_height = 0.200\nfirst_layer_height = 0.300\nfill_density = 20%\nperimeters = 3\nperimeter_speed = 50\ninfill_speed = 60\ncooling = 1\nfan_always_on = 1\nsupport_material = 0\n';
    return Uint8List.fromList(content.codeUnits);
  }

  @override
  Future<RecommendationResult> updateParameters(String id, Map<String, dynamic> params) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final idx = _history.indexWhere((r) => r.id == id);
    if (idx == -1) throw Exception('Recommendation not found');

    var updated = _history[idx];
    if (params.containsKey('layerHeight')) {
      updated = updated.copyWith(layerHeight: params['layerHeight']);
    }
    if (params.containsKey('infillDensity')) {
      updated = updated.copyWith(infillDensity: params['infillDensity']);
    }
    if (params.containsKey('printSpeed')) {
      updated = updated.copyWith(printSpeed: params['printSpeed']);
    }
    if (params.containsKey('wallCount')) {
      updated = updated.copyWith(wallCount: params['wallCount']);
    }
    if (params.containsKey('coolingFan')) {
      updated = updated.copyWith(coolingFan: params['coolingFan']);
    }
    if (params.containsKey('supportDensity')) {
      updated = updated.copyWith(supportDensity: params['supportDensity']);
    }

    _history[idx] = updated;
    return updated;
  }

}
