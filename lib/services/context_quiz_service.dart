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

    for (final pair in pairs) {
      // 检查词语是否有上下文信息
      final wordContext = pair.word.id != null 
        ? await _dbHelper.getContextInfoByWordId(pair.word.id!) 
        : null;
      // 检查意项是否有上下文信息
      final meaningContext = pair.meaning.id != null 
        ? await _dbHelper.getContextInfoByMeaningId(pair.meaning.id!) 
        : null;

      // 生成词语→意项测试
      final wordToMeaning = _generateQuizItem(
        question: pair.word.text,
        answer: pair.meaning.text,
        context: wordContext,
        direction: QuizDirection.wordToMeaning,
        pair: pair,
      );
      quizItems.add(wordToMeaning);

      // 生成意项→词语测试
      final meaningToWord = _generateQuizItem(
        question: pair.meaning.text,
        answer: pair.word.text,
        context: meaningContext,
        direction: QuizDirection.meaningToWord,
        pair: pair,
      );
      quizItems.add(meaningToWord);
    }

    return quizItems;
  }

  /// 为随机抽查生成单向测试项（只生成意项→词语）
  Future<List<SmartQuizItem>> generateRandomQuizItems(List<WordMeaningPair> pairs) async {
    final quizItems = <SmartQuizItem>[];

    for (final pair in pairs) {
      // 检查意项是否有上下文信息
      final meaningContext = pair.meaning.id != null 
        ? await _dbHelper.getContextInfoByMeaningId(pair.meaning.id!) 
        : null;

      // 只生成意项→词语测试
      final meaningToWord = _generateQuizItem(
        question: pair.meaning.text,
        answer: pair.word.text,
        context: meaningContext,
        direction: QuizDirection.meaningToWord,
        pair: pair,
      );
      quizItems.add(meaningToWord);
    }

    return quizItems;
  }

  /// 生成单个智能测试项
  SmartQuizItem _generateQuizItem({
    required String question,
    required String answer,
    required ContextInfo? context,
    required QuizDirection direction,
    required WordMeaningPair pair,
  }) {
    // 根据方向和上下文信息调整question和answer的显示
    String displayQuestion = question;
    String displayAnswer = answer;
    
    if (context != null && context.partOfSpeech != null) {
      if (direction == QuizDirection.wordToMeaning) {
        // 词语→意项：在问题中显示词性
        displayQuestion = '$question (${context.partOfSpeech})';
      } else {
        // 意项→词语：在答案中包含词性信息，但问题显示时不包含词性
        displayAnswer = '$answer (${context.partOfSpeech})';
      }
    }
    
    if (context != null && (context.placeholders.isNotEmpty || context.prepositions.isNotEmpty || context.keywords.isNotEmpty)) {
      // 有其他上下文信息（非纯词性），生成填空题
      final blankQuiz = ContextParser.generateBlankQuiz(context, direction);
      return SmartQuizItem(
        id: '${pair.word.id ?? pair.word.text.hashCode}_${pair.meaning.id ?? pair.meaning.text.hashCode}_${direction.name}',
        question: displayQuestion,
        expectedAnswer: displayAnswer,
        quizType: QuizType.blank,
        blankQuiz: blankQuiz,
        direction: direction,
        pair: pair,
        context: context,
      );
    } else {
      // 无复杂上下文信息（只有词性或无上下文），使用传统问答
      return SmartQuizItem(
        id: '${pair.word.id ?? pair.word.text.hashCode}_${pair.meaning.id ?? pair.meaning.text.hashCode}_${direction.name}',
        question: displayQuestion,
        expectedAnswer: displayAnswer,
        quizType: QuizType.traditional,
        direction: direction,
        pair: pair,
      );
    }
  }

  /// 验证答案
  QuizResult validateAnswer(SmartQuizItem quizItem, dynamic userAnswer) {
    switch (quizItem.quizType) {
      case QuizType.blank:
        if (userAnswer is List<String>) {
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
            feedback: '填空题需要提供答案列表',
            correctAnswer: quizItem.expectedAnswer,
            userAnswer: userAnswer.toString(),
          );
        }
      
      case QuizType.traditional:
        if (userAnswer is String) {
          final isCorrect = _compareAnswers(userAnswer, quizItem.expectedAnswer);
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
            feedback: '传统题目需要提供文本答案',
            correctAnswer: quizItem.expectedAnswer,
            userAnswer: userAnswer.toString(),
          );
        }
    }
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
  final String expectedAnswer;
  final QuizType quizType;
  final BlankQuizItem? blankQuiz;
  final QuizDirection direction;
  final WordMeaningPair pair;
  final ContextInfo? context;

  SmartQuizItem({
    required this.id,
    required this.question,
    required this.expectedAnswer,
    required this.quizType,
    this.blankQuiz,
    required this.direction,
    required this.pair,
    this.context,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'question': question,
      'expected_answer': expectedAnswer,
      'quiz_type': quizType.name,
      'blank_quiz': blankQuiz?.toMap(),
      'direction': direction.name,
      'pair': pair.toMap(),
      'context': context?.toMap(),
    };
  }

  factory SmartQuizItem.fromMap(Map<String, dynamic> map) {
    return SmartQuizItem(
      id: map['id'],
      question: map['question'],
      expectedAnswer: map['expected_answer'],
      quizType: QuizType.values.byName(map['quiz_type']),
      blankQuiz: map['blank_quiz'] != null ? BlankQuizItem.fromMap(map['blank_quiz']) : null,
      direction: QuizDirection.values.byName(map['direction']),
      pair: WordMeaningPair.fromMap(map['pair']),
      context: map['context'] != null ? ContextInfo.fromMap(map['context']) : null,
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