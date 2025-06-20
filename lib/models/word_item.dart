class WordItem {
  final int? id;
  final String word;
  final String meaning;
  final DateTime createdAt;
  final DateTime updatedAt;

  WordItem({
    this.id,
    required this.word,
    required this.meaning,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'word': word,
      'meaning': meaning,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory WordItem.fromMap(Map<String, dynamic> map) {
    return WordItem(
      id: map['id'],
      word: map['word'],
      meaning: map['meaning'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']),
    );
  }

  WordItem copyWith({
    int? id,
    String? word,
    String? meaning,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WordItem(
      id: id ?? this.id,
      word: word ?? this.word,
      meaning: meaning ?? this.meaning,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}