import 'word.dart';
import 'meaning.dart';

/// 词语-意项配对类，用于界面显示和测试
class WordMeaningPair {
  final Word word;
  final Meaning meaning;

  WordMeaningPair({
    required this.word,
    required this.meaning,
  });

  /// 为了向后兼容，提供类似WordItem的属性
  int? get id => null; // 配对本身没有ID
  String get wordText => word.text;
  String get meaningText => meaning.text;
  DateTime get createdAt => word.createdAt.isAfter(meaning.createdAt) 
      ? word.createdAt 
      : meaning.createdAt;
  DateTime get updatedAt => word.updatedAt.isAfter(meaning.updatedAt)
      ? word.updatedAt
      : meaning.updatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WordMeaningPair &&
          runtimeType == other.runtimeType &&
          word == other.word &&
          meaning == other.meaning;

  @override
  int get hashCode => word.hashCode ^ meaning.hashCode;
}