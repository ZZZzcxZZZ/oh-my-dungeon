class CheckRollComponent {
  const CheckRollComponent({required this.notation, required this.results});

  final String notation;
  final List<int> results;

  factory CheckRollComponent.fromJson(Map<String, Object?> json) {
    return CheckRollComponent(
      notation: json['notation']! as String,
      results: (json['results'] as List<Object?>)
          .map((value) => (value as num).toInt())
          .toList(),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CheckRollComponent &&
            notation == other.notation &&
            _listEquals(results, other.results);
  }

  @override
  int get hashCode => Object.hash(notation, Object.hashAll(results));
}

class CheckResponse {
  const CheckResponse({
    required this.id,
    required this.requestId,
    required this.responderId,
    required this.characterId,
    required this.notation,
    required this.total,
    required this.components,
    required this.result,
    required this.createdAt,
  });

  final String id;
  final String requestId;
  final String responderId;
  final String? characterId;
  final String notation;
  final int total;
  final List<CheckRollComponent> components;
  final String result;
  final String createdAt;

  factory CheckResponse.fromJson(Map<String, Object?> json) {
    return CheckResponse(
      id: json['id']! as String,
      requestId: json['requestId']! as String,
      responderId: json['responderId']! as String,
      characterId: json['characterId'] as String?,
      notation: json['notation']! as String,
      total: (json['total'] as num).toInt(),
      components: (json['components'] as List<Object?>? ?? const [])
          .map(
            (value) =>
                CheckRollComponent.fromJson(value as Map<String, Object?>),
          )
          .toList(),
      result: json['result']! as String,
      createdAt: json['createdAt']! as String,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CheckResponse &&
            id == other.id &&
            requestId == other.requestId &&
            responderId == other.responderId &&
            characterId == other.characterId &&
            notation == other.notation &&
            total == other.total &&
            _listEquals(components, other.components) &&
            result == other.result &&
            createdAt == other.createdAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    requestId,
    responderId,
    characterId,
    notation,
    total,
    Object.hashAll(components),
    result,
    createdAt,
  );
}

class CheckRequest {
  const CheckRequest({
    required this.id,
    required this.sessionId,
    required this.requestedBy,
    required this.label,
    required this.checkType,
    required this.ability,
    required this.skill,
    required this.dc,
    required this.dcVisibility,
    required this.targetMode,
    required this.targetUserIds,
    required this.targetCharacterIds,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.responses,
  });

  final String id;
  final String sessionId;
  final String requestedBy;
  final String label;
  final String checkType;
  final String? ability;
  final String? skill;
  final int? dc;
  final String dcVisibility;
  final String targetMode;
  final List<String> targetUserIds;
  final List<String> targetCharacterIds;
  final String status;
  final String createdAt;
  final String updatedAt;
  final List<CheckResponse> responses;

  factory CheckRequest.fromJson(Map<String, Object?> json) {
    return CheckRequest(
      id: json['id']! as String,
      sessionId: json['sessionId']! as String,
      requestedBy: json['requestedBy']! as String,
      label: json['label']! as String,
      checkType: json['checkType']! as String,
      ability: json['ability'] as String?,
      skill: json['skill'] as String?,
      dc: (json['dc'] as num?)?.toInt(),
      dcVisibility: json['dcVisibility']! as String,
      targetMode: json['targetMode']! as String,
      targetUserIds: (json['targetUserIds'] as List<Object?>? ?? const [])
          .whereType<String>()
          .toList(),
      targetCharacterIds:
          (json['targetCharacterIds'] as List<Object?>? ?? const [])
              .whereType<String>()
              .toList(),
      status: json['status']! as String,
      createdAt: json['createdAt']! as String,
      updatedAt: json['updatedAt']! as String,
      responses: (json['responses'] as List<Object?>? ?? const [])
          .map((value) => CheckResponse.fromJson(value as Map<String, Object?>))
          .toList(),
    );
  }

  CheckRequest copyWith({
    String? id,
    String? label,
    String? status,
    List<CheckResponse>? responses,
  }) {
    return CheckRequest(
      id: id ?? this.id,
      sessionId: sessionId,
      requestedBy: requestedBy,
      label: label ?? this.label,
      checkType: checkType,
      ability: ability,
      skill: skill,
      dc: dc,
      dcVisibility: dcVisibility,
      targetMode: targetMode,
      targetUserIds: targetUserIds,
      targetCharacterIds: targetCharacterIds,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt,
      responses: responses ?? this.responses,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CheckRequest &&
            id == other.id &&
            sessionId == other.sessionId &&
            requestedBy == other.requestedBy &&
            label == other.label &&
            checkType == other.checkType &&
            ability == other.ability &&
            skill == other.skill &&
            dc == other.dc &&
            dcVisibility == other.dcVisibility &&
            targetMode == other.targetMode &&
            _listEquals(targetUserIds, other.targetUserIds) &&
            _listEquals(targetCharacterIds, other.targetCharacterIds) &&
            status == other.status &&
            createdAt == other.createdAt &&
            updatedAt == other.updatedAt &&
            _listEquals(responses, other.responses);
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    requestedBy,
    label,
    checkType,
    ability,
    skill,
    dc,
    dcVisibility,
    targetMode,
    Object.hashAll(targetUserIds),
    Object.hashAll(targetCharacterIds),
    status,
    createdAt,
    updatedAt,
    Object.hashAll(responses),
  );
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
