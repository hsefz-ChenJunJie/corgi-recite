import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/database_helper.dart';
import '../models/word.dart';
import '../models/meaning.dart';
import '../models/word_meaning.dart';
import '../models/word_meaning_pair.dart';

/// 数据导入导出服务
/// 负责处理词库数据的导入和导出功能
class DataPortService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// 导出数据模型
  static const String exportVersion = '1.0.0';

  /// 导出所有词库数据为JSON格式
  Future<ExportResult> exportData() async {
    try {
      // 获取所有数据
      final words = await _dbHelper.getAllWords();
      final meanings = await _dbHelper.getAllMeanings();
      final wordMeaningPairs = await _dbHelper.getAllWordMeaningPairs();

      // 构建导出数据结构
      final exportData = {
        'version': exportVersion,
        'exportedAt': DateTime.now().toIso8601String(),
        'appName': 'Corgi Recite',
        'totalWords': words.length,
        'totalMeanings': meanings.length,
        'totalRelations': wordMeaningPairs.length,
        'data': {
          'words': words.map((word) => {
            'id': word.id,
            'text': word.text,
            'createdAt': word.createdAt.toIso8601String(),
            'updatedAt': word.updatedAt.toIso8601String(),
          }).toList(),
          'meanings': meanings.map((meaning) => {
            'id': meaning.id,
            'text': meaning.text,
            'createdAt': meaning.createdAt.toIso8601String(),
            'updatedAt': meaning.updatedAt.toIso8601String(),
          }).toList(),
          'relations': wordMeaningPairs.map((pair) => {
            'wordId': pair.word.id,
            'meaningId': pair.meaning.id,
            'wordText': pair.word.text,
            'meaningText': pair.meaning.text,
          }).toList(),
        },
      };

      // 转换为JSON字符串，确保UTF-8编码
      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
      
      // 验证导出数据中的中文字符
      final chineseCount = jsonString.runes.where((rune) => rune >= 0x4E00 && rune <= 0x9FFF).length;
      print('🔍 [EXPORT-DEBUG] 导出数据包含中文字符数量: $chineseCount');
      
      // 生成文件名
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final fileName = 'corgi_recite_backup_$timestamp.json';

      return ExportResult(
        success: true,
        data: jsonString,
        fileName: fileName,
        message: '成功导出 ${words.length} 个词语、${meanings.length} 个意项、${wordMeaningPairs.length} 个关联关系',
      );
    } catch (e) {
      return ExportResult(
        success: false,
        message: '导出失败：$e',
      );
    }
  }

  /// 保存导出数据到文件并分享
  Future<ShareResult> shareExportData() async {
    try {
      final exportResult = await exportData();
      if (!exportResult.success) {
        return ShareResult(
          success: false,
          message: exportResult.message,
        );
      }

      // 获取临时目录
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/${exportResult.fileName}');
      
      // 写入文件，明确指定UTF-8编码
      await file.writeAsString(exportResult.data!, encoding: utf8);
      
      // 分享文件
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '柯基背单词词库备份文件',
      );

      return ShareResult(
        success: true,
        message: '导出成功并已分享',
        filePath: file.path,
      );
    } catch (e) {
      return ShareResult(
        success: false,
        message: '分享失败：$e',
      );
    }
  }

  /// 选择并导入数据文件
  Future<ImportResult> importDataFromFile() async {
    try {
      print('🔍 [DEBUG] 开始文件选择过程...');
      
      // 选择文件 - 针对MacOS优化，尝试多种配置
      print('🔍 [DEBUG] 调用 FilePicker.platform.pickFiles...');
      
      // 方案1: 最简单的配置，只设置基本参数
      var result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true,
      );
      
      print('🔍 [DEBUG] 方案1结果: ${result != null ? "有结果" : "null"}');
      
      // 如果方案1失败，尝试方案2
      if (result == null) {
        print('🔍 [DEBUG] 方案1失败，尝试方案2...');
        result = await FilePicker.platform.pickFiles(
          allowMultiple: false,
          withData: true,
        );
        print('🔍 [DEBUG] 方案2结果: ${result != null ? "有结果" : "null"}');
      }
      
      // 如果方案2也失败，尝试方案3（不设置withData）
      if (result == null) {
        print('🔍 [DEBUG] 方案2失败，尝试方案3...');
        result = await FilePicker.platform.pickFiles();
        print('🔍 [DEBUG] 方案3结果: ${result != null ? "有结果" : "null"}');
      }

      print('🔍 [DEBUG] FilePicker 返回结果: ${result != null ? "有结果" : "null"}');

      if (result == null) {
        print('🔍 [DEBUG] 用户取消了文件选择或选择器返回null');
        return ImportResult(
          success: false,
          message: '已取消文件选择（debug: result为null）',
        );
      }

      print('🔍 [DEBUG] 文件列表长度: ${result.files.length}');
      if (result.files.isEmpty) {
        print('🔍 [DEBUG] 文件列表为空');
        return ImportResult(
          success: false,
          message: '未选择任何文件（debug: files列表为空）',
        );
      }

      final platformFile = result.files.first;
      print('🔍 [DEBUG] 选择的文件: ${platformFile.name}');
      print('🔍 [DEBUG] 文件大小: ${platformFile.size} bytes');
      print('🔍 [DEBUG] 文件路径: ${platformFile.path}');
      print('🔍 [DEBUG] 是否有bytes数据: ${platformFile.bytes != null}');
      
      // 优先使用bytes数据（MacOS更可靠）
      if (platformFile.bytes != null) {
        print('🔍 [DEBUG] 使用bytes数据读取文件...');
        try {
          // 使用utf8.decode而不是String.fromCharCodes来正确处理UTF-8编码
          final jsonString = utf8.decode(platformFile.bytes!);
          print('🔍 [DEBUG] 成功从bytes读取（UTF-8解码），字符串长度: ${jsonString.length}');
          
          // 验证是否包含中文字符
          final chineseCount = jsonString.runes.where((rune) => rune >= 0x4E00 && rune <= 0x9FFF).length;
          print('🔍 [DEBUG] 检测到中文字符数量: $chineseCount');
          
          return await importDataFromJson(jsonString);
        } catch (e) {
          print('🔍 [DEBUG] 从bytes读取失败: $e');
        }
      }
      
      // 检查文件路径
      if (platformFile.path == null || platformFile.path!.isEmpty) {
        print('🔍 [DEBUG] 文件路径为空，且无bytes数据');
        return ImportResult(
          success: false,
          message: '无法读取文件内容（debug: path为空且无bytes数据）',
        );
      }

      print('🔍 [DEBUG] 尝试从路径读取文件: ${platformFile.path}');
      final file = File(platformFile.path!);
      
      // 检查文件是否存在
      final exists = await file.exists();
      print('🔍 [DEBUG] 文件是否存在: $exists');
      if (!exists) {
        return ImportResult(
          success: false,
          message: '选择的文件不存在或无法访问（debug: file.exists()返回false）',
        );
      }

      print('🔍 [DEBUG] 开始读取文件内容...');
      final jsonString = await file.readAsString(encoding: utf8);
      print('🔍 [DEBUG] 成功读取文件（UTF-8编码），内容长度: ${jsonString.length}');
      
      // 验证是否包含中文字符
      final chineseCount = jsonString.runes.where((rune) => rune >= 0x4E00 && rune <= 0x9FFF).length;
      print('🔍 [DEBUG] 检测到中文字符数量: $chineseCount');
      
      return await importDataFromJson(jsonString);
    } catch (e, stackTrace) {
      print('🔍 [DEBUG] 文件选择过程发生异常: $e');
      print('🔍 [DEBUG] 堆栈跟踪: $stackTrace');
      
      // 提供更详细的错误信息
      String errorMessage = '文件选择或读取失败';
      
      if (e.toString().contains('permission')) {
        errorMessage = '没有文件访问权限，请检查应用权限设置';
      } else if (e.toString().contains('not found')) {
        errorMessage = '文件不存在或已被移动';
      } else {
        errorMessage = '文件处理失败（debug: $e）';
      }
      
      return ImportResult(
        success: false,
        message: errorMessage,
      );
    }
  }

  /// 从JSON字符串导入数据
  Future<ImportResult> importDataFromJson(String jsonString) async {
    try {
      // 解析JSON
      final Map<String, dynamic> importData;
      try {
        importData = json.decode(jsonString) as Map<String, dynamic>;
      } catch (e) {
        return ImportResult(
          success: false,
          message: '文件格式错误，请确保是有效的JSON文件',
        );
      }

      // 验证数据格式
      final validationResult = _validateImportData(importData);
      if (!validationResult.success) {
        return validationResult;
      }

      // 解析数据
      final data = importData['data'] as Map<String, dynamic>;
      final wordsData = data['words'] as List<dynamic>;
      final meaningsData = data['meanings'] as List<dynamic>;
      final relationsData = data['relations'] as List<dynamic>;

      // 统计信息
      int newWords = 0;
      int newMeanings = 0;
      int newRelations = 0;
      int skippedWords = 0;
      int skippedMeanings = 0;
      int skippedRelations = 0;

      final now = DateTime.now();

      // 导入词语
      for (final wordData in wordsData) {
        final wordText = wordData['text'] as String;
        final existingWord = await _dbHelper.getWordByText(wordText);
        
        if (existingWord == null) {
          final word = Word(
            text: wordText,
            createdAt: _parseDateTime(wordData['createdAt']) ?? now,
            updatedAt: _parseDateTime(wordData['updatedAt']) ?? now,
          );
          await _dbHelper.insertWord(word);
          newWords++;
        } else {
          skippedWords++;
        }
      }

      // 导入意项
      for (final meaningData in meaningsData) {
        final meaningText = meaningData['text'] as String;
        final existingMeaning = await _dbHelper.getMeaningByText(meaningText);
        
        if (existingMeaning == null) {
          final meaning = Meaning(
            text: meaningText,
            createdAt: _parseDateTime(meaningData['createdAt']) ?? now,
            updatedAt: _parseDateTime(meaningData['updatedAt']) ?? now,
          );
          await _dbHelper.insertMeaning(meaning);
          newMeanings++;
        } else {
          skippedMeanings++;
        }
      }

      // 导入关联关系
      for (final relationData in relationsData) {
        final wordText = relationData['wordText'] as String;
        final meaningText = relationData['meaningText'] as String;
        
        final word = await _dbHelper.getWordByText(wordText);
        final meaning = await _dbHelper.getMeaningByText(meaningText);
        
        if (word != null && meaning != null) {
          final wordMeaning = WordMeaning(
            wordId: word.id!,
            meaningId: meaning.id!,
            createdAt: now,
          );
          
          final result = await _dbHelper.insertWordMeaning(wordMeaning);
          if (result > 0) {
            newRelations++;
          } else {
            skippedRelations++;
          }
        }
      }

      return ImportResult(
        success: true,
        message: '导入完成！\n'
            '新增词语：$newWords 个\n'
            '新增意项：$newMeanings 个\n'
            '新增关联：$newRelations 个\n'
            '跳过重复词语：$skippedWords 个\n'
            '跳过重复意项：$skippedMeanings 个\n'
            '跳过重复关联：$skippedRelations 个',
        importedWords: newWords,
        importedMeanings: newMeanings,
        importedRelations: newRelations,
        skippedWords: skippedWords,
        skippedMeanings: skippedMeanings,
        skippedRelations: skippedRelations,
      );
    } catch (e) {
      return ImportResult(
        success: false,
        message: '导入失败：$e',
      );
    }
  }

  /// 验证导入数据格式
  ImportResult _validateImportData(Map<String, dynamic> importData) {
    // 检查必要字段
    if (!importData.containsKey('version')) {
      return ImportResult(
        success: false,
        message: '文件格式错误：缺少版本信息',
      );
    }

    if (!importData.containsKey('data')) {
      return ImportResult(
        success: false,
        message: '文件格式错误：缺少数据内容',
      );
    }

    final data = importData['data'];
    if (data is! Map<String, dynamic>) {
      return ImportResult(
        success: false,
        message: '文件格式错误：数据格式不正确',
      );
    }

    // 检查数据字段
    final requiredFields = ['words', 'meanings', 'relations'];
    for (final field in requiredFields) {
      if (!data.containsKey(field)) {
        return ImportResult(
          success: false,
          message: '文件格式错误：缺少 $field 数据',
        );
      }
      
      if (data[field] is! List) {
        return ImportResult(
          success: false,
          message: '文件格式错误：$field 数据格式不正确',
        );
      }
    }

    return ImportResult(success: true, message: '格式验证通过');
  }

  /// 解析日期时间字符串
  DateTime? _parseDateTime(dynamic dateTimeStr) {
    if (dateTimeStr == null) return null;
    try {
      return DateTime.parse(dateTimeStr.toString());
    } catch (e) {
      return null;
    }
  }

  /// 获取当前数据库统计信息
  Future<DatabaseStats> getDatabaseStats() async {
    try {
      final words = await _dbHelper.getAllWords();
      final meanings = await _dbHelper.getAllMeanings();
      final wordMeaningPairs = await _dbHelper.getAllWordMeaningPairs();

      return DatabaseStats(
        totalWords: words.length,
        totalMeanings: meanings.length,
        totalRelations: wordMeaningPairs.length,
      );
    } catch (e) {
      return DatabaseStats(
        totalWords: 0,
        totalMeanings: 0,
        totalRelations: 0,
      );
    }
  }
}

/// 导出结果
class ExportResult {
  final bool success;
  final String message;
  final String? data;
  final String? fileName;

  ExportResult({
    required this.success,
    required this.message,
    this.data,
    this.fileName,
  });
}

/// 分享结果
class ShareResult {
  final bool success;
  final String message;
  final String? filePath;

  ShareResult({
    required this.success,
    required this.message,
    this.filePath,
  });
}

/// 导入结果
class ImportResult {
  final bool success;
  final String message;
  final int importedWords;
  final int importedMeanings;
  final int importedRelations;
  final int skippedWords;
  final int skippedMeanings;
  final int skippedRelations;

  ImportResult({
    required this.success,
    required this.message,
    this.importedWords = 0,
    this.importedMeanings = 0,
    this.importedRelations = 0,
    this.skippedWords = 0,
    this.skippedMeanings = 0,
    this.skippedRelations = 0,
  });
}

/// 数据库统计信息
class DatabaseStats {
  final int totalWords;
  final int totalMeanings;
  final int totalRelations;

  DatabaseStats({
    required this.totalWords,
    required this.totalMeanings,
    required this.totalRelations,
  });
}