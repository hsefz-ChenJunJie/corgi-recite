import '../models/context_info.dart';

/// 测试方向
enum QuizDirection {
  wordToMeaning,   // 词语→意项
  meaningToWord,   // 意项→词语
}

/// 上下文感知输入格式解析器
/// 支持三种元信息标记：
/// 1. 不定代词（占位符）：{something} {someone}
/// 2. 介词：[in] [on] [at]
/// 3. 词性：(n.) (v.) (adj.)
class ContextParser {
  
  /// 解析输入文本，提取上下文信息
  static ParseResult parseText(String text) {
    if (text.trim().isEmpty) {
      return ParseResult(
        contextInfo: null,
        displayText: text,
        hasContext: false,
      );
    }

    final placeholders = <Placeholder>[];
    final prepositions = <Preposition>[];
    String? partOfSpeech;
    String displayText = text;
    String processedText = text;

    // 1. 解析词性：(n.) (v.) (adj.)
    final partOfSpeechMatch = RegExp(r'\(([^)]+)\)').firstMatch(processedText);
    if (partOfSpeechMatch != null) {
      partOfSpeech = partOfSpeechMatch.group(1);
      processedText = processedText.replaceFirst(partOfSpeechMatch.group(0)!, '').trim();
      displayText = displayText.replaceFirst(partOfSpeechMatch.group(0)!, '').trim();
    }

    // 2. 解析不定代词（占位符）：{something} {someone}
    final placeholderMatches = RegExp(r'\{([^}]+)\}').allMatches(processedText);
    for (final match in placeholderMatches) {
      final content = match.group(1)!;
      final startIndex = match.start;
      final endIndex = match.end;
      
      placeholders.add(Placeholder(
        content: content,
        startIndex: startIndex,
        endIndex: endIndex,
        hint: _getPlaceholderHint(content),
      ));
    }
    
    // 移除占位符标记，保留内容
    processedText = processedText.replaceAllMapped(RegExp(r'\{([^}]+)\}'), (match) => match.group(1)!);
    displayText = displayText.replaceAllMapped(RegExp(r'\{([^}]+)\}'), (match) => match.group(1)!);

    // 3. 解析介词：[in] [on] [at]
    final prepositionMatches = RegExp(r'\[([^\]]+)\]').allMatches(processedText);
    for (final match in prepositionMatches) {
      final content = match.group(1)!;
      final startIndex = match.start;
      final endIndex = match.end;
      
      prepositions.add(Preposition(
        content: content,
        startIndex: startIndex,
        endIndex: endIndex,
        alternatives: _getPrepositionAlternatives(content),
      ));
    }
    
    // 移除介词标记，保留内容
    processedText = processedText.replaceAllMapped(RegExp(r'\[([^\]]+)\]'), (match) => match.group(1)!);
    displayText = displayText.replaceAllMapped(RegExp(r'\[([^\]]+)\]'), (match) => match.group(1)!);


    final hasContext = placeholders.isNotEmpty || 
                      prepositions.isNotEmpty || 
                      partOfSpeech != null;

    if (!hasContext) {
      return ParseResult(
        contextInfo: null,
        displayText: displayText,
        hasContext: false,
      );
    }

    final contextInfo = ContextInfo(
      originalText: text,
      displayText: displayText.trim(),
      placeholders: placeholders,
      prepositions: prepositions,
      partOfSpeech: partOfSpeech,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    return ParseResult(
      contextInfo: contextInfo,
      displayText: displayText.trim(),
      hasContext: true,
    );
  }

  /// 生成填空题
  /// [direction] 指定测试方向：wordToMeaning 或 meaningToWord
  static BlankQuizItem generateBlankQuiz(ContextInfo contextInfo, QuizDirection direction) {
    String template = contextInfo.displayText;
    final blanks = <BlankAnswer>[];
    int blankIndex = 0;

    // 根据不同的测试方向采用不同的填空策略
    switch (direction) {
      case QuizDirection.wordToMeaning:
        // 词语→意项：显示所有关键词，只需填空其他内容
        template = _processWordToMeaning(contextInfo, template, blanks, blankIndex);
        break;
      case QuizDirection.meaningToWord:
        // 意项→词语：特殊处理介词和关键词
        template = _processMeaningToWord(contextInfo, template, blanks, blankIndex);
        break;
    }

    return BlankQuizItem(
      template: template,
      blanks: blanks,
      originalText: contextInfo.originalText,
      contextInfo: contextInfo,
    );
  }

  /// 处理词语→意项的填空策略
  /// 根据用户要求：词语→意项应显示所有信息，不进行填空
  static String _processWordToMeaning(ContextInfo contextInfo, String template, List<BlankAnswer> blanks, int blankIndex) {
    // 词语→意项：显示所有信息，不进行填空
    // 直接返回原模板，不生成任何填空题
    return template;
  }

  /// 处理意项→词语的填空策略
  /// 根据用户要求：意项→词语进行差异化填空处理
  static String _processMeaningToWord(ContextInfo contextInfo, String template, List<BlankAnswer> blanks, int blankIndex) {
    
    if (contextInfo.prepositions.isNotEmpty) {
      // 有介词的情况：只需要填空介词，其他内容直接显示
      for (final preposition in contextInfo.prepositions) {
        if (template.contains(preposition.content)) {
          template = template.replaceFirst(preposition.content, '___');
          blanks.add(BlankAnswer(
            index: blankIndex++,
            correctAnswer: preposition.content,
            acceptableAnswers: [preposition.content, ...preposition.alternatives],
            hint: '介词',
            type: BlankType.preposition,
          ));
          break; // 只替换第一个介词
        }
      }
    } else if (contextInfo.placeholders.isNotEmpty) {
      // 只有不定代词的情况：显示不定代词，填空其他内容
      final wordsToBlank = _extractNonSpecialWords(contextInfo, template);
      for (final word in wordsToBlank) {
        if (template.contains(word)) {
          template = template.replaceFirst(word, '___');
          blanks.add(BlankAnswer(
            index: blankIndex++,
            correctAnswer: word,
            acceptableAnswers: [word],
            hint: '填写除不定代词外的内容',
            type: BlankType.regular,
          ));
          break; // 只替换一个词
        }
      }
    } else {
      // 没有特殊标记的情况：正常填空
      final wordsToBlank = _extractNonSpecialWords(contextInfo, template);
      for (final word in wordsToBlank) {
        if (template.contains(word)) {
          template = template.replaceFirst(word, '___');
          blanks.add(BlankAnswer(
            index: blankIndex++,
            correctAnswer: word,
            acceptableAnswers: [word],
            hint: '填写内容',
            type: BlankType.regular,
          ));
          break; // 只替换一个词
        }
      }
    }

    return template;
  }

  /// 为了向后兼容，保留原有方法
  static BlankQuizItem generateBlankQuizLegacy(ContextInfo contextInfo) {
    String template = contextInfo.displayText;
    final blanks = <BlankAnswer>[];
    int blankIndex = 0;

    // 1. 处理占位符
    for (final placeholder in contextInfo.placeholders) {
      template = template.replaceFirst(placeholder.content, '___');
      blanks.add(BlankAnswer(
        index: blankIndex++,
        correctAnswer: placeholder.content,
        acceptableAnswers: [placeholder.content, ...(_getPlaceholderSynonyms(placeholder.content))],
        hint: placeholder.hint,
        type: BlankType.placeholder,
      ));
    }

    // 2. 处理介词
    for (final preposition in contextInfo.prepositions) {
      template = template.replaceFirst(preposition.content, '___');
      blanks.add(BlankAnswer(
        index: blankIndex++,
        correctAnswer: preposition.content,
        acceptableAnswers: [preposition.content, ...preposition.alternatives],
        hint: '介词',
        type: BlankType.preposition,
      ));
    }


    // 4. 处理词性
    if (contextInfo.partOfSpeech != null) {
      template = '$template (___.)';
      blanks.add(BlankAnswer(
        index: blankIndex++,
        correctAnswer: contextInfo.partOfSpeech!,
        acceptableAnswers: [contextInfo.partOfSpeech!],
        hint: '词性',
        type: BlankType.partOfSpeech,
      ));
    }

    return BlankQuizItem(
      template: template,
      blanks: blanks,
      originalText: contextInfo.originalText,
      contextInfo: contextInfo,
    );
  }

  /// 验证填空题答案
  static QuizValidationResult validateBlankAnswers(BlankQuizItem quizItem, List<String> answers) {
    if (answers.length != quizItem.blanks.length) {
      return QuizValidationResult(
        isCorrect: false,
        correctCount: 0,
        totalCount: quizItem.blanks.length,
        incorrectBlanks: List.generate(quizItem.blanks.length, (i) => i),
        feedback: '答案数量不匹配',
      );
    }

    int correctCount = 0;
    final incorrectBlanks = <int>[];
    final feedback = <String>[];

    for (int i = 0; i < answers.length; i++) {
      final userAnswer = answers[i].trim().toLowerCase();
      final blank = quizItem.blanks[i];
      final acceptableAnswers = blank.acceptableAnswers.map((a) => a.toLowerCase()).toList();
      
      if (acceptableAnswers.contains(userAnswer)) {
        correctCount++;
      } else {
        incorrectBlanks.add(i);
        feedback.add('第${i + 1}空错误，正确答案：${blank.correctAnswer}');
      }
    }

    return QuizValidationResult(
      isCorrect: correctCount == answers.length,
      correctCount: correctCount,
      totalCount: answers.length,
      incorrectBlanks: incorrectBlanks,
      feedback: feedback.join('; '),
    );
  }

  /// 获取占位符提示
  static String? _getPlaceholderHint(String content) {
    final hints = {
      'someone': '某人',
      'somebody': '某人',
      'something': '某物',
      'somewhere': '某地',
      'somehow': '以某种方式',
      'anyone': '任何人',
      'anything': '任何事物',
      'anywhere': '任何地方',
    };
    return hints[content.toLowerCase()];
  }

  /// 获取占位符同义词
  static List<String> _getPlaceholderSynonyms(String content) {
    final synonyms = <String, List<String>>{
      'someone': ['somebody'],
      'somebody': ['someone'],
      'something': <String>[],
      'somewhere': <String>[],
      'anyone': ['anybody'],
      'anybody': ['anyone'],
      'anything': <String>[],
      'anywhere': <String>[],
    };
    return synonyms[content.toLowerCase()] ?? <String>[];
  }

  /// 获取介词替代选项
  static List<String> _getPrepositionAlternatives(String preposition) {
    final alternatives = {
      'in': ['on', 'at'],
      'on': ['in', 'at'],
      'at': ['in', 'on'],
      'of': ['from', 'about'],
      'to': ['for', 'with'],
      'for': ['to', 'with'],
      'with': ['by', 'through'],
      'by': ['with', 'through'],
    };
    return alternatives[preposition.toLowerCase()] ?? [];
  }

  /// 提取非特殊标记的常规文本词语
  /// 返回除了占位符、介词、关键词以外的普通单词
  static List<String> _extractNonSpecialWords(ContextInfo contextInfo, String template) {
    // 获取所有特殊内容
    final specialContents = <String>{};
    
    // 添加占位符内容
    for (final placeholder in contextInfo.placeholders) {
      specialContents.add(placeholder.content);
    }
    
    // 添加介词内容
    for (final preposition in contextInfo.prepositions) {
      specialContents.add(preposition.content);
    }
    
    
    // 分割template为单词
    final words = template.split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) => word.replaceAll(RegExp(r'[^\w]'), '')) // 移除标点符号
        .where((word) => word.isNotEmpty)
        .toList();
    
    // 过滤出非特殊内容的词语
    final nonSpecialWords = <String>[];
    for (final word in words) {
      if (!specialContents.contains(word.toLowerCase()) && 
          word.length > 1) { // 过滤单字符词语
        nonSpecialWords.add(word);
      }
    }
    
    return nonSpecialWords;
  }
}

/// 解析结果
class ParseResult {
  final ContextInfo? contextInfo;
  final String displayText;
  final bool hasContext;

  ParseResult({
    required this.contextInfo,
    required this.displayText,
    required this.hasContext,
  });
}

/// 填空题验证结果
class QuizValidationResult {
  final bool isCorrect;
  final int correctCount;
  final int totalCount;
  final List<int> incorrectBlanks;
  final String feedback;

  QuizValidationResult({
    required this.isCorrect,
    required this.correctCount,
    required this.totalCount,
    required this.incorrectBlanks,
    required this.feedback,
  });
}