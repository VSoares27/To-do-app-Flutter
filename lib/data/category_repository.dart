import '../models/category.dart';
import 'app_database.dart';

class CategoryRepository {
  Future<List<Category>> fetchAll() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('categories', orderBy: 'name COLLATE NOCASE ASC');
    return rows.map(Category.fromMap).toList();
  }

  Future<int> insert(Category category) async {
    final db = await AppDatabase.instance.database;
    return db.insert('categories', category.toMap());
  }

  Future<void> update(Category category) async {
    final db = await AppDatabase.instance.database;
    await db.update('categories', category.toMap(),
        where: 'id = ?', whereArgs: [category.id]);
  }

  /// Deleting a category keeps its tasks: the FK is ON DELETE SET NULL, so the
  /// tasks simply become uncategorized.
  Future<void> delete(int id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> taskCount(int categoryId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM tasks WHERE category_id = ?', [categoryId]);
    return (rows.first['c'] as int?) ?? 0;
  }
}
