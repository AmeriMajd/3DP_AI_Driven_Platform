class RecommendRequest {
  final String fileId;
  final int? orientationRank;
  final String intendedUse;      // functional / decorative / prototype
  final String surfaceFinish;    // rough / standard / fine
  final bool needsFlexibility;
  final String strengthRequired; // low / medium / high
  final String budgetPriority;   // cost / quality / speed
  final bool outdoorUse;
  final String priorityFace;     // top / bottom / front / none

  const RecommendRequest({
    required this.fileId,
    this.orientationRank,
    required this.intendedUse,
    required this.surfaceFinish,
    required this.needsFlexibility,
    required this.strengthRequired,
    required this.budgetPriority,
    required this.outdoorUse,
    required this.priorityFace,
  });

  Map<String, dynamic> toJson() => {
        'file_id': fileId,
        if (orientationRank != null) 'orientation_rank': orientationRank,
        'intended_use': intendedUse,
        'surface_finish': surfaceFinish,
        'needs_flexibility': needsFlexibility,
        'strength_required': strengthRequired,
        'budget_priority': budgetPriority,
        'outdoor_use': outdoorUse,
        'priority_face': priorityFace,
      };
}
