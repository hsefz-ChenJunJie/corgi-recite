import '../models/word.dart';
import '../models/meaning.dart';
import '../models/word_meaning_pair.dart';
import '../models/word_item.dart';
import '../database/database_helper.dart';

/// 测试服务类，处理多对多关系的智能抽查逻辑
class QuizService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// 获取意项到词语的测试项目（一个意项的所有词语在同一页）
  Future<List<QuizItem>> getMeaningToWordsQuizItems(int count) async {
    final meanings = await _dbHelper.getAllMeanings();
    if (meanings.isEmpty) return [];

    meanings.shuffle();
    final selectedMeanings = meanings.take(count).toList();
    
    List<QuizItem> quizItems = [];
    for (final meaning in selectedMeanings) {
      final relatedWords = await _dbHelper.getWordsByMeaningId(meaning.id!);
      if (relatedWords.isNotEmpty) {
        quizItems.add(QuizItem(
          meaning: meaning,
          requiredWords: relatedWords,
          type: QuizItemType.meaningToWords,
        ));
      }
    }
    return quizItems;
  }

  /// 获取词语到意项的测试项目（一个词语的所有意项在同一页）
  Future<List<QuizItem>> getWordToMeaningsQuizItems(int count) async {
    final words = await _dbHelper.getAllWords();
    if (words.isEmpty) return [];

    words.shuffle();
    final selectedWords = words.take(count).toList();
    
    List<QuizItem> quizItems = [];
    for (final word in selectedWords) {
      final relatedMeanings = await _dbHelper.getMeaningsByWordId(word.id!);
      if (relatedMeanings.isNotEmpty) {
        quizItems.add(QuizItem(
          word: word,
          requiredMeanings: relatedMeanings,
          type: QuizItemType.wordToMeanings,
        ));
      }
    }
    return quizItems;
  }

  /// 根据词语列表获取传统的词语->意项测试项目  
  Future<List<QuizItem>> getTraditionalQuizItems(List<WordMeaningPair> pairs) async {
    return pairs.map((pair) => QuizItem(
      meaning: pair.meaning,
      requiredWords: [pair.word],
      type: QuizItemType.wordToMeaning,
    )).toList();
  }

  /// 获取双向测试项目（新添加词语后的标准流程）
  /// 第一阶段：词语 -> 意项，第二阶段：意项 -> 词语
  Future<List<QuizItem>> getBidirectionalQuizItems(List<WordItem> wordItems) async {
    final List<QuizItem> quizItems = [];
    
    // 第一阶段：词语到意项（按词语分组）
    final Map<String, List<String>> wordToMeanings = {};
    for (final item in wordItems) {
      if (wordToMeanings.containsKey(item.word)) {
        if (!wordToMeanings[item.word]!.contains(item.meaning)) {
          wordToMeanings[item.word]!.add(item.meaning);
        }
      } else {
        wordToMeanings[item.word] = [item.meaning];
      }
    }

    // 添加词语到意项的测试项目
    for (final entry in wordToMeanings.entries) {
      final meanings = entry.value.map((m) => Meaning(
        text: m,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      )).toList();
      
      quizItems.add(QuizItem(
        word: Word(
          text: entry.key,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        requiredMeanings: meanings,
        type: QuizItemType.wordToMeanings,
      ));
    }

    // 第二阶段：意项到词语（按意项分组）
    final Map<String, List<String>> meaningToWords = {};
    for (final item in wordItems) {
      if (meaningToWords.containsKey(item.meaning)) {
        if (!meaningToWords[item.meaning]!.contains(item.word)) {
          meaningToWords[item.meaning]!.add(item.word);
        }
      } else {
        meaningToWords[item.meaning] = [item.word];
      }
    }

    // 添加意项到词语的测试项目
    for (final entry in meaningToWords.entries) {
      final words = entry.value.map((w) => Word(
        text: w,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      )).toList();
      
      quizItems.add(QuizItem(
        meaning: Meaning(
          text: entry.key,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        requiredWords: words,
        type: QuizItemType.meaningToWords,
      ));
    }

    return quizItems;
  }

  /// 验证答案
  bool validateAnswer(QuizItem item, List<String> userAnswers) {
    // 移除空白和转换为小写进行比较
    final normalizedAnswers = userAnswers
        .map((answer) => answer.trim().toLowerCase())
        .where((answer) => answer.isNotEmpty)
        .toList();
    
    List<String> requiredTexts;
    
    if (item.type == QuizItemType.meaningToWords) {
      requiredTexts = item.requiredWords
          .map((word) => word.text.trim().toLowerCase())
          .toList();
    } else {
      requiredTexts = item.requiredMeanings
          .map((meaning) => meaning.text.trim().toLowerCase())
          .toList();
    }

    if (normalizedAnswers.length != requiredTexts.length) {
      return false;
    }

    // 检查所有必需的内容是否都被正确输入
    for (final required in requiredTexts) {
      if (!normalizedAnswers.contains(required)) {
        return false;
      }
    }

    return true;
  }
}

/// 测试项目类
class QuizItem {
  final Meaning? meaning;
  final Word? word;
  final List<Word> requiredWords;
  final List<Meaning> requiredMeanings;
  final QuizItemType type;

  QuizItem({
    this.meaning,
    this.word,
    this.requiredWords = const [],
    this.requiredMeanings = const [],
    required this.type,
  });

  /// 获取显示文本（根据测试类型）
  String get displayText {
    switch (type) {
      case QuizItemType.meaningToWords:
        return meaning!.text;
      case QuizItemType.wordToMeanings:
        return word!.text;
      case QuizItemType.wordToMeaning:
        return word!.text;
    }
  }

  /// 获取预期答案文本
  String get expectedAnswerText {
    switch (type) {
      case QuizItemType.meaningToWords:
        return requiredWords.map((w) => w.text).join('、');
      case QuizItemType.wordToMeanings:
        return requiredMeanings.map((m) => m.text).join('、');
      case QuizItemType.wordToMeaning:
        return meaning!.text;
    }
  }

  /// 获取问题提示
  String get questionHint {
    switch (type) {
      case QuizItemType.meaningToWords:
        if (requiredWords.length == 1) {
          return '请输入对应的词语：';
        } else {
          return '请输入所有对应的词语（共${requiredWords.length}个）：';
        }
      case QuizItemType.wordToMeanings:
        if (requiredMeanings.length == 1) {
          return '请输入词语的意思：';
        } else {
          return '请输入所有意思（共${requiredMeanings.length}个）：';
        }
      case QuizItemType.wordToMeaning:
        return '请输入词语的意思：';
    }
  }

  /// 是否需要多个输入框
  bool get needsMultipleInputs {
    switch (type) {
      case QuizItemType.meaningToWords:
        return requiredWords.length > 1;
      case QuizItemType.wordToMeanings:
        return requiredMeanings.length > 1;
      case QuizItemType.wordToMeaning:
        return false;
    }
  }

  /// 获取输入框数量
  int get inputCount {
    switch (type) {
      case QuizItemType.meaningToWords:
        return requiredWords.length;
      case QuizItemType.wordToMeanings:
        return requiredMeanings.length;
      case QuizItemType.wordToMeaning:
        return 1;
    }
  }
}

enum QuizItemType {
  meaningToWords, // 意项 -> 词语（一个或多个）
  wordToMeanings, // 词语 -> 意项（一个或多个）
  wordToMeaning,  // 词语 -> 意项（传统模式）
}