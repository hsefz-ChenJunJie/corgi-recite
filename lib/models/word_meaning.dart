class WordMeaning {
  final int? id;
  final int wordId;
  final int meaningId;
  final DateTime createdAt;

  WordMeaning({
    this.id,
    required this.wordId,
    required this.meaningId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'word_id': wordId,
      'meaning_id': meaningId,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory WordMeaning.fromMap(Map<String, dynamic> map) {
    return WordMeaning(
      id: map['id'],
      wordId: map['word_id'],
      meaningId: map['meaning_id'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
    );
  }

  WordMeaning copyWith({
    int? id,
    int? wordId,
    int? meaningId,
    DateTime? createdAt,
  }) {
    return WordMeaning(
      id: id ?? this.id,
      wordId: wordId ?? this.wordId,
      meaningId: meaningId ?? this.meaningId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WordMeaning && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}