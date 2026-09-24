import 'package:flutter/material.dart' hide Category;

import '../data/category_repository.dart';
import '../data/task_repository.dart';
import '../models/category.dart';
import '../models/task.dart';
import '../services/notification_service.dart';

/// Single ChangeNotifier holding tasks, categories and the active filters.
/// Provider + ChangeNotifier keeps state management simple for a small app:
/// every mutation writes to SQLite first, then reloads and notifies listeners.
class AppState extends ChangeNotifier {
  AppState({
    TaskRepository? tasks,
    CategoryRepository? categories,
  })  : _taskRepo = tasks ?? TaskRepository(),
        _categoryRepo = categories ?? CategoryRepository();

  final TaskRepository _taskRepo;
  final CategoryRepository _categoryRepo;

  List<Task> _tasks = const [];
  List<Category> _categories = const [];
  StatusFilter _status = StatusFilter.all;
  int? _categoryFilter;
  bool _loading = true;
  String? _error;

  List<Task> get tasks => _tasks;
  List<Category> get categories => _categories;
  StatusFilter get status => _status;
  int? get categoryFilter => _categoryFilter;
  bool get loading => _loading;
  String? get error => _error;

  Category? categoryById(int? id) {
    if (id == null) return null;
    for (final c in _categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    await _guard(() async {
      _categories = await _categoryRepo.fetchAll();
      _tasks = await _taskRepo.fetch(
          status: _status, categoryId: _categoryFilter);
    });
    _loading = false;
    notifyListeners();
  }

  Future<void> _reloadTasks() async {
    await _guard(() async {
      _tasks = await _taskRepo.fetch(
          status: _status, categoryId: _categoryFilter);
    });
    notifyListeners();
  }

  Future<void> _guard(Future<void> Function() body) async {
    try {
      await body();
      _error = null;
    } catch (e) {
      _error = 'Database error: $e';
      debugPrint(_error);
    }
  }

  void setStatusFilter(StatusFilter value) {
    _status = value;
    _reloadTasks();
  }

  /// A category filter of null means "All categories".
  void setCategoryFilter(int? categoryId) {
    _categoryFilter = categoryId;
    _reloadTasks();
  }

  // ---------------- Tasks ----------------

  Future<void> saveTask(Task task) async {
    await _guard(() async {
      if (task.id == null) {
        final id = await _taskRepo.insert(task);
        final saved = task.copyWith(id: id, notificationId: id);
        await NotificationService.instance.sync(saved);
      } else {
        await _taskRepo.update(task);
        await NotificationService.instance.sync(task);
      }
    });
    await _reloadTasks();
  }

  Future<void> toggleCompleted(Task task) async {
    final updated = task.copyWith(completed: !task.completed);
    await _guard(() async {
      await _taskRepo.update(updated);
      // sync() cancels when completed, re-schedules when reopened and the due
      // date is still in the future.
      await NotificationService.instance.sync(updated);
    });
    await _reloadTasks();
  }

  Future<void> deleteTask(Task task) async {
    await _guard(() async {
      if (task.id != null) await _taskRepo.delete(task.id!);
      final nid = task.notificationId ?? task.id;
      if (nid != null) await NotificationService.instance.cancel(nid);
    });
    await _reloadTasks();
  }

  // ---------------- Categories ----------------

  Future<void> addCategory(String name, int color) async {
    await _guard(() async {
      await _categoryRepo.insert(Category(name: name.trim(), color: color));
      _categories = await _categoryRepo.fetchAll();
    });
    notifyListeners();
  }

  Future<void> renameCategory(Category category, String name) async {
    await _guard(() async {
      await _categoryRepo.update(category.copyWith(name: name.trim()));
      _categories = await _categoryRepo.fetchAll();
    });
    await _reloadTasks();
  }

  Future<int> categoryTaskCount(int categoryId) =>
      _categoryRepo.taskCount(categoryId);

  /// Tasks that used the category become uncategorized (FK SET NULL).
  Future<void> deleteCategory(Category category) async {
    await _guard(() async {
      if (category.id == null) return;
      await _categoryRepo.delete(category.id!);
      if (_categoryFilter == category.id) _categoryFilter = null;
      _categories = await _categoryRepo.fetchAll();
    });
    await _reloadTasks();
  }
}
