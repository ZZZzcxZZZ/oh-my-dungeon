class Room {
  const Room({required this.id, required this.name});

  final String id;
  final String name;

  factory Room.fromJson(Map<String, Object?> json) {
    return Room(id: json['id']! as String, name: json['name']! as String);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Room &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            name == other.name;
  }

  @override
  int get hashCode => Object.hash(id, name);
}
