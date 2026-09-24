import '../models/task.dart';
import 'app_database.dart';

/// Status filter used by the task list screen.
enum StatusFilter { all, pending, completed }

class TaskRepository {
  /// Filtering is done with SQL WHERE clauses so large lists stay cheap.
  Future<List<Task>> fetch({
    StatusFilter status = StatusFilter.all,
    int? categoryId,
  }) async {
    final db = await AppDatabase.instance.database;
    final where = <String>[];
    final args = <Object?>[];

    if (status == StatusFilter.pending) where.add('completed = 0');
    if (status == StatusFilter.completed) where.add('completed = 1');
    if (categoryId != null) {
      where.add('category_id = ?');
      args.add(categoryId);
    }

    final rows = await db.query(
      'tasks',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'completed ASC, '
          'CASE WHEN due_date_time IS NULL THEN 1 ELSE 0 END ASC, '
          'due_date_time ASC, created_at DESC',
    );
    return rows.map(Task.fromMap).toList();
  }

  Future<Task?> findById(int id) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('tasks', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Task.fromMap(rows.first);
  }

  Future<int> insert(Task task) async {
    final db = await AppDatabase.instance.database;
    final id = await db.insert('tasks', task.toMap());
    // notification_id mirrors the row id: stable and unique per task.
    await db.update('tasks', {'notification_id': id},
        where: 'id = ?', whereArgs: [id]);
    return id;
  }

  Future<void> update(Task task) async {
    final db = await AppDatabase.instance.database;
    await db.update('tasks', task.toMap(), where: 'id = ?', whereArgs: [task.id]);
  }

  Future<void> delete(int id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }
}
