# 習慣化アプリ 詳細設計書

## 目次
1. [システム概要](#1-システム概要)
2. [技術スタック](#2-技術スタック)
3. [データベース設計](#3-データベース設計)
4. [ドメイン層設計](#4-ドメイン層設計)
5. [インフラストラクチャ層設計](#5-インフラストラクチャ層設計)
6. [アプリケーション層設計](#6-アプリケーション層設計)
7. [プレゼンテーション層設計](#7-プレゼンテーション層設計)
8. [画面仕様](#8-画面仕様)
9. [カレンダー表示ロジック](#9-カレンダー表示ロジック)
10. [エラーハンドリング](#10-エラーハンドリング)
11. [パフォーマンス最適化](#11-パフォーマンス最適化)

---

## 1. システム概要

### 1.1 アプリケーション名
**Habit Tracker**

### 1.2 目的
日々の習慣を記録・管理し、GitHubのContributionグラフ風のビジュアルフィードバックでモチベーションを維持

### 1.3 主要機能
- タスクのCRUD操作
- タスク実行記録
- Contributionスタイルカレンダー表示

---

## 2. 技術スタック

### 2.1 フレームワーク
- **Flutter**: 3.16.0以上
- **Dart**: 3.2.0以上

### 2.2 主要パッケージ

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # 状態管理
  flutter_riverpod: ^2.4.0
  riverpod_annotation: ^2.3.0
  
  # データベース
  sqflite: ^2.3.0
  path: ^1.8.3
  
  # UI
  fl_chart: ^0.65.0
  flutter_colorpicker: ^1.0.3
  table_calendar: ^3.0.9
  intl: ^0.18.1
  
  # ユーティリティ
  uuid: ^4.2.0
  freezed_annotation: ^2.4.1
  json_annotation: ^4.8.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  
  # コード生成
  build_runner: ^2.4.6
  riverpod_generator: ^2.3.0
  freezed: ^2.4.5
  json_serializable: ^6.7.1
  
  # リント
  flutter_lints: ^3.0.0
```

---

## 3. データベース設計

### 3.1 データベース仕様

#### 基本情報
- **データベース名**: `habit_tracker.db`
- **初期バージョン**: 1
- **格納場所**: アプリケーションドキュメントディレクトリ

### 3.2 テーブル定義

#### 3.2.1 tasks テーブル

```sql
CREATE TABLE tasks (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  color TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  is_deleted INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX idx_tasks_created_at ON tasks(created_at);
CREATE INDEX idx_tasks_is_deleted ON tasks(is_deleted);
```

**カラム詳細:**

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|-----------|------|
| id | TEXT | NO | - | UUID (主キー) |
| name | TEXT | NO | - | タスク名 (最大255文字) |
| color | TEXT | NO | - | カラーコード (例: "#FF5733") |
| created_at | INTEGER | NO | - | 作成日時 (Unixタイムスタンプ ミリ秒) |
| updated_at | INTEGER | NO | - | 更新日時 (Unixタイムスタンプ ミリ秒) |
| is_deleted | INTEGER | NO | 0 | 削除フラグ (0: 未削除, 1: 削除済み) |

#### 3.2.2 task_executions テーブル

```sql
CREATE TABLE task_executions (
  id TEXT PRIMARY KEY,
  task_id TEXT NOT NULL,
  executed_at INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
);

CREATE INDEX idx_task_executions_task_id ON task_executions(task_id);
CREATE INDEX idx_task_executions_executed_at ON task_executions(executed_at);
CREATE INDEX idx_task_executions_task_date ON task_executions(task_id, executed_at);
```

**カラム詳細:**

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|-----------|------|
| id | TEXT | NO | - | UUID (主キー) |
| task_id | TEXT | NO | - | タスクID (外部キー) |
| executed_at | INTEGER | NO | - | 実行日時 (Unixタイムスタンプ ミリ秒) |
| created_at | INTEGER | NO | - | 記録日時 (Unixタイムスタンプ ミリ秒) |

### 3.3 マイグレーション戦略

```dart
Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 2) {
    // バージョン2へのマイグレーション
    // await db.execute('ALTER TABLE tasks ADD COLUMN ...');
  }
  // 以降のバージョンアップ対応
}
```

---

## 4. ドメイン層設計

### 4.1 エンティティ定義

#### 4.1.1 Task エンティティ

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'task.freezed.dart';
part 'task.g.dart';

@freezed
class Task with _$Task {
  const factory Task({
    required String id,
    required String name,
    required String color,
    required DateTime createdAt,
    required DateTime updatedAt,
    @Default(false) bool isDeleted,
  }) = _Task;

  factory Task.fromJson(Map<String, dynamic> json) => _$TaskFromJson(json);
}
```

**ファクトリメソッド:**

```dart
extension TaskExtension on Task {
  // 新規作成用
  static Task create({
    required String name,
    required String color,
  }) {
    final now = DateTime.now();
    return Task(
      id: const Uuid().v4(),
      name: name,
      color: color,
      createdAt: now,
      updatedAt: now,
    );
  }

  // コピーして更新
  Task update({
    String? name,
    String? color,
  }) {
    return copyWith(
      name: name ?? this.name,
      color: color ?? this.color,
      updatedAt: DateTime.now(),
    );
  }
}
```

#### 4.1.2 TaskExecution エンティティ

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'task_execution.freezed.dart';
part 'task_execution.g.dart';

@freezed
class TaskExecution with _$TaskExecution {
  const factory TaskExecution({
    required String id,
    required String taskId,
    required DateTime executedAt,
    required DateTime createdAt,
  }) = _TaskExecution;

  factory TaskExecution.fromJson(Map<String, dynamic> json) =>
      _$TaskExecutionFromJson(json);
}
```

**ファクトリメソッド:**

```dart
extension TaskExecutionExtension on TaskExecution {
  static TaskExecution create({
    required String taskId,
    DateTime? executedAt,
  }) {
    final now = DateTime.now();
    return TaskExecution(
      id: const Uuid().v4(),
      taskId: taskId,
      executedAt: executedAt ?? now,
      createdAt: now,
    );
  }
}
```

### 4.2 リポジトリインターフェース

#### 4.2.1 TaskRepository

```dart
abstract class TaskRepository {
  // 作成
  Future<Task> createTask(Task task);
  
  // 読み取り
  Future<Task?> getTaskById(String id);
  Future<List<Task>> getAllTasks();
  Stream<List<Task>> watchAllTasks();
  
  // 更新
  Future<Task> updateTask(Task task);
  
  // 削除（論理削除）
  Future<void> deleteTask(String id);
  
  // 完全削除
  Future<void> permanentlyDeleteTask(String id);
}
```

#### 4.2.2 TaskExecutionRepository

```dart
abstract class TaskExecutionRepository {
  // 作成
  Future<TaskExecution> createExecution(TaskExecution execution);
  
  // 読み取り
  Future<TaskExecution?> getExecutionById(String id);
  Future<List<TaskExecution>> getExecutionsByTaskId(String taskId);
  Future<List<TaskExecution>> getExecutionsByDateRange({
    required DateTime startDate,
    required DateTime endDate,
    String? taskId,
  });
  Stream<List<TaskExecution>> watchExecutionsByTaskId(String taskId);
  
  // 削除
  Future<void> deleteExecution(String id);
  
  // 当日の実行記録を取得
  Future<TaskExecution?> getTodayExecution(String taskId);
  
  // 日付ごとの実行回数を取得
  Future<Map<DateTime, int>> getExecutionCountByDate({
    required DateTime startDate,
    required DateTime endDate,
    String? taskId,
  });
}
```

---

## 5. インフラストラクチャ層設計

### 5.1 DatabaseHelper

```dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;
  
  static const String _databaseName = 'habit_tracker.db';
  static const int _databaseVersion = 1;
  
  // テーブル名
  static const String tableTask = 'tasks';
  static const String tableTaskExecution = 'task_executions';
  
  DatabaseHelper._internal();
  
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }
  
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
  
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }
  
  Future<void> _onCreate(Database db, int version) async {
    // tasksテーブル作成
    await db.execute('''
      CREATE TABLE $tableTask (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        color TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
    
    await db.execute('''
      CREATE INDEX idx_tasks_created_at ON $tableTask(created_at)
    ''');
    
    await db.execute('''
      CREATE INDEX idx_tasks_is_deleted ON $tableTask(is_deleted)
    ''');
    
    // task_executionsテーブル作成
    await db.execute('''
      CREATE TABLE $tableTaskExecution (
        id TEXT PRIMARY KEY,
        task_id TEXT NOT NULL,
        executed_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (task_id) REFERENCES $tableTask(id) ON DELETE CASCADE
      )
    ''');
    
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
  
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // マイグレーション処理
  }
  
  // データベースをクローズ
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
```

### 5.2 TaskLocalDataSource

```dart
class TaskLocalDataSource {
  final DatabaseHelper _dbHelper;
  
  TaskLocalDataSource(this._dbHelper);
  
  Future<void> insertTask(Map<String, dynamic> taskMap) async {
    final db = await _dbHelper.database;
    await db.insert(
      DatabaseHelper.tableTask,
      taskMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  Future<Map<String, dynamic>?> getTaskById(String id) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      DatabaseHelper.tableTask,
      where: 'id = ? AND is_deleted = ?',
      whereArgs: [id, 0],
    );
    return results.isNotEmpty ? results.first : null;
  }
  
  Future<List<Map<String, dynamic>>> getAllTasks() async {
    final db = await _dbHelper.database;
    return await db.query(
      DatabaseHelper.tableTask,
      where: 'is_deleted = ?',
      whereArgs: [0],
      orderBy: 'created_at ASC',
    );
  }
  
  Future<void> updateTask(Map<String, dynamic> taskMap) async {
    final db = await _dbHelper.database;
    await db.update(
      DatabaseHelper.tableTask,
      taskMap,
      where: 'id = ?',
      whereArgs: [taskMap['id']],
    );
  }
  
  Future<void> deleteTask(String id) async {
    final db = await _dbHelper.database;
    await db.update(
      DatabaseHelper.tableTask,
      {
        'is_deleted': 1,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  Future<void> permanentlyDeleteTask(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      DatabaseHelper.tableTask,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
```

### 5.3 TaskExecutionLocalDataSource

```dart
class TaskExecutionLocalDataSource {
  final DatabaseHelper _dbHelper;
  
  TaskExecutionLocalDataSource(this._dbHelper);
  
  Future<void> insertExecution(Map<String, dynamic> executionMap) async {
    final db = await _dbHelper.database;
    await db.insert(
      DatabaseHelper.tableTaskExecution,
      executionMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  Future<Map<String, dynamic>?> getExecutionById(String id) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      DatabaseHelper.tableTaskExecution,
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }
  
  Future<List<Map<String, dynamic>>> getExecutionsByTaskId(
    String taskId,
  ) async {
    final db = await _dbHelper.database;
    return await db.query(
      DatabaseHelper.tableTaskExecution,
      where: 'task_id = ?',
      whereArgs: [taskId],
      orderBy: 'executed_at DESC',
    );
  }
  
  Future<List<Map<String, dynamic>>> getExecutionsByDateRange({
    required DateTime startDate,
    required DateTime endDate,
    String? taskId,
  }) async {
    final db = await _dbHelper.database;
    final startMillis = startDate.millisecondsSinceEpoch;
    final endMillis = endDate.millisecondsSinceEpoch;
    
    if (taskId != null) {
      return await db.query(
        DatabaseHelper.tableTaskExecution,
        where: 'task_id = ? AND executed_at BETWEEN ? AND ?',
        whereArgs: [taskId, startMillis, endMillis],
        orderBy: 'executed_at ASC',
      );
    } else {
      return await db.query(
        DatabaseHelper.tableTaskExecution,
        where: 'executed_at BETWEEN ? AND ?',
        whereArgs: [startMillis, endMillis],
        orderBy: 'executed_at ASC',
      );
    }
  }
  
  Future<void> deleteExecution(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      DatabaseHelper.tableTaskExecution,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  Future<Map<String, dynamic>?> getTodayExecution(String taskId) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    final results = await db.query(
      DatabaseHelper.tableTaskExecution,
      where: 'task_id = ? AND executed_at BETWEEN ? AND ?',
      whereArgs: [
        taskId,
        startOfDay.millisecondsSinceEpoch,
        endOfDay.millisecondsSinceEpoch,
      ],
      limit: 1,
    );
    
    return results.isNotEmpty ? results.first : null;
  }
}
```

### 5.4 Repository実装

#### 5.4.1 TaskRepositoryImpl

```dart
class TaskRepositoryImpl implements TaskRepository {
  final TaskLocalDataSource _dataSource;
  
  TaskRepositoryImpl(this._dataSource);
  
  @override
  Future<Task> createTask(Task task) async {
    final taskMap = _taskToMap(task);
    await _dataSource.insertTask(taskMap);
    return task;
  }
  
  @override
  Future<Task?> getTaskById(String id) async {
    final taskMap = await _dataSource.getTaskById(id);
    return taskMap != null ? _mapToTask(taskMap) : null;
  }
  
  @override
  Future<List<Task>> getAllTasks() async {
    final taskMaps = await _dataSource.getAllTasks();
    return taskMaps.map(_mapToTask).toList();
  }
  
  @override
  Stream<List<Task>> watchAllTasks() async* {
    while (true) {
      yield await getAllTasks();
      await Future.delayed(const Duration(seconds: 1));
    }
  }
  
  @override
  Future<Task> updateTask(Task task) async {
    final taskMap = _taskToMap(task);
    await _dataSource.updateTask(taskMap);
    return task;
  }
  
  @override
  Future<void> deleteTask(String id) async {
    await _dataSource.deleteTask(id);
  }
  
  @override
  Future<void> permanentlyDeleteTask(String id) async {
    await _dataSource.permanentlyDeleteTask(id);
  }
  
  Map<String, dynamic> _taskToMap(Task task) {
    return {
      'id': task.id,
      'name': task.name,
      'color': task.color,
      'created_at': task.createdAt.millisecondsSinceEpoch,
      'updated_at': task.updatedAt.millisecondsSinceEpoch,
      'is_deleted': task.isDeleted ? 1 : 0,
    };
  }
  
  Task _mapToTask(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as String,
      name: map['name'] as String,
      color: map['color'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      isDeleted: (map['is_deleted'] as int) == 1,
    );
  }
}
```

#### 5.4.2 TaskExecutionRepositoryImpl

```dart
class TaskExecutionRepositoryImpl implements TaskExecutionRepository {
  final TaskExecutionLocalDataSource _dataSource;
  
  TaskExecutionRepositoryImpl(this._dataSource);
  
  @override
  Future<TaskExecution> createExecution(TaskExecution execution) async {
    final executionMap = _executionToMap(execution);
    await _dataSource.insertExecution(executionMap);
    return execution;
  }
  
  @override
  Future<TaskExecution?> getExecutionById(String id) async {
    final executionMap = await _dataSource.getExecutionById(id);
    return executionMap != null ? _mapToExecution(executionMap) : null;
  }
  
  @override
  Future<List<TaskExecution>> getExecutionsByTaskId(String taskId) async {
    final executionMaps = await _dataSource.getExecutionsByTaskId(taskId);
    return executionMaps.map(_mapToExecution).toList();
  }
  
  @override
  Future<List<TaskExecution>> getExecutionsByDateRange({
    required DateTime startDate,
    required DateTime endDate,
    String? taskId,
  }) async {
    final executionMaps = await _dataSource.getExecutionsByDateRange(
      startDate: startDate,
      endDate: endDate,
      taskId: taskId,
    );
    return executionMaps.map(_mapToExecution).toList();
  }
  
  @override
  Stream<List<TaskExecution>> watchExecutionsByTaskId(String taskId) async* {
    while (true) {
      yield await getExecutionsByTaskId(taskId);
      await Future.delayed(const Duration(seconds: 1));
    }
  }
  
  @override
  Future<void> deleteExecution(String id) async {
    await _dataSource.deleteExecution(id);
  }
  
  @override
  Future<TaskExecution?> getTodayExecution(String taskId) async {
    final executionMap = await _dataSource.getTodayExecution(taskId);
    return executionMap != null ? _mapToExecution(executionMap) : null;
  }
  
  @override
  Future<Map<DateTime, int>> getExecutionCountByDate({
    required DateTime startDate,
    required DateTime endDate,
    String? taskId,
  }) async {
    final executions = await getExecutionsByDateRange(
      startDate: startDate,
      endDate: endDate,
      taskId: taskId,
    );
    
    final Map<DateTime, int> countMap = {};
    for (final execution in executions) {
      final date = DateTime(
        execution.executedAt.year,
        execution.executedAt.month,
        execution.executedAt.day,
      );
      countMap[date] = (countMap[date] ?? 0) + 1;
    }
    
    return countMap;
  }
  
  Map<String, dynamic> _executionToMap(TaskExecution execution) {
    return {
      'id': execution.id,
      'task_id': execution.taskId,
      'executed_at': execution.executedAt.millisecondsSinceEpoch,
      'created_at': execution.createdAt.millisecondsSinceEpoch,
    };
  }
  
  TaskExecution _mapToExecution(Map<String, dynamic> map) {
    return TaskExecution(
      id: map['id'] as String,
      taskId: map['task_id'] as String,
      executedAt: DateTime.fromMillisecondsSinceEpoch(
        map['executed_at'] as int,
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['created_at'] as int,
      ),
    );
  }
}
```

---

## 6. アプリケーション層設計

### 6.1 Riverpod Providers

#### 6.1.1 基本Providers

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'providers.g.dart';

// DatabaseHelper Provider
@riverpod
DatabaseHelper databaseHelper(DatabaseHelperRef ref) {
  return DatabaseHelper.instance;
}

// DataSource Providers
@riverpod
TaskLocalDataSource taskLocalDataSource(TaskLocalDataSourceRef ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  return TaskLocalDataSource(dbHelper);
}

@riverpod
TaskExecutionLocalDataSource taskExecutionLocalDataSource(
  TaskExecutionLocalDataSourceRef ref,
) {
  final dbHelper = ref.watch(databaseHelperProvider);
  return TaskExecutionLocalDataSource(dbHelper);
}

// Repository Providers
@riverpod
TaskRepository taskRepository(TaskRepositoryRef ref) {
  final dataSource = ref.watch(taskLocalDataSourceProvider);
  return TaskRepositoryImpl(dataSource);
}

@riverpod
TaskExecutionRepository taskExecutionRepository(
  TaskExecutionRepositoryRef ref,
) {
  final dataSource = ref.watch(taskExecutionLocalDataSourceProvider);
  return TaskExecutionRepositoryImpl(dataSource);
}
```

#### 6.1.2 タスク関連Providers

```dart
// タスク一覧のStreamProvider
@riverpod
Stream<List<Task>> taskList(TaskListRef ref) {
  final repository = ref.watch(taskRepositoryProvider);
  return repository.watchAllTasks();
}

// 特定タスクのProvider
@riverpod
Future<Task?> task(TaskRef ref, String taskId) async {
  final repository = ref.watch(taskRepositoryProvider);
  return await repository.getTaskById(taskId);
}

// タスクCRUD用Notifier
@riverpod
class TaskNotifier extends _$TaskNotifier {
  @override
  FutureOr<void> build() {}
  
  Future<void> createTask({
    required String name,
    required String color,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(taskRepositoryProvider);
      final task = TaskExtension.create(name: name, color: color);
      await repository.createTask(task);
    });
  }
  
  Future<void> updateTask({
    required String id,
    String? name,
    String? color,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(taskRepositoryProvider);
      final task = await repository.getTaskById(id);
      if (task != null) {
        final updatedTask = task.update(name: name, color: color);
        await repository.updateTask(updatedTask);
      }
    });
  }
  
  Future<void> deleteTask(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(taskRepositoryProvider);
      await repository.deleteTask(id);
    });
  }
}
```

#### 6.1.3 実行記録関連Providers

```dart
// タスク実行記録のStreamProvider
@riverpod
Stream<List<TaskExecution>> taskExecutionList(
  TaskExecutionListRef ref,
  String taskId,
) {
  final repository = ref.watch(taskExecutionRepositoryProvider);
  return repository.watchExecutionsByTaskId(taskId);
}

// 実行記録CRUD用Notifier
@riverpod
class TaskExecutionNotifier extends _$TaskExecutionNotifier {
  @override
  FutureOr<void> build() {}
  
  Future<void> addExecution({
    required String taskId,
    DateTime? executedAt,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(taskExecutionRepositoryProvider);
      
      // 当日の実行記録がすでに存在するかチェック
      final todayExecution = await repository.getTodayExecution(taskId);
      if (todayExecution != null) {
        throw Exception('今日はすでに実行済みです');
      }
      
      final execution = TaskExecutionExtension.create(
        taskId: taskId,
        executedAt: executedAt,
      );
      await repository.createExecution(execution);
    });
  }
  
  Future<void> removeExecution(String executionId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(taskExecutionRepositoryProvider);
      await repository.deleteExecution(executionId);
    });
  }
  
  Future<bool> canExecuteToday(String taskId) async {
    final repository = ref.read(taskExecutionRepositoryProvider);
    final todayExecution = await repository.getTodayExecution(taskId);
    return todayExecution == null;
  }
}
```

#### 6.1.4 カレンダー関連Providers

```dart
// カレンダー表示用データProvider
@riverpod
class CalendarData extends _$CalendarData {
  @override
  Future<Map<DateTime, int>> build({
    required DateTime startDate,
    required DateTime endDate,
    String? taskId,
  }) async {
    final repository = ref.watch(taskExecutionRepositoryProvider);
    return await repository.getExecutionCountByDate(
      startDate: startDate,
      endDate: endDate,
      taskId: taskId,
    );
  }
  
  // 期間を変更して再読み込み
  Future<void> changeDateRange({
    required DateTime startDate,
    required DateTime endDate,
    String? taskId,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(taskExecutionRepositoryProvider);
      return await repository.getExecutionCountByDate(
        startDate: startDate,
        endDate: endDate,
        taskId: taskId,
      );
    });
  }
}
```

---

## 7. プレゼンテーション層設計

### 7.1 画面一覧

1. **ホーム画面** (`home_screen.dart`)
2. **カレンダー画面** (`calendar_screen.dart`)
3. **タスク登録・編集画面** (`task_form_screen.dart`)
4. **タスク詳細画面** (`task_detail_screen.dart`)

### 7.2 共通ウィジェット

#### 7.2.1 タスクカードウィジェット

```dart
class TaskCard extends ConsumerWidget {
  final Task task;
  final VoidCallback onTap;
  final VoidCallback onExecute;
  
  const TaskCard({
    super.key,
    required this.task,
    required this.onTap,
    required this.onExecute,
  });
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Color(int.parse(task.color.replaceFirst('#', '0xff'))),
            shape: BoxShape.circle,
          ),
        ),
        title: Text(task.name),
        subtitle: Text(
          '作成日: ${DateFormat('yyyy/MM/dd').format(task.createdAt)}',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.check_circle_outline),
          onPressed: onExecute,
        ),
        onTap: onTap,
      ),
    );
  }
}
```

#### 7.2.2 Contributionカレンダーウィジェット

```dart
class ContributionCalendar extends StatelessWidget {
  final Map<DateTime, int> executionData;
  final Color taskColor;
  final DateTime startDate;
  final DateTime endDate;
  
  const ContributionCalendar({
    super.key,
    required this.executionData,
    required this.taskColor,
    required this.startDate,
    required this.endDate,
  });
  
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7, // 1週間
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: _calculateDayCount(),
      itemBuilder: (context, index) {
        final date = startDate.add(Duration(days: index));
        final count = executionData[_normalizeDate(date)] ?? 0;
        
        return GestureDetector(
          onTap: () => _showDayDetail(context, date, count),
          child: Container(
            decoration: BoxDecoration(
              color: _getColorForCount(count),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 10,
                  color: count > 0 ? Colors.white : Colors.black54,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  int _calculateDayCount() {
    return endDate.difference(startDate).inDays + 1;
  }
  
  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
  
  Color _getColorForCount(int count) {
    if (count == 0) return Colors.grey[300]!;
    if (count == 1) return taskColor.withOpacity(0.3);
    if (count == 2) return taskColor.withOpacity(0.6);
    return taskColor;
  }
  
  void _showDayDetail(BuildContext context, DateTime date, int count) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(DateFormat('yyyy年M月d日').format(date)),
        content: Text('実行回数: $count回'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }
}
```

---

## 8. 画面仕様

### 8.1 ホーム画面

#### レイアウト構成
- AppBar: タイトル「Habit Tracker」
- Body: タスク一覧（ListView）
- FAB: タスク追加ボタン
- BottomNavigationBar: タスク一覧/カレンダー切り替え

#### 主要機能
1. タスク一覧表示（作成日順）
2. タスククイック実行
3. タスク詳細への遷移

#### 実装例

```dart
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskListAsync = ref.watch(taskListProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Habit Tracker'),
      ),
      body: taskListAsync.when(
        data: (tasks) {
          if (tasks.isEmpty) {
            return const Center(
              child: Text('タスクがありません\n右下のボタンから追加してください'),
            );
          }
          
          return ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return TaskCard(
                task: task,
                onTap: () => _navigateToDetail(context, task.id),
                onExecute: () => _executeTask(ref, task.id),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('エラー: $error')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToForm(context),
        child: const Icon(Icons.add),
      ),
    );
  }
  
  void _navigateToDetail(BuildContext context, String taskId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskDetailScreen(taskId: taskId),
      ),
    );
  }
  
  void _navigateToForm(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TaskFormScreen(),
      ),
    );
  }
  
  Future<void> _executeTask(WidgetRef ref, String taskId) async {
    final notifier = ref.read(taskExecutionNotifierProvider.notifier);
    final canExecute = await notifier.canExecuteToday(taskId);
    
    if (!canExecute) {
      // エラーメッセージ表示
      return;
    }
    
    await notifier.addExecution(taskId: taskId);
  }
}
```

### 8.2 カレンダー画面

#### レイアウト構成
- AppBar: タイトル「カレンダー」、期間選択ボタン
- タスク選択ドロップダウン
- Contributionカレンダー
- 統計情報表示エリア

#### 主要機能
1. 期間切り替え（1ヶ月/3ヶ月/6ヶ月/1年）
2. タスク別/全体の切り替え
3. 日付タップで詳細表示

#### 実装例

```dart
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});
  
  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  String? _selectedTaskId;
  int _monthRange = 3; // デフォルト3ヶ月
  
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month - _monthRange, now.day);
    final endDate = now;
    
    final calendarDataAsync = ref.watch(
      calendarDataProvider(
        startDate: startDate,
        endDate: endDate,
        taskId: _selectedTaskId,
      ),
    );
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('カレンダー'),
        actions: [
          PopupMenuButton<int>(
            initialValue: _monthRange,
            onSelected: (value) {
              setState(() => _monthRange = value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 1, child: Text('1ヶ月')),
              const PopupMenuItem(value: 3, child: Text('3ヶ月')),
              const PopupMenuItem(value: 6, child: Text('6ヶ月')),
              const PopupMenuItem(value: 12, child: Text('1年')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTaskSelector(),
          Expanded(
            child: calendarDataAsync.when(
              data: (data) => ContributionCalendar(
                executionData: data,
                taskColor: _getTaskColor(),
                startDate: startDate,
                endDate: endDate,
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('エラー: $error')),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTaskSelector() {
    final taskListAsync = ref.watch(taskListProvider);
    
    return taskListAsync.when(
      data: (tasks) => DropdownButton<String?>(
        value: _selectedTaskId,
        hint: const Text('タスクを選択'),
        items: [
          const DropdownMenuItem(value: null, child: Text('全体')),
          ...tasks.map((task) => DropdownMenuItem(
            value: task.id,
            child: Text(task.name),
          )),
        ],
        onChanged: (value) {
          setState(() => _selectedTaskId = value);
        },
      ),
      loading: () => const CircularProgressIndicator(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
  
  Color _getTaskColor() {
    // タスクの色を取得（選択されていない場合はデフォルト色）
    return Colors.blue;
  }
}
```

### 8.3 タスク登録・編集画面

#### レイアウト構成
- AppBar: タイトル「タスク追加」or「タスク編集」
- Body: フォーム
  - タスク名入力フィールド
  - カラーピッカー
  - 保存ボタン

#### バリデーション
- タスク名: 必須、1〜255文字

#### 実装例

```dart
class TaskFormScreen extends ConsumerStatefulWidget {
  final String? taskId; // 編集時のみ指定
  
  const TaskFormScreen({super.key, this.taskId});
  
  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  Color _selectedColor = Colors.blue;
  
  @override
  void initState() {
    super.initState();
    _loadTask();
  }
  
  Future<void> _loadTask() async {
    if (widget.taskId != null) {
      final task = await ref.read(taskProvider(widget.taskId!).future);
      if (task != null) {
        _nameController.text = task.name;
        _selectedColor = Color(
          int.parse(task.color.replaceFirst('#', '0xff')),
        );
        setState(() {});
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final isEdit = widget.taskId != null;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'タスク編集' : 'タスク追加'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'タスク名',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'タスク名を入力してください';
                  }
                  if (value.length > 255) {
                    return 'タスク名は255文字以内で入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              const Text('カラー選択'),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _showColorPicker,
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: _selectedColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey),
                  ),
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _saveTask,
                child: const Text('保存'),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('カラー選択'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _selectedColor,
            onColorChanged: (color) {
              setState(() => _selectedColor = color);
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('完了'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) return;
    
    final notifier = ref.read(taskNotifierProvider.notifier);
    final colorHex = '#${_selectedColor.value.toRadixString(16).substring(2)}';
    
    if (widget.taskId != null) {
      await notifier.updateTask(
        id: widget.taskId!,
        name: _nameController.text,
        color: colorHex,
      );
    } else {
      await notifier.createTask(
        name: _nameController.text,
        color: colorHex,
      );
    }
    
    if (mounted) {
      Navigator.pop(context);
    }
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
```

### 8.4 タスク詳細画面

#### レイアウト構成
- AppBar: タイトル（タスク名）、編集・削除ボタン
- Body:
  - タスク情報カード
  - 実行履歴リスト

#### 主要機能
1. タスク情報表示
2. 実行履歴表示（日付降順）
3. 編集画面への遷移
4. タスク削除（確認ダイアログ表示）

---

## 9. カレンダー表示ロジック

### 9.1 色の濃淡計算

```dart
class CalendarColorCalculator {
  static Color getColorForCount(int count, Color baseColor) {
    if (count == 0) {
      return Colors.grey[300]!;
    } else if (count == 1) {
      return baseColor.withOpacity(0.3);
    } else if (count == 2) {
      return baseColor.withOpacity(0.6);
    } else {
      return baseColor;
    }
  }
}
```

### 9.2 日付正規化

```dart
extension DateTimeExtension on DateTime {
  DateTime get normalized {
    return DateTime(year, month, day);
  }
  
  bool isSameDay(DateTime other) {
    return year == other.year && 
           month == other.month && 
           day == other.day;
  }
}
```

### 9.3 期間計算

```dart
class DateRangeCalculator {
  static DateTime getStartDate(int monthsAgo) {
    final now = DateTime.now();
    return DateTime(now.year, now.month - monthsAgo, now.day);
  }
  
  static int getDayCount(DateTime start, DateTime end) {
    return end.difference(start).inDays + 1;
  }
}
```

---

## 10. エラーハンドリング

### 10.1 エラー種別

1. **データベースエラー**: SQLiteの操作失敗
2. **バリデーションエラー**: 入力値の検証失敗
3. **ビジネスロジックエラー**: 重複実行など

### 10.2 エラー表示

```dart
void showErrorSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 3),
    ),
  );
}

void showSuccessSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 2),
    ),
  );
}
```

### 10.3 AsyncValueのエラーハンドリング

```dart
ref.listen(taskNotifierProvider, (previous, next) {
  next.whenOrNull(
    error: (error, stackTrace) {
      showErrorSnackBar(context, error.toString());
    },
  );
});
```

---

## 11. パフォーマンス最適化

### 11.1 データベースクエリ最適化

- 必要なカラムのみをSELECT
- インデックスの適切な使用
- WHERE句による絞り込み
- トランザクションのバッチ処理

### 11.2 ウィジェット最適化

- const constructorの使用
- 不要な再ビルドの防止
- ListView.builderの使用（大量データ対応）

### 11.3 Riverpod最適化

- Providerの適切な粒度
- autoDisposeの活用
- select()による部分購読

```dart
final taskName = ref.watch(
  taskProvider(taskId).select((task) => task?.name),
);
```

---

## 12. テスト方針

### 12.1 単体テスト対象
- Entity
- Repository（モック使用）
- ビジネスロジック

### 12.2 ウィジェットテスト対象
- 各画面のレンダリング
- ユーザーインタラクション
- エラー状態の表示

### 12.3 統合テスト対象
- 画面遷移フロー
- CRUD操作の一連の流れ

---

## 付録A: ファイル構成

```
lib/
├── main.dart
├── app.dart
├── presentation/
│   ├── screens/
│   │   ├── home/
│   │   │   ├── home_screen.dart
│   │   │   └── widgets/
│   │   │       └── task_card.dart
│   │   ├── calendar/
│   │   │   ├── calendar_screen.dart
│   │   │   └── widgets/
│   │   │       └── contribution_calendar.dart
│   │   ├── task_form/
│   │   │   └── task_form_screen.dart
│   │   └── task_detail/
│   │       └── task_detail_screen.dart
│   └── widgets/
│       └── loading_indicator.dart
├── application/
│   ├── providers/
│   │   ├── providers.dart
│   │   ├── providers.g.dart
│   │   ├── task_provider.dart
│   │   ├── task_provider.g.dart
│   │   ├── task_execution_provider.dart
│   │   └── task_execution_provider.g.dart
│   └── state/
│       └── calendar_state.dart
├── domain/
│   ├── entities/
│   │   ├── task.dart
│   │   ├── task.freezed.dart
│   │   ├── task.g.dart
│   │   ├── task_execution.dart
│   │   ├── task_execution.freezed.dart
│   │   └── task_execution.g.dart
│   └── repositories/
│       ├── task_repository.dart
│       └── task_execution_repository.dart
├── infrastructure/
│   ├── database/
│   │   ├── database_helper.dart
│   │   └── database_constants.dart
│   ├── datasources/
│   │   ├── task_local_datasource.dart
│   │   └── task_execution_local_datasource.dart
│   └── repositories/
│       ├── task_repository_impl.dart
│       └── task_execution_repository_impl.dart
└── utils/
    ├── constants.dart
    ├── extensions/
    │   └── datetime_extension.dart
    └── helpers/
        ├── color_calculator.dart
        └── date_range_calculator.dart
```

---

以上が習慣化アプリの詳細設計書となります。