import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/word_item.dart';

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
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
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
}