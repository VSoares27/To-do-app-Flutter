/// Task model.
///
/// Extra fields beyond the spec:
/// - [notificationId]: stable int id used by flutter_local_notifications so we
///   can cancel/reschedule a reminder for this specific task.
class Task {
  final int? id;
  final String title;
  final String description;
  final bool completed;
  final DateTime? dueDateTime;
  final DateTime createdAt;
  final int? categoryId;
  final int? notificationId;

  const Task({
    this.id,
    required this.title,
    this.description = '',
    this.completed = false,
    this.dueDateTime,
    required this.createdAt,
    this.categoryId,
    this.notificationId,
  });

  Task copyWith({
    int? id,
    String? title,
    String? description,
    bool? completed,
    DateTime? dueDateTime,
    bool clearDueDateTime = false,
    DateTime? createdAt,
    int? categoryId,
    bool clearCategory = false,
    int? notificationId,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      completed: completed ?? this.completed,
      dueDateTime:
          clearDueDateTime ? null : (dueDateTime ?? this.dueDateTime),
      createdAt: createdAt ?? this.createdAt,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      notificationId: notificationId ?? this.notificationId,
    );
  }

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'title': title,
        'description': description,
        'completed': completed ? 1 : 0,
        'due_date_time': dueDateTime?.millisecondsSinceEpoch,
        'created_at': createdAt.millisecondsSinceEpoch,
        'category_id': categoryId,
        'notification_id': notificationId,
      };

  factory Task.fromMap(Map<String, Object?> map) => Task(
        id: map['id'] as int?,
        title: (map['title'] as String?) ?? '',
        description: (map['description'] as String?) ?? '',
        completed: (map['completed'] as int? ?? 0) == 1,
        dueDateTime: map['due_date_time'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                map['due_date_time'] as int),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (map['created_at'] as int?) ??
                DateTime.now().millisecondsSinceEpoch),
        categoryId: map['category_id'] as int?,
        notificationId: map['notification_id'] as int?,
      );
}
