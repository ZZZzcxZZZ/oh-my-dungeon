import 'character.dart';

class CharacterProfile {
  const CharacterProfile({
    this.alignment = '',
    this.appearance = '',
    this.personalityTraits = '',
    this.ideals = '',
    this.bonds = '',
    this.flaws = '',
    this.backstory = '',
    this.languages = const <String>[],
    this.privateNotes = '',
  });

  factory CharacterProfile.fromCharacter(CharacterSheet character) {
    final raw = character.dataMap['profile'];
    final profile = raw is Map
        ? CharacterProfile.fromJson(Map<String, Object?>.from(raw))
        : const CharacterProfile();
    if (profile.privateNotes.isNotEmpty || character.notes.isEmpty) {
      return profile;
    }
    return profile.copyWith(privateNotes: character.notes);
  }

  factory CharacterProfile.fromJson(Map<String, Object?> json) {
    return CharacterProfile(
      alignment: _text(json['alignment']),
      appearance: _text(json['appearance']),
      personalityTraits: _text(json['personalityTraits']),
      ideals: _text(json['ideals']),
      bonds: _text(json['bonds']),
      flaws: _text(json['flaws']),
      backstory: _text(json['backstory']),
      languages: _strings(json['languages']),
      privateNotes: _text(json['privateNotes']),
    );
  }

  final String alignment;
  final String appearance;
  final String personalityTraits;
  final String ideals;
  final String bonds;
  final String flaws;
  final String backstory;
  final List<String> languages;
  final String privateNotes;

  CharacterProfile copyWith({
    String? alignment,
    String? appearance,
    String? personalityTraits,
    String? ideals,
    String? bonds,
    String? flaws,
    String? backstory,
    List<String>? languages,
    String? privateNotes,
  }) {
    return CharacterProfile(
      alignment: alignment ?? this.alignment,
      appearance: appearance ?? this.appearance,
      personalityTraits: personalityTraits ?? this.personalityTraits,
      ideals: ideals ?? this.ideals,
      bonds: bonds ?? this.bonds,
      flaws: flaws ?? this.flaws,
      backstory: backstory ?? this.backstory,
      languages: languages ?? this.languages,
      privateNotes: privateNotes ?? this.privateNotes,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'alignment': alignment,
    'appearance': appearance,
    'personalityTraits': personalityTraits,
    'ideals': ideals,
    'bonds': bonds,
    'flaws': flaws,
    'backstory': backstory,
    'languages': List<String>.unmodifiable(languages),
    'privateNotes': privateNotes,
  };

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CharacterProfile &&
            alignment == other.alignment &&
            appearance == other.appearance &&
            personalityTraits == other.personalityTraits &&
            ideals == other.ideals &&
            bonds == other.bonds &&
            flaws == other.flaws &&
            backstory == other.backstory &&
            privateNotes == other.privateNotes &&
            _listEquals(languages, other.languages);
  }

  @override
  int get hashCode => Object.hash(
    alignment,
    appearance,
    personalityTraits,
    ideals,
    bonds,
    flaws,
    backstory,
    privateNotes,
    Object.hashAll(languages),
  );
}

String _text(Object? value) => value is String ? value : '';

List<String> _strings(Object? value) {
  if (value is! List) return const <String>[];
  return value
      .whereType<String>()
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

bool _listEquals<T>(List<T> left, List<T> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
