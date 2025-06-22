/// 上下文感知信息模型
/// 支持四种元信息：不定代词（占位符）、介词、多关键词、词性
class ContextInfo {
  final int? id;
  final String originalText;  // 原始文本（包含标记符号）
  final String displayText;   // 显示文本（去除标记符号）
  final List<Placeholder> placeholders;  // 占位符列表
  final List<Preposition> prepositions;  // 介词列表
  final List<String> keywords;           // 关键词列表（多关键词用|分隔）
  final String? partOfSpeech;           // 词性
  final DateTime createdAt;
  final DateTime updatedAt;

  ContextInfo({
    this.id,
    required this.originalText,
    required this.displayText,
    required this.placeholders,
    required this.prepositions,
    required this.keywords,
    this.partOfSpeech,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'original_text': originalText,
      'display_text': displayText,
      'placeholders': placeholders.map((p) => p.toMap()).toList(),
      'prepositions': prepositions.map((p) => p.toMap()).toList(),
      'keywords': keywords,
      'part_of_speech': partOfSpeech,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory ContextInfo.fromMap(Map<String, dynamic> map) {
    return ContextInfo(
      id: map['id'],
      originalText: map['original_text'],
      displayText: map['display_text'],
      placeholders: (map['placeholders'] as List?)
          ?.map((p) => Placeholder.fromMap(p))
          .toList() ?? [],
      prepositions: (map['prepositions'] as List?)
          ?.map((p) => Preposition.fromMap(p))
          .toList() ?? [],
      keywords: List<String>.from(map['keywords'] ?? []),
      partOfSpeech: map['part_of_speech'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']),
    );
  }

  ContextInfo copyWith({
    int? id,
    String? originalText,
    String? displayText,
    List<Placeholder>? placeholders,
    List<Preposition>? prepositions,
    List<String>? keywords,
    String? partOfSpeech,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ContextInfo(
      id: id ?? this.id,
      originalText: originalText ?? this.originalText,
      displayText: displayText ?? this.displayText,
      placeholders: placeholders ?? this.placeholders,
      prepositions: prepositions ?? this.prepositions,
      keywords: keywords ?? this.keywords,
      partOfSpeech: partOfSpeech ?? this.partOfSpeech,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContextInfo && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// 占位符（不定代词）模型
class Placeholder {
  final String content;    // 占位符内容，如 "someone", "something"
  final int startIndex;    // 在原文中的开始位置
  final int endIndex;      // 在原文中的结束位置
  final String? hint;      // 提示信息

  Placeholder({
    required this.content,
    required this.startIndex,
    required this.endIndex,
    this.hint,
  });

  Map<String, dynamic> toMap() {
    return {
      'content': content,
      'start_index': startIndex,
      'end_index': endIndex,
      'hint': hint,
    };
  }

  factory Placeholder.fromMap(Map<String, dynamic> map) {
    return Placeholder(
      content: map['content'],
      startIndex: map['start_index'],
      endIndex: map['end_index'],
      hint: map['hint'],
    );
  }
}

/// 介词模型
class Preposition {
  final String content;    // 介词内容，如 "in", "on", "at"
  final int startIndex;    // 在原文中的开始位置
  final int endIndex;      // 在原文中的结束位置
  final List<String> alternatives; // 可选的其他介词

  Preposition({
    required this.content,
    required this.startIndex,
    required this.endIndex,
    required this.alternatives,
  });

  Map<String, dynamic> toMap() {
    return {
      'content': content,
      'start_index': startIndex,
      'end_index': endIndex,
      'alternatives': alternatives,
    };
  }

  factory Preposition.fromMap(Map<String, dynamic> map) {
    return Preposition(
      content: map['content'],
      startIndex: map['start_index'],
      endIndex: map['end_index'],
      alternatives: List<String>.from(map['alternatives'] ?? []),
    );
  }
}

/// 填空题模型
class BlankQuizItem {
  final String template;           // 填空题模板，用 ___ 表示空白
  final List<BlankAnswer> blanks;  // 空白答案列表
  final String originalText;       // 原始完整文本
  final ContextInfo contextInfo;   // 上下文信息

  BlankQuizItem({
    required this.template,
    required this.blanks,
    required this.originalText,
    required this.contextInfo,
  });

  Map<String, dynamic> toMap() {
    return {
      'template': template,
      'blanks': blanks.map((b) => b.toMap()).toList(),
      'original_text': originalText,
      'context_info': contextInfo.toMap(),
    };
  }

  factory BlankQuizItem.fromMap(Map<String, dynamic> map) {
    return BlankQuizItem(
      template: map['template'],
      blanks: (map['blanks'] as List)
          .map((b) => BlankAnswer.fromMap(b))
          .toList(),
      originalText: map['original_text'],
      contextInfo: ContextInfo.fromMap(map['context_info']),
    );
  }
}

/// 填空答案模型
class BlankAnswer {
  final int index;                 // 空白编号（从0开始）
  final String correctAnswer;      // 正确答案
  final List<String> acceptableAnswers; // 可接受的答案列表
  final String? hint;              // 提示信息
  final BlankType type;            // 空白类型

  BlankAnswer({
    required this.index,
    required this.correctAnswer,
    required this.acceptableAnswers,
    this.hint,
    required this.type,
  });

  Map<String, dynamic> toMap() {
    return {
      'index': index,
      'correct_answer': correctAnswer,
      'acceptable_answers': acceptableAnswers,
      'hint': hint,
      'type': type.name,
    };
  }

  factory BlankAnswer.fromMap(Map<String, dynamic> map) {
    return BlankAnswer(
      index: map['index'],
      correctAnswer: map['correct_answer'],
      acceptableAnswers: List<String>.from(map['acceptable_answers']),
      hint: map['hint'],
      type: BlankType.values.byName(map['type']),
    );
  }
}

/// 空白类型枚举
enum BlankType {
  placeholder,   // 不定代词（占位符）
  preposition,   // 介词
  keyword,       // 关键词
  partOfSpeech,  // 词性
  regular,       // 常规文本
}