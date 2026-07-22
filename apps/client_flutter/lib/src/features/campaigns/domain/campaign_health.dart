/// Derives the viewer-safe health grade used by campaign avatars.
String? campaignHealthStateFromHp(num? currentHp, num? maxHp) {
  if (maxHp == null || maxHp <= 0 || currentHp == null) return null;
  if (currentHp <= 0) return 'down';
  final ratio = currentHp / maxHp;
  if (ratio > 0.5) return 'healthy';
  if (ratio > 0.25) return 'injured';
  return 'critical';
}

double? campaignHealthFractionFromHp(num? currentHp, num? maxHp) {
  if (maxHp == null || maxHp <= 0 || currentHp == null) return null;
  return (currentHp / maxHp).clamp(0, 1).toDouble();
}

String? campaignHealthStateFromSheet(Map<String, Object?> sheet) {
  final currentHp = sheet['currentHp'];
  final maxHp = sheet['maxHp'];
  return campaignHealthStateFromHp(
    currentHp is num ? currentHp : null,
    maxHp is num ? maxHp : null,
  );
}

double? campaignHealthFractionFromSheet(Map<String, Object?> sheet) {
  final currentHp = sheet['currentHp'];
  final maxHp = sheet['maxHp'];
  return campaignHealthFractionFromHp(
    currentHp is num ? currentHp : null,
    maxHp is num ? maxHp : null,
  );
}
