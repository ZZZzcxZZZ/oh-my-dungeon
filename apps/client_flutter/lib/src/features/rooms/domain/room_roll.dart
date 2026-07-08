class RoomRoll {
  const RoomRoll({
    required this.id,
    required this.roomId,
    required this.notation,
    required this.total,
    required this.actorName,
    required this.actorMode,
    required this.createdAt,
  });

  final String id;
  final String roomId;
  final String notation;
  final int total;
  final String actorName;
  final String actorMode;
  final String createdAt;

  factory RoomRoll.fromJson(Map<String, Object?> json) {
    return RoomRoll(
      id: json['id']! as String,
      roomId: json['roomId']! as String,
      notation: json['notation']! as String,
      total: json['total']! as int,
      actorName: json['actorName']! as String,
      actorMode: json['actorMode']! as String,
      createdAt: json['createdAt']! as String,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is RoomRoll &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            roomId == other.roomId &&
            notation == other.notation &&
            total == other.total &&
            actorName == other.actorName &&
            actorMode == other.actorMode &&
            createdAt == other.createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      roomId,
      notation,
      total,
      actorName,
      actorMode,
      createdAt,
    );
  }
}
