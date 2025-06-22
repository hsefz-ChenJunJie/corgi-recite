class Word {
  final int? id;
  final String text;
  final DateTime createdAt;
  final DateTime updatedAt;

  Word({
    this.id,
    required this.text,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Word.fromMap(Map<String, dynamic> map) {
    return Word(
      id: map['id'],
      text: map['text'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']),
    );
  }

  Word copyWith({
    int? id,
    String? text,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Word(
      id: id ?? this.id,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Word && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}