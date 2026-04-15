import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('scroller.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE articles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        author TEXT NOT NULL,
        content TEXT NOT NULL,
        source TEXT UNIQUE NOT NULL,
        category TEXT NOT NULL,
        published_date TEXT NOT NULL,
        is_saved INTEGER DEFAULT 0
      )
    ''');
  }

  Future<void> insertArticle(Map<String, dynamic> article) async {
    final db = await instance.database;
    await db.insert(
      'articles',
      article,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<Map<String, dynamic>>> getSavedArticles() async {
    final db = await instance.database;
    return await db.query(
      'articles',
      where: 'is_saved = ?',
      whereArgs: [1],
      orderBy: 'id DESC',
    );
  }

  Future<int> toggleSave(int id, int currentStatus) async {
    final db = await instance.database;
    final newStatus = currentStatus == 1 ? 0 : 1;
    await db.update(
      'articles',
      {'is_saved': newStatus},
      where: 'id = ?',
      whereArgs: [id],
    );
    return newStatus;
  }

  Future<Map<String, dynamic>?> getArticleBySource(String source) async {
    final db = await instance.database;
    final maps = await db.query(
      'articles',
      columns: ['id', 'is_saved'],
      where: 'source = ?',
      whereArgs: [source],
    );
    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }
}