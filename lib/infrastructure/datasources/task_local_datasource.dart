import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';

/// タスクのローカルデータソース
///
/// SQLiteデータベースに対するタスクのCRUD操作を提供します。
/// データベース操作の低レベルな実装を担当し、
/// Map<String, dynamic>形式でデータを扱います。
class TaskLocalDataSource {
  final DatabaseHelper _dbHelper;

  /// コンストラクタ
  ///
  /// [dbHelper] データベースヘルパーインスタンス
  TaskLocalDataSource(this._dbHelper);

  /// タスクを挿入
  ///
  /// [taskMap] タスクデータ（Map形式）
  ///
  /// 既に同じIDのタスクが存在する場合は置き換えます。
  Future<void> insertTask(Map<String, dynamic> taskMap) async {
    final db = await _dbHelper.database;
    await db.insert(
      DatabaseHelper.tableTask,
      taskMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// IDでタスクを取得
  ///
  /// [id] タスクID
  ///
  /// 戻り値: タスクデータ（存在しない場合はnull）
  /// 削除済みのタスクは取得されません。
  Future<Map<String, dynamic>?> getTaskById(String id) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      DatabaseHelper.tableTask,
      where: 'id = ? AND is_deleted = ?',
      whereArgs: [id, 0],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// すべてのタスクを取得
  ///
  /// 戻り値: 削除されていないすべてのタスクのリスト
  /// 作成日時の昇順でソートされます。
  Future<List<Map<String, dynamic>>> getAllTasks() async {
    final db = await _dbHelper.database;
    return await db.query(
      DatabaseHelper.tableTask,
      where: 'is_deleted = ?',
      whereArgs: [0],
      orderBy: 'created_at ASC',
    );
  }

  /// タスクを更新
  ///
  /// [taskMap] 更新するタスクデータ（idを含む必要があります）
  ///
  /// 指定されたIDのタスクを更新します。
  Future<void> updateTask(Map<String, dynamic> taskMap) async {
    final db = await _dbHelper.database;
    await db.update(
      DatabaseHelper.tableTask,
      taskMap,
      where: 'id = ?',
      whereArgs: [taskMap['id']],
    );
  }

  /// タスクを論理削除
  ///
  /// [id] 削除するタスクID
  ///
  /// is_deletedフラグを1に設定し、updated_atを現在時刻に更新します。
  /// データは物理的には削除されず、論理削除としてマークされます。
  Future<void> deleteTask(String id) async {
    final db = await _dbHelper.database;
    await db.update(
      DatabaseHelper.tableTask,
      {'is_deleted': 1, 'updated_at': DateTime.now().microsecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// タスクを完全削除
  ///
  /// [id] 削除するタスクID
  ///
  /// データベースから物理的に削除します。
  /// 注意: この操作は取り消せません。
  Future<void> permanentlyDeleteTask(String id) async {
    final db = await _dbHelper.database;
    await db.delete(DatabaseHelper.tableTask, where: 'id = ?', whereArgs: [id]);
  }
}
