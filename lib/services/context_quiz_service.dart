import '../models/context_info.dart';
import '../models/word_meaning_pair.dart';
import '../database/database_helper.dart';
import 'context_parser.dart';

/// 上下文感知智能填空题服务
class ContextQuizService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// 为词语-意项对生成智能测试项（双向测试）
  Future<List<SmartQuizItem>> generateSmartQuizItems(List<WordMeaningPair> pairs) async {
    final quizItems = <SmartQuizItem>[];

    // 第一阶段：词语→意项测试（按词语分组）
    final wordToMeaningsGroups = await _groupPairsByWord(pairs);
    for (final group in wordToMeaningsGroups) {
      quizItems.add(group);
    }

    // 第二阶段：意项→词语测试（按意项分组）
    final meaningToWordsGroups = await _groupPairsByMeaning(pairs);
    for (final group in meaningToWordsGroups) {
      quizItems.add(group);
    }

    return quizItems;
  }

  /// 为随机抽查生成单向测试项（只生成意项→词语）
  Future<List<SmartQuizItem>> generateRandomQuizItems(List<WordMeaningPair> pairs) async {
    // 按意项分组，实现一对多智能测试
    return await _groupPairsByMeaning(pairs);
  }

  /// 按词语分组生成词语→意项测试（一个词语对应多个意项的同页测试）
  Future<List<SmartQuizItem>> _groupPairsByWord(List<WordMeaningPair> pairs) async {
    final Map<String, List<WordMeaningPair>> wordGroups = {};
    
    // 按词语文本分组
    for (final pair in pairs) {
      final wordText = pair.word.text;
      if (wordGroups.containsKey(wordText)) {
        wordGroups[wordText]!.add(pair);
      } else {
        wordGroups[wordText] = [pair];
      }
    }

    final List<SmartQuizItem> groupedItems = [];
    for (final entry in wordGroups.entries) {
      final wordText = entry.key;
      final groupPairs = entry.value;
      
      // 使用第一个pair的词语信息作为代表
      final representativePair = groupPairs.first;
      final wordContext = representativePair.word.id != null 
        ? await _dbHelper.getContextInfoByWordId(representativePair.word.id!) 
        : null;

      // 收集所有意项文本
      final meanings = groupPairs.map((p) => p.meaning.text).toList();
      
      // 生成词语→意项的分组测试项
      groupedItems.add(_generateGroupQuizItem(
        question: wordText,
        answers: meanings,
        context: wordContext,
        direction: QuizDirection.wordToMeaning,
        pairs: groupPairs,
      ));
    }

    return groupedItems;
  }

  /// 按意项分组生成意项→词语测试（一个意项对应多个词语的同页测试）
  Future<List<SmartQuizItem>> _groupPairsByMeaning(List<WordMeaningPair> pairs) async {
    final Map<String, List<WordMeaningPair>> meaningGroups = {};
    
    // 按意项文本分组
    for (final pair in pairs) {
      final meaningText = pair.meaning.text;
      if (meaningGroups.containsKey(meaningText)) {
        meaningGroups[meaningText]!.add(pair);
      } else {
        meaningGroups[meaningText] = [pair];
      }
    }

    final List<SmartQuizItem> groupedItems = [];
    for (final entry in meaningGroups.entries) {
      final meaningText = entry.key;
      final groupPairs = entry.value;
      
      // 收集所有词语文本和上下文信息
      final words = <String>[];
      final contexts = <ContextInfo?>[];
      
      for (final pair in groupPairs) {
        words.add(pair.word.text);
        final wordContext = pair.word.id != null 
          ? await _dbHelper.getContextInfoByWordId(pair.word.id!) 
          : null;
        contexts.add(wordContext);
      }
      
      // 生成意项→词语的分组测试项（支持多个特殊信息）
      groupedItems.add(await _generateMultiContextQuizItem(
        question: meaningText,
        answers: words,
        contexts: contexts,
        direction: QuizDirection.meaningToWord,
        pairs: groupPairs,
      ));
    }

    return groupedItems;
  }

  /// 生成分组智能测试项（支持一对多）
  SmartQuizItem _generateGroupQuizItem({
    required String question,
    required List<String> answers,
    required ContextInfo? context,
    required QuizDirection direction,
    required List<WordMeaningPair> pairs,
  }) {
    // 根据方向和上下文信息调整question和answer的显示
    String displayQuestion = question;
    List<String> displayAnswers = List.from(answers);
    
    // 处理词性显示：根据用户要求，词性在任何测试中都应显示
    if (context != null && context.partOfSpeech != null) {
      if (direction == QuizDirection.wordToMeaning) {
        // 词语→意项：在问题中显示词性
        displayQuestion = '$question (${context.partOfSpeech})';
      } else {
        // 意项→词语：在问题中也显示词性，确保用户能看到词性信息
        displayQuestion = '$question (词性: ${context.partOfSpeech})';
        // 为所有答案添加词性
        displayAnswers = answers.map((answer) => '$answer (${context.partOfSpeech})').toList();
      }
    }
    
    // 根据用户要求处理填空策略
    if (direction == QuizDirection.wordToMeaning) {
      // 词语→意项：显示所有信息，不进行填空，使用传统问答
      return SmartQuizItem(
        id: _generateGroupId(pairs, direction),
        question: displayQuestion,
        expectedAnswers: displayAnswers,
        quizType: QuizType.traditional,
        direction: direction,
        pairs: pairs,
        context: context,
      );
    } else {
      // 意项→词语：根据上下文信息决定是否进行填空
      if (context != null && (context.placeholders.isNotEmpty || context.prepositions.isNotEmpty)) {
        // 有上下文信息（不定代词或介词），生成填空题
        // 对于分组填空，我们使用第一个答案生成填空模板
        final blankQuiz = ContextParser.generateBlankQuiz(context, direction);
        return SmartQuizItem(
          id: _generateGroupId(pairs, direction),
          question: displayQuestion,
          expectedAnswers: displayAnswers,
          quizType: QuizType.blank,
          blankQuiz: blankQuiz,
          direction: direction,
          pairs: pairs,
          context: context,
        );
      } else {
        // 无复杂上下文信息（只有词性或无上下文），使用传统问答
        return SmartQuizItem(
          id: _generateGroupId(pairs, direction),
          question: displayQuestion,
          expectedAnswers: displayAnswers,
          quizType: QuizType.traditional,
          direction: direction,
          pairs: pairs,
          context: context,
        );
      }
    }
  }

  /// 生成分组ID
  String _generateGroupId(List<WordMeaningPair> pairs, QuizDirection direction) {
    final pairIds = pairs.map((p) => '${p.word.id ?? p.word.text.hashCode}_${p.meaning.id ?? p.meaning.text.hashCode}').join('_');
    return '${pairIds}_${direction.name}';
  }

  /// 生成支持多个特殊信息的智能测试项
  Future<SmartQuizItem> _generateMultiContextQuizItem({
    required String question,
    required List<String> answers,
    required List<ContextInfo?> contexts,
    required QuizDirection direction,
    required List<WordMeaningPair> pairs,
  }) async {
    String displayQuestion = question;
    List<String> displayAnswers = List.from(answers);
    
    // 检查是否有任何词语包含特殊信息（介词、不定代词）
    final hasBlankContexts = contexts.any((context) => 
      context != null && (context.placeholders.isNotEmpty || context.prepositions.isNotEmpty));
    
    // 检查是否有词性信息
    final hasPartOfSpeech = contexts.any((context) => 
      context != null && context.partOfSpeech != null);
    
    // 处理词性显示
    if (hasPartOfSpeech && direction == QuizDirection.meaningToWord) {
      // 在问题中显示所有词性信息（去重）
      final partOfSpeeches = contexts
          .where((context) => context?.partOfSpeech != null)
          .map((context) => context!.partOfSpeech!)
          .toSet()
          .join('、');
      if (partOfSpeeches.isNotEmpty) {
        displayQuestion = '$question (词性: $partOfSpeeches)';
      }
    }
    
    if (direction == QuizDirection.wordToMeaning) {
      // 词语→意项：显示所有信息，不进行填空，使用传统问答
      return SmartQuizItem(
        id: _generateGroupId(pairs, direction),
        question: displayQuestion,
        expectedAnswers: displayAnswers,
        quizType: QuizType.traditional,
        direction: direction,
        pairs: pairs,
        contexts: contexts,
      );
    } else {
      // 意项→词语：检查是否需要填空
      if (hasBlankContexts) {
        // 有特殊信息，生成多个填空项
        final List<BlankQuizItem> blankQuizItems = [];
        final List<String> finalAnswers = [];
        
        for (int i = 0; i < answers.length; i++) {
          final context = contexts[i];
          final answer = answers[i];
          
          if (context != null && (context.placeholders.isNotEmpty || context.prepositions.isNotEmpty)) {
            // 有特殊信息，生成填空项
            final blankQuiz = ContextParser.generateBlankQuiz(context, direction);
            blankQuizItems.add(blankQuiz);
            // 对于填空项，期望答案需要包含词性信息（如果有）
            if (context.partOfSpeech != null) {
              finalAnswers.add('$answer (${context.partOfSpeech})');
            } else {
              finalAnswers.add(answer);
            }
          } else {
            // 无特殊信息，但需要用户输入，为它们生成一个简单的填空项
            // 创建一个简单的填空模板：显示"第X个词语: ___"
            final wordIndex = i + 1;
            final emptyContext = ContextInfo(
              id: null,
              originalText: answer,
              displayText: answer,
              placeholders: [],
              prepositions: [],
              partOfSpeech: context?.partOfSpeech,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            final blankQuiz = BlankQuizItem(
              template: '第${wordIndex}个词语: ___',
              originalText: answer,
              contextInfo: emptyContext,
              blanks: [
                BlankAnswer(
                  index: 0,
                  type: BlankType.regular,
                  correctAnswer: answer,
                  acceptableAnswers: [answer],
                  hint: '请输入词语',
                )
              ],
            );
            blankQuizItems.add(blankQuiz);
            
            // 添加到期望答案中
            if (context?.partOfSpeech != null) {
              finalAnswers.add('$answer (${context!.partOfSpeech})');
            } else {
              finalAnswers.add(answer);
            }
          }
        }
        
        return SmartQuizItem(
          id: _generateGroupId(pairs, direction),
          question: displayQuestion,
          expectedAnswers: finalAnswers,
          quizType: QuizType.blank,
          blankQuizItems: blankQuizItems.isNotEmpty ? blankQuizItems : null,
          direction: direction,
          pairs: pairs,
          contexts: contexts,
        );
      } else {
        // 无特殊信息（只有词性或无上下文），使用传统问答
        // 为有词性的答案添加词性标记
        final List<String> finalAnswers = [];
        for (int i = 0; i < answers.length; i++) {
          final context = contexts[i];
          final answer = answers[i];
          if (context?.partOfSpeech != null) {
            finalAnswers.add('$answer (${context!.partOfSpeech})');
          } else {
            finalAnswers.add(answer);
          }
        }
        
        return SmartQuizItem(
          id: _generateGroupId(pairs, direction),
          question: displayQuestion,
          expectedAnswers: finalAnswers,
          quizType: QuizType.traditional,
          direction: direction,
          pairs: pairs,
          contexts: contexts,
        );
      }
    }
  }


  /// 验证答案
  QuizResult validateAnswer(SmartQuizItem quizItem, dynamic userAnswer) {
    switch (quizItem.quizType) {
      case QuizType.blank:
        if (userAnswer is List<String>) {
          // 检查是否为多个填空项（多特殊信息）
          if (quizItem.blankQuizItems != null && quizItem.blankQuizItems!.isNotEmpty) {
            return _validateMultiBlankAnswers(quizItem, userAnswer);
          } else if (quizItem.blankQuiz != null) {
            // 单个填空项（向后兼容）
            final validationResult = ContextParser.validateBlankAnswers(
              quizItem.blankQuiz!,
              userAnswer,
            );
            return QuizResult(
              isCorrect: validationResult.isCorrect,
              score: validationResult.correctCount / validationResult.totalCount,
              feedback: validationResult.feedback,
              correctAnswer: quizItem.expectedAnswer,
              userAnswer: userAnswer.join(', '),
            );
          } else {
            return QuizResult(
              isCorrect: false,
              score: 0.0,
              feedback: '填空题数据不完整',
              correctAnswer: quizItem.expectedAnswer,
              userAnswer: userAnswer.join(', '),
            );
          }
        } else {
          return QuizResult(
            isCorrect: false,
            score: 0.0,
            feedback: '填空题需要提供答案列表',
            correctAnswer: quizItem.expectedAnswer,
            userAnswer: userAnswer.toString(),
          );
        }
      
      case QuizType.traditional:
        // 支持单个答案或多个答案
        if (userAnswer is String) {
          // 单个答案模式
          if (quizItem.expectedAnswers.length == 1) {
            final isCorrect = _compareAnswers(userAnswer, quizItem.expectedAnswers.first);
            return QuizResult(
              isCorrect: isCorrect,
              score: isCorrect ? 1.0 : 0.0,
              feedback: isCorrect ? '正确！' : '错误，正确答案是：${quizItem.expectedAnswer}',
              correctAnswer: quizItem.expectedAnswer,
              userAnswer: userAnswer,
            );
          } else {
            return QuizResult(
              isCorrect: false,
              score: 0.0,
              feedback: '此题有多个答案，请分别输入所有答案',
              correctAnswer: quizItem.expectedAnswer,
              userAnswer: userAnswer,
            );
          }
        } else if (userAnswer is List<String>) {
          // 多个答案模式
          return _validateMultipleAnswers(quizItem, userAnswer);
        } else {
          return QuizResult(
            isCorrect: false,
            score: 0.0,
            feedback: '传统题目需要提供文本答案',
            correctAnswer: quizItem.expectedAnswer,
            userAnswer: userAnswer.toString(),
          );
        }
    }
  }

  /// 验证多个填空项的答案（多特殊信息）
  QuizResult _validateMultiBlankAnswers(SmartQuizItem quizItem, List<String> userAnswers) {
    final blankQuizItems = quizItem.blankQuizItems!;
    int totalBlanks = 0;
    int correctBlanks = 0;
    List<String> feedbackMessages = [];
    
    // 计算总填空数量
    for (final blankQuiz in blankQuizItems) {
      totalBlanks += blankQuiz.blanks.length;
    }
    
    // 检查用户答案数量
    if (userAnswers.length != totalBlanks) {
      return QuizResult(
        isCorrect: false,
        score: 0.0,
        feedback: '答案数量不正确。需要${totalBlanks}个答案，您输入了${userAnswers.length}个。',
        correctAnswer: quizItem.expectedAnswer,
        userAnswer: userAnswers.join('、'),
      );
    }
    
    // 逐个验证每个填空项
    int answerIndex = 0;
    for (int i = 0; i < blankQuizItems.length; i++) {
      final blankQuiz = blankQuizItems[i];
      final blanksCount = blankQuiz.blanks.length;
      
      // 提取当前填空项对应的用户答案
      final currentAnswers = userAnswers.sublist(answerIndex, answerIndex + blanksCount);
      
      // 验证当前填空项
      final validationResult = ContextParser.validateBlankAnswers(blankQuiz, currentAnswers);
      correctBlanks += validationResult.correctCount;
      
      if (validationResult.isCorrect) {
        feedbackMessages.add('第${i + 1}个词语：正确');
      } else {
        feedbackMessages.add('第${i + 1}个词语：${validationResult.feedback}');
      }
      
      answerIndex += blanksCount;
    }
    
    final isCorrect = correctBlanks == totalBlanks;
    final score = correctBlanks / totalBlanks;
    
    // 如果不是完全正确，还需要检查传统答案部分
    if (!isCorrect && quizItem.expectedAnswers.length > blankQuizItems.length) {
      // 有混合的传统答案和填空答案
      feedbackMessages.add('部分词语需要直接输入完整答案');
    }
    
    return QuizResult(
      isCorrect: isCorrect,
      score: score,
      feedback: isCorrect ? '全部正确！' : feedbackMessages.join('；'),
      correctAnswer: quizItem.expectedAnswer,
      userAnswer: userAnswers.join('、'),
    );
  }

  /// 验证多个答案
  QuizResult _validateMultipleAnswers(SmartQuizItem quizItem, List<String> userAnswers) {
    final normalizedUserAnswers = userAnswers
        .map((answer) => answer.trim().toLowerCase())
        .where((answer) => answer.isNotEmpty)
        .toList();
    
    final normalizedExpectedAnswers = quizItem.expectedAnswers
        .map((answer) => answer.trim().toLowerCase())
        .toList();

    // 检查数量是否匹配
    if (normalizedUserAnswers.length != normalizedExpectedAnswers.length) {
      return QuizResult(
        isCorrect: false,
        score: 0.0,
        feedback: '答案数量不正确。需要${normalizedExpectedAnswers.length}个答案，您输入了${normalizedUserAnswers.length}个。正确答案：${quizItem.expectedAnswer}',
        correctAnswer: quizItem.expectedAnswer,
        userAnswer: userAnswers.join('、'),
      );
    }

    // 检查所有答案是否都正确
    int correctCount = 0;
    for (final expected in normalizedExpectedAnswers) {
      if (normalizedUserAnswers.contains(expected)) {
        correctCount++;
      }
    }

    final isCorrect = correctCount == normalizedExpectedAnswers.length;
    final score = correctCount / normalizedExpectedAnswers.length;
    
    return QuizResult(
      isCorrect: isCorrect,
      score: score,
      feedback: isCorrect 
        ? '正确！' 
        : '部分正确（$correctCount/${normalizedExpectedAnswers.length}）。正确答案：${quizItem.expectedAnswer}',
      correctAnswer: quizItem.expectedAnswer,
      userAnswer: userAnswers.join('、'),
    );
  }

  /// 比较答案
  bool _compareAnswers(String userAnswer, String correctAnswer) {
    final userClean = userAnswer.trim().toLowerCase();
    final correctClean = correctAnswer.trim().toLowerCase();
    
    // 直接匹配
    if (userClean == correctClean) return true;
    
    // 如果正确答案包含词性，也尝试匹配不包含词性的版本
    final correctWithoutPos = correctClean.replaceAll(RegExp(r'\s*\([^)]*\)'), '');
    if (userClean == correctWithoutPos) return true;
    
    return false;
  }

  /// 获取测试统计信息
  QuizStatistics calculateStatistics(List<QuizResult> results) {
    if (results.isEmpty) {
      return QuizStatistics(
        totalQuestions: 0,
        correctAnswers: 0,
        averageScore: 0.0,
        accuracy: 0.0,
        blankQuizCount: 0,
        traditionalQuizCount: 0,
      );
    }

    final totalQuestions = results.length;
    final correctAnswers = results.where((r) => r.isCorrect).length;
    final totalScore = results.map((r) => r.score).reduce((a, b) => a + b);
    final averageScore = totalScore / totalQuestions;
    final accuracy = correctAnswers / totalQuestions;

    return QuizStatistics(
      totalQuestions: totalQuestions,
      correctAnswers: correctAnswers,
      averageScore: averageScore,
      accuracy: accuracy,
      blankQuizCount: 0, // 这里可以根据需要统计
      traditionalQuizCount: 0, // 这里可以根据需要统计
    );
  }
}

/// 智能测试项
class SmartQuizItem {
  final String id;
  final String question;
  final String expectedAnswer; // 保留单个答案，向后兼容
  final List<String> expectedAnswers; // 新增多个答案支持
  final QuizType quizType;
  final BlankQuizItem? blankQuiz; // 单个填空项，向后兼容
  final List<BlankQuizItem>? blankQuizItems; // 多个填空项，支持多特殊信息
  final QuizDirection direction;
  final WordMeaningPair? pair; // 单个pair，可选
  final List<WordMeaningPair> pairs; // 多个pairs，支持分组
  final ContextInfo? context; // 单个上下文，向后兼容
  final List<ContextInfo?> contexts; // 多个上下文，支持多特殊信息

  SmartQuizItem({
    required this.id,
    required this.question,
    String? expectedAnswer,
    List<String>? expectedAnswers,
    required this.quizType,
    this.blankQuiz,
    this.blankQuizItems,
    required this.direction,
    this.pair,
    List<WordMeaningPair>? pairs,
    this.context,
    List<ContextInfo?>? contexts,
  }) : 
    expectedAnswer = expectedAnswer ?? (expectedAnswers?.join('、') ?? ''),
    expectedAnswers = expectedAnswers ?? (expectedAnswer != null ? [expectedAnswer] : []),
    pairs = pairs ?? (pair != null ? [pair] : []),
    contexts = contexts ?? (context != null ? [context] : []);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'question': question,
      'expected_answer': expectedAnswer,
      'expected_answers': expectedAnswers,
      'quiz_type': quizType.name,
      'blank_quiz': blankQuiz?.toMap(),
      'blank_quiz_items': blankQuizItems?.map((item) => item.toMap()).toList(),
      'direction': direction.name,
      'pair': pair?.toMap(),
      'pairs': pairs.map((p) => p.toMap()).toList(),
      'context': context?.toMap(),
      'contexts': contexts.map((c) => c?.toMap()).toList(),
    };
  }

  factory SmartQuizItem.fromMap(Map<String, dynamic> map) {
    return SmartQuizItem(
      id: map['id'],
      question: map['question'],
      expectedAnswer: map['expected_answer'],
      expectedAnswers: map['expected_answers'] != null 
        ? List<String>.from(map['expected_answers'])
        : null,
      quizType: QuizType.values.byName(map['quiz_type']),
      blankQuiz: map['blank_quiz'] != null ? BlankQuizItem.fromMap(map['blank_quiz']) : null,
      blankQuizItems: map['blank_quiz_items'] != null 
        ? (map['blank_quiz_items'] as List).map((item) => BlankQuizItem.fromMap(item)).toList()
        : null,
      direction: QuizDirection.values.byName(map['direction']),
      pair: map['pair'] != null ? WordMeaningPair.fromMap(map['pair']) : null,
      pairs: map['pairs'] != null 
        ? (map['pairs'] as List).map((p) => WordMeaningPair.fromMap(p)).toList()
        : null,
      context: map['context'] != null ? ContextInfo.fromMap(map['context']) : null,
      contexts: map['contexts'] != null 
        ? (map['contexts'] as List).map((c) => c != null ? ContextInfo.fromMap(c) : null).toList()
        : null,
    );
  }
}

/// 测试类型
enum QuizType {
  traditional,  // 传统问答
  blank,        // 填空题
}


/// 测试结果
class QuizResult {
  final bool isCorrect;
  final double score;
  final String feedback;
  final String correctAnswer;
  final String userAnswer;

  QuizResult({
    required this.isCorrect,
    required this.score,
    required this.feedback,
    required this.correctAnswer,
    required this.userAnswer,
  });

  Map<String, dynamic> toMap() {
    return {
      'is_correct': isCorrect,
      'score': score,
      'feedback': feedback,
      'correct_answer': correctAnswer,
      'user_answer': userAnswer,
    };
  }

  factory QuizResult.fromMap(Map<String, dynamic> map) {
    return QuizResult(
      isCorrect: map['is_correct'],
      score: map['score'],
      feedback: map['feedback'],
      correctAnswer: map['correct_answer'],
      userAnswer: map['user_answer'],
    );
  }
}

/// 测试统计信息
class QuizStatistics {
  final int totalQuestions;
  final int correctAnswers;
  final double averageScore;
  final double accuracy;
  final int blankQuizCount;
  final int traditionalQuizCount;

  QuizStatistics({
    required this.totalQuestions,
    required this.correctAnswers,
    required this.averageScore,
    required this.accuracy,
    required this.blankQuizCount,
    required this.traditionalQuizCount,
  });

  Map<String, dynamic> toMap() {
    return {
      'total_questions': totalQuestions,
      'correct_answers': correctAnswers,
      'average_score': averageScore,
      'accuracy': accuracy,
      'blank_quiz_count': blankQuizCount,
      'traditional_quiz_count': traditionalQuizCount,
    };
  }

  factory QuizStatistics.fromMap(Map<String, dynamic> map) {
    return QuizStatistics(
      totalQuestions: map['total_questions'],
      correctAnswers: map['correct_answers'],
      averageScore: map['average_score'],
      accuracy: map['accuracy'],
      blankQuizCount: map['blank_quiz_count'],
      traditionalQuizCount: map['traditional_quiz_count'],
    );
  }
}