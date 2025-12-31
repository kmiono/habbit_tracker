import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// データベースヘルパークラス
///
/// SQLiteデータベースの初期化、テーブル作成、マイグレーションを管理します。
/// シングルトンパターンで実装されており、アプリ全体で1つのインスタンスを共有します。
class DatabaseHelper {
  // シングルトンインスタンス
  static final DatabaseHelper instance = DatabaseHelper._internal();

  // データベースインスタンス（遅延初期化）
  static Database? _database;

  // データベース名
  static const String _databaseName = 'habit_tracker.db';

  // データベースバージョン
  static const int _databaseVersion = 1;

  // テーブル名: タスク
  static const String tableTask = 'tasks';

  /// テーブル名: タスク実行記録
  static const String tableTaskExecution = 'task_executions';

  /// プライベートコンストラクタ（シングルトンパターン）
  DatabaseHelper._internal();

  /// データベースインスタンスを取得
  ///
  /// 初回呼び出し時にデータベースを初期化します。
  /// 2回目以降は既存のインスタンスを返します。
  ///
  /// 戻り値: 初期化済みのデータベースインスタンス
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// データベースを初期化
  ///
  /// データベースファイルが存在しない場合は作成し、
  /// テーブルとインデックスを作成します。
  ///
  /// 戻り値: 初期化済みのデータベースインスタンス
  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  /// データベース設定（外部キー制約の有効化）
  ///
  /// データベース接続時に外部キー制約を有効化します。
  /// これにより、タスク削除時に実行記録も自動的に削除されます。
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// データベース作成時の処理
  ///
  /// テーブルとインデックスを作成します。
  ///
  /// [db] データベースインスタンス
  /// [version] データベースバージョン
  Future<void> _onCreate(Database db, int version) async {
    // tasksテーブル作成
    await db.execute('''
CREATE TABLE $tableTask(
id TEXT PRIMARY KEY,
name TEXT NOT NULL
color TEXT NOT NULL,
created_at INTEGER NOT NULL,
updated_at INTEGER NOT NULL,
is_deleted INTEGER NOT NULL default 0
)
''');

    // tasksテーブルのインデックス作成
    await db.execute('''
CREATE INDEX idx_tasks_created_at ON $tableTask(created_at)
''');

    await db.execute('''
CREATED INDEX idx_tasks_is_deleted ON $tableTask(is_deleted)
''');

    // task_executionsテーブル作成
    await db.execute('''
      CREATE TABLE $tableTaskExecution(
      id TEXT PRIMARY KEY,
      task_is TEXT NOT NULL,
      executed_at INTEGER NOT NULL,
      created_at INTEGER NOT NULL,
      FOREIGN KEY(task_id) REFERENCES $tableTask(id) ON DELETE CASCADE
      )
    ''');

    // task_executionsテーブルのインデックス作成
    await db.execute('''
      CREATE INDEX idx_task_executions_task_id 
      ON $tableTaskExecution(task_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_task_executions_executed_at 
      ON $tableTaskExecution(executed_at)
    ''');

    await db.execute('''
      CREATE INDEX idx_task_executions_task_date 
      ON $tableTaskExecution(task_id, executed_at)
    ''');
  }

  /// データベースアップグレード時の処理
  ///
  /// データベースバージョンが変更された際に呼び出されます。
  /// マイグレーション処理を実装します。
  ///
  /// [db] データベースインスタンス
  /// [oldVersion] 旧バージョン
  /// [newVersion] 新バージョン
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // バージョン2へのマイグレーション例
    // if (oldVersion < 2) {
    //   await db.execute('ALTER TABLE $tableTask ADD COLUMN description TEXT');
    // }

    // バージョン3へのマイグレーション例
    // if (oldVersion < 3) {
    //   await db.execute('ALTER TABLE $tableTaskExecution ADD COLUMN notes TEXT');
    // }

    // 以降のバージョンアップ対応をここに追加
  }

  /// データベースをクローズ
  ///
  /// アプリ終了時やテスト時にデータベース接続を閉じます。
  /// クローズ後は次回のアクセス時に再初期化されます。
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  /// データベースを削除（テスト用）
  ///
  /// テスト時にデータベースを完全に削除します。
  /// 本番環境では使用しないでください。
  Future<void> deleteDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _databaseName);
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }
}
