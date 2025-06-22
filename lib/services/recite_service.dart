import '../models/word_item.dart';
import '../database/database_helper.dart';

/// 背诵服务类，处理多对多关系的背诵逻辑
class ReciteService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// 根据WordItem列表获取智能背诵项目
  /// 一个词语的多个意项会合并在同一页显示
  Future<List<ReciteItem>> getReciteItems(List<WordItem> wordItems) async {
    final Map<String, List<String>> wordToMeanings = {};
    
    // 按词语分组意项
    for (final item in wordItems) {
      if (wordToMeanings.containsKey(item.word)) {
        if (!wordToMeanings[item.word]!.contains(item.meaning)) {
          wordToMeanings[item.word]!.add(item.meaning);
        }
      } else {
        wordToMeanings[item.word] = [item.meaning];
      }
    }

    // 创建背诵项目
    final List<ReciteItem> reciteItems = [];
    for (final entry in wordToMeanings.entries) {
      reciteItems.add(ReciteItem(
        word: entry.key,
        meanings: entry.value,
        createdAt: wordItems.firstWhere((item) => item.word == entry.key).createdAt,
      ));
    }

    return reciteItems;
  }

  /// 从多对多数据库获取背诵项目
  Future<List<ReciteItem>> getReciteItemsFromDatabase(List<WordItem> wordItems) async {
    final Set<String> wordTexts = wordItems.map((item) => item.word).toSet();
    final List<ReciteItem> reciteItems = [];

    for (final wordText in wordTexts) {
      final word = await _dbHelper.getWordByText(wordText);
      if (word != null) {
        final meanings = await _dbHelper.getMeaningsByWordId(word.id!);
        if (meanings.isNotEmpty) {
          reciteItems.add(ReciteItem(
            word: wordText,
            meanings: meanings.map((m) => m.text).toList(),
            createdAt: word.createdAt,
          ));
        }
      }
    }

    return reciteItems;
  }
}

/// 背诵项目类
class ReciteItem {
  final String word;
  final List<String> meanings;
  final DateTime createdAt;

  ReciteItem({
    required this.word,
    required this.meanings,
    required this.createdAt,
  });

  /// 获取意项显示文本
  String get meaningsText => meanings.join('\n');

  /// 是否有多个意项
  bool get hasMultipleMeanings => meanings.length > 1;

  /// 意项数量
  int get meaningCount => meanings.length;
}