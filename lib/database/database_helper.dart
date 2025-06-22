import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import '../models/word_item.dart';
import '../models/word.dart';
import '../models/meaning.dart';
import '../models/word_meaning.dart';
import '../models/word_meaning_pair.dart';
import '../models/context_info.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'corgi_recite.db');
    return await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 新的多对多结构
    await db.execute('''
      CREATE TABLE words(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        text TEXT NOT NULL UNIQUE,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE meanings(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        text TEXT NOT NULL UNIQUE,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE word_meanings(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word_id INTEGER NOT NULL,
        meaning_id INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (word_id) REFERENCES words (id) ON DELETE CASCADE,
        FOREIGN KEY (meaning_id) REFERENCES meanings (id) ON DELETE CASCADE,
        UNIQUE(word_id, meaning_id)
      )
    ''');

    // 上下文信息表
    await db.execute('''
      CREATE TABLE context_info(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word_id INTEGER,
        meaning_id INTEGER,
        original_text TEXT NOT NULL,
        display_text TEXT NOT NULL,
        placeholders TEXT,
        prepositions TEXT,
        keywords TEXT,
        part_of_speech TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (word_id) REFERENCES words (id) ON DELETE CASCADE,
        FOREIGN KEY (meaning_id) REFERENCES meanings (id) ON DELETE CASCADE
      )
    ''');

    // 保留旧表以便兼容和迁移
    await db.execute('''
      CREATE TABLE word_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT NOT NULL,
        meaning TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 创建新表
      await db.execute('''
        CREATE TABLE words(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          text TEXT NOT NULL UNIQUE,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE meanings(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          text TEXT NOT NULL UNIQUE,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE word_meanings(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          word_id INTEGER NOT NULL,
          meaning_id INTEGER NOT NULL,
          created_at INTEGER NOT NULL,
          FOREIGN KEY (word_id) REFERENCES words (id) ON DELETE CASCADE,
          FOREIGN KEY (meaning_id) REFERENCES meanings (id) ON DELETE CASCADE,
          UNIQUE(word_id, meaning_id)
        )
      ''');

      // 迁移现有数据
      await _migrateOldData(db);
    }
    
    if (oldVersion < 3) {
      // 添加上下文信息表
      await db.execute('''
        CREATE TABLE context_info(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          word_id INTEGER,
          meaning_id INTEGER,
          original_text TEXT NOT NULL,
          display_text TEXT NOT NULL,
          placeholders TEXT,
          prepositions TEXT,
          keywords TEXT,
          part_of_speech TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          FOREIGN KEY (word_id) REFERENCES words (id) ON DELETE CASCADE,
          FOREIGN KEY (meaning_id) REFERENCES meanings (id) ON DELETE CASCADE
        )
      ''');
    }
  }

  Future<void> _migrateOldData(Database db) async {
    final List<Map<String, dynamic>> oldItems = await db.query('word_items');
    
    for (var item in oldItems) {
      final wordText = item['word'] as String;
      final meaningText = item['meaning'] as String;
      final createdAt = item['created_at'] as int;
      final updatedAt = item['updated_at'] as int;

      // 插入词语（如果不存在）
      int wordId;
      final existingWords = await db.query(
        'words',
        where: 'text = ?',
        whereArgs: [wordText],
      );
      
      if (existingWords.isEmpty) {
        wordId = await db.insert('words', {
          'text': wordText,
          'created_at': createdAt,
          'updated_at': updatedAt,
        });
      } else {
        wordId = existingWords.first['id'] as int;
      }

      // 插入意项（如果不存在）
      int meaningId;
      final existingMeanings = await db.query(
        'meanings',
        where: 'text = ?',
        whereArgs: [meaningText],
      );
      
      if (existingMeanings.isEmpty) {
        meaningId = await db.insert('meanings', {
          'text': meaningText,
          'created_at': createdAt,
          'updated_at': updatedAt,
        });
      } else {
        meaningId = existingMeanings.first['id'] as int;
      }

      // 创建关联关系（如果不存在）
      final existingRelations = await db.query(
        'word_meanings',
        where: 'word_id = ? AND meaning_id = ?',
        whereArgs: [wordId, meaningId],
      );
      
      if (existingRelations.isEmpty) {
        await db.insert('word_meanings', {
          'word_id': wordId,
          'meaning_id': meaningId,
          'created_at': createdAt,
        });
      }
    }
  }

  Future<int> insertWordItem(WordItem wordItem) async {
    final db = await database;
    return await db.insert(
      'word_items',
      wordItem.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<WordItem>> getAllWordItems() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('word_items');
    return List.generate(maps.length, (i) {
      return WordItem.fromMap(maps[i]);
    });
  }

  Future<WordItem?> getWordItem(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'word_items',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return WordItem.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateWordItem(WordItem wordItem) async {
    final db = await database;
    return await db.update(
      'word_items',
      wordItem.toMap(),
      where: 'id = ?',
      whereArgs: [wordItem.id],
    );
  }

  Future<int> deleteWordItem(int id) async {
    final db = await database;
    return await db.delete(
      'word_items',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<WordItem>> getRandomWordItems(int count) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      'SELECT * FROM word_items ORDER BY RANDOM() LIMIT ?',
      [count],
    );
    return List.generate(maps.length, (i) {
      return WordItem.fromMap(maps[i]);
    });
  }

  // 新的多对多关系方法

  // 词语操作
  Future<int> insertWord(Word word) async {
    final db = await database;
    try {
      return await db.insert('words', word.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
    } catch (e) {
      // 如果插入失败（可能是重复），查找现有的
      final existing = await db.query('words', where: 'text = ?', whereArgs: [word.text]);
      if (existing.isNotEmpty) {
        return existing.first['id'] as int;
      }
      rethrow;
    }
  }

  Future<Word?> getWordByText(String text) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'words',
      where: 'text = ?',
      whereArgs: [text],
    );
    if (maps.isNotEmpty) {
      return Word.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Word>> getAllWords() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('words');
    return List.generate(maps.length, (i) => Word.fromMap(maps[i]));
  }

  // 意项操作
  Future<int> insertMeaning(Meaning meaning) async {
    final db = await database;
    try {
      return await db.insert('meanings', meaning.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
    } catch (e) {
      // 如果插入失败（可能是重复），查找现有的
      final existing = await db.query('meanings', where: 'text = ?', whereArgs: [meaning.text]);
      if (existing.isNotEmpty) {
        return existing.first['id'] as int;
      }
      rethrow;
    }
  }

  Future<Meaning?> getMeaningByText(String text) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'meanings',
      where: 'text = ?',
      whereArgs: [text],
    );
    if (maps.isNotEmpty) {
      return Meaning.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Meaning>> getAllMeanings() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('meanings');
    return List.generate(maps.length, (i) => Meaning.fromMap(maps[i]));
  }

  // 关联关系操作
  Future<int> insertWordMeaning(WordMeaning wordMeaning) async {
    final db = await database;
    return await db.insert('word_meanings', wordMeaning.toMap(), 
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<List<WordMeaningPair>> getAllWordMeaningPairs() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT 
        w.id as word_id, w.text as word_text, w.created_at as word_created_at, w.updated_at as word_updated_at,
        m.id as meaning_id, m.text as meaning_text, m.created_at as meaning_created_at, m.updated_at as meaning_updated_at
      FROM word_meanings wm
      JOIN words w ON wm.word_id = w.id
      JOIN meanings m ON wm.meaning_id = m.id
      ORDER BY wm.created_at DESC
    ''');
    
    return List.generate(maps.length, (i) {
      final map = maps[i];
      final word = Word(
        id: map['word_id'],
        text: map['word_text'],
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['word_created_at']),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(map['word_updated_at']),
      );
      final meaning = Meaning(
        id: map['meaning_id'],
        text: map['meaning_text'],
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['meaning_created_at']),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(map['meaning_updated_at']),
      );
      return WordMeaningPair(word: word, meaning: meaning);
    });
  }

  Future<List<WordMeaningPair>> getRandomWordMeaningPairs(int count) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT 
        w.id as word_id, w.text as word_text, w.created_at as word_created_at, w.updated_at as word_updated_at,
        m.id as meaning_id, m.text as meaning_text, m.created_at as meaning_created_at, m.updated_at as meaning_updated_at
      FROM word_meanings wm
      JOIN words w ON wm.word_id = w.id
      JOIN meanings m ON wm.meaning_id = m.id
      ORDER BY RANDOM()
      LIMIT ?
    ''', [count]);
    
    return List.generate(maps.length, (i) {
      final map = maps[i];
      final word = Word(
        id: map['word_id'],
        text: map['word_text'],
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['word_created_at']),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(map['word_updated_at']),
      );
      final meaning = Meaning(
        id: map['meaning_id'],
        text: map['meaning_text'],
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['meaning_created_at']),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(map['meaning_updated_at']),
      );
      return WordMeaningPair(word: word, meaning: meaning);
    });
  }

  Future<List<Word>> getWordsByMeaningId(int meaningId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT w.*
      FROM words w
      JOIN word_meanings wm ON w.id = wm.word_id
      WHERE wm.meaning_id = ?
    ''', [meaningId]);
    
    return List.generate(maps.length, (i) => Word.fromMap(maps[i]));
  }

  Future<List<Meaning>> getMeaningsByWordId(int wordId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT m.*
      FROM meanings m
      JOIN word_meanings wm ON m.id = wm.meaning_id
      WHERE wm.word_id = ?
    ''', [wordId]);
    
    return List.generate(maps.length, (i) => Meaning.fromMap(maps[i]));
  }

  // 批量添加词语-意项对的方法（支持多对多关系）
  Future<List<int>> addWordMeaningPairs(List<String> wordMeaningTexts) async {
    final db = await database;
    final List<int> addedIds = [];
    final now = DateTime.now();

    await db.transaction((txn) async {
      for (String pairText in wordMeaningTexts) {
        final parts = pairText.split('=');
        if (parts.length == 2) {
          // 解析词语（支持逗号分隔的多个词语）
          final wordTexts = parts[0].split(',').map((w) => w.trim()).where((w) => w.isNotEmpty).toList();
          // 解析意项（支持逗号分隔的多个意项）
          final meaningTexts = parts[1].split(',').map((m) => m.trim()).where((m) => m.isNotEmpty).toList();

          // 为每个词语-意项组合创建关联
          for (final wordText in wordTexts) {
            for (final meaningText in meaningTexts) {
              // 插入或获取词语
              int wordId;
              final existingWord = await txn.query('words', where: 'text = ?', whereArgs: [wordText]);
              if (existingWord.isEmpty) {
                wordId = await txn.insert('words', {
                  'text': wordText,
                  'created_at': now.millisecondsSinceEpoch,
                  'updated_at': now.millisecondsSinceEpoch,
                });
              } else {
                wordId = existingWord.first['id'] as int;
              }

              // 插入或获取意项
              int meaningId;
              final existingMeaning = await txn.query('meanings', where: 'text = ?', whereArgs: [meaningText]);
              if (existingMeaning.isEmpty) {
                meaningId = await txn.insert('meanings', {
                  'text': meaningText,
                  'created_at': now.millisecondsSinceEpoch,
                  'updated_at': now.millisecondsSinceEpoch,
                });
              } else {
                meaningId = existingMeaning.first['id'] as int;
              }

              // 创建关联关系（如果不存在）
              final existingRelation = await txn.query(
                'word_meanings',
                where: 'word_id = ? AND meaning_id = ?',
                whereArgs: [wordId, meaningId],
              );
              
              if (existingRelation.isEmpty) {
                final relationId = await txn.insert('word_meanings', {
                  'word_id': wordId,
                  'meaning_id': meaningId,
                  'created_at': now.millisecondsSinceEpoch,
                });
                addedIds.add(relationId);
              }
            }
          }
        }
      }
    });

    return addedIds;
  }

  // 根据多对多关系获取特定意项的所有词语（用于测试逻辑）
  Future<List<WordMeaningPair>> getWordPairsForMeaning(Meaning meaning) async {
    final words = await getWordsByMeaningId(meaning.id!);
    return words.map((word) => WordMeaningPair(word: word, meaning: meaning)).toList();
  }

  // 删除特定的词语-意项关联关系
  Future<bool> deleteWordMeaningPair(int wordId, int meaningId) async {
    final db = await database;
    
    await db.transaction((txn) async {
      // 删除关联关系
      await txn.delete(
        'word_meanings',
        where: 'word_id = ? AND meaning_id = ?',
        whereArgs: [wordId, meaningId],
      );
      
      // 检查词语是否还有其他关联，如果没有则删除词语
      final wordMeanings = await txn.query(
        'word_meanings',
        where: 'word_id = ?',
        whereArgs: [wordId],
      );
      
      if (wordMeanings.isEmpty) {
        await txn.delete('words', where: 'id = ?', whereArgs: [wordId]);
      }
      
      // 检查意项是否还有其他关联，如果没有则删除意项
      final meaningWords = await txn.query(
        'word_meanings',
        where: 'meaning_id = ?',
        whereArgs: [meaningId],
      );
      
      if (meaningWords.isEmpty) {
        await txn.delete('meanings', where: 'id = ?', whereArgs: [meaningId]);
      }
    });
    
    return true;
  }

  // 批量删除词语-意项关联关系
  Future<int> deleteWordMeaningPairs(List<WordMeaningPair> pairs) async {
    final db = await database;
    int deletedCount = 0;
    
    await db.transaction((txn) async {
      for (final pair in pairs) {
        // 删除关联关系
        final deletedRelations = await txn.delete(
          'word_meanings',
          where: 'word_id = ? AND meaning_id = ?',
          whereArgs: [pair.word.id, pair.meaning.id],
        );
        
        if (deletedRelations > 0) {
          deletedCount++;
        }
        
        // 检查词语是否还有其他关联，如果没有则删除词语
        final wordMeanings = await txn.query(
          'word_meanings',
          where: 'word_id = ?',
          whereArgs: [pair.word.id],
        );
        
        if (wordMeanings.isEmpty) {
          await txn.delete('words', where: 'id = ?', whereArgs: [pair.word.id]);
        }
        
        // 检查意项是否还有其他关联，如果没有则删除意项
        final meaningWords = await txn.query(
          'word_meanings',
          where: 'meaning_id = ?',
          whereArgs: [pair.meaning.id],
        );
        
        if (meaningWords.isEmpty) {
          await txn.delete('meanings', where: 'id = ?', whereArgs: [pair.meaning.id]);
        }
      }
    });
    
    return deletedCount;
  }

  // ==================== 上下文信息相关方法 ====================

  /// 插入上下文信息 - 关联词语
  Future<int> insertContextInfoForWord(int wordId, ContextInfo contextInfo) async {
    final db = await database;
    return await db.insert('context_info', {
      'word_id': wordId,
      'meaning_id': null,
      'original_text': contextInfo.originalText,
      'display_text': contextInfo.displayText,
      'placeholders': jsonEncode(contextInfo.placeholders.map((p) => p.toMap()).toList()),
      'prepositions': jsonEncode(contextInfo.prepositions.map((p) => p.toMap()).toList()),
      'keywords': jsonEncode(contextInfo.keywords),
      'part_of_speech': contextInfo.partOfSpeech,
      'created_at': contextInfo.createdAt.millisecondsSinceEpoch,
      'updated_at': contextInfo.updatedAt.millisecondsSinceEpoch,
    });
  }

  /// 插入上下文信息 - 关联意项
  Future<int> insertContextInfoForMeaning(int meaningId, ContextInfo contextInfo) async {
    final db = await database;
    return await db.insert('context_info', {
      'word_id': null,
      'meaning_id': meaningId,
      'original_text': contextInfo.originalText,
      'display_text': contextInfo.displayText,
      'placeholders': jsonEncode(contextInfo.placeholders.map((p) => p.toMap()).toList()),
      'prepositions': jsonEncode(contextInfo.prepositions.map((p) => p.toMap()).toList()),
      'keywords': jsonEncode(contextInfo.keywords),
      'part_of_speech': contextInfo.partOfSpeech,
      'created_at': contextInfo.createdAt.millisecondsSinceEpoch,
      'updated_at': contextInfo.updatedAt.millisecondsSinceEpoch,
    });
  }

  /// 根据词语ID获取上下文信息
  Future<ContextInfo?> getContextInfoByWordId(int wordId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'context_info',
      where: 'word_id = ?',
      whereArgs: [wordId],
    );

    if (maps.isEmpty) return null;
    
    return _contextInfoFromMap(maps.first);
  }

  /// 根据意项ID获取上下文信息
  Future<ContextInfo?> getContextInfoByMeaningId(int meaningId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'context_info',
      where: 'meaning_id = ?',
      whereArgs: [meaningId],
    );

    if (maps.isEmpty) return null;
    
    return _contextInfoFromMap(maps.first);
  }

  /// 获取所有上下文信息
  Future<List<ContextInfo>> getAllContextInfo() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('context_info');
    return maps.map((map) => _contextInfoFromMap(map)).toList();
  }

  /// 更新上下文信息
  Future<int> updateContextInfo(ContextInfo contextInfo) async {
    final db = await database;
    return await db.update(
      'context_info',
      {
        'original_text': contextInfo.originalText,
        'display_text': contextInfo.displayText,
        'placeholders': jsonEncode(contextInfo.placeholders.map((p) => p.toMap()).toList()),
        'prepositions': jsonEncode(contextInfo.prepositions.map((p) => p.toMap()).toList()),
        'keywords': jsonEncode(contextInfo.keywords),
        'part_of_speech': contextInfo.partOfSpeech,
        'updated_at': contextInfo.updatedAt.millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [contextInfo.id],
    );
  }

  /// 删除上下文信息
  Future<int> deleteContextInfo(int id) async {
    final db = await database;
    return await db.delete(
      'context_info',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 从Map转换为ContextInfo对象
  ContextInfo _contextInfoFromMap(Map<String, dynamic> map) {
    return ContextInfo(
      id: map['id'],
      originalText: map['original_text'],
      displayText: map['display_text'],
      placeholders: (jsonDecode(map['placeholders'] ?? '[]') as List)
          .map((p) => Placeholder.fromMap(p))
          .toList(),
      prepositions: (jsonDecode(map['prepositions'] ?? '[]') as List)
          .map((p) => Preposition.fromMap(p))
          .toList(),
      keywords: List<String>.from(jsonDecode(map['keywords'] ?? '[]')),
      partOfSpeech: map['part_of_speech'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']),
    );
  }
}