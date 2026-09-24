import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/task_repository.dart';
import '../models/task.dart';
import '../services/notification_service.dart';
import '../state/app_state.dart';
import 'category_screen.dart';
import 'task_editor_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  @override
  void initState() {
    super.initState();
    // Ask for notification permission once, after the first frame. A denial is
    // only surfaced as a snackbar; the app keeps working without reminders.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final granted = await NotificationService.instance.requestPermission();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Notifications are disabled. Tasks still work, without reminders.'),
          ),
        );
      }
    });
  }

  Future<void> _openEditor(BuildContext context, {int? taskId}) async {
    // Navigation passes only the task id; the editor loads the row from SQLite.
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TaskEditorScreen(taskId: taskId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My tasks'),
        actions: [
          IconButton(
            tooltip: 'Categories',
            icon: const Icon(Icons.label_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CategoryScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('New task'),
      ),
      body: Column(
        children: [
          _StatusFilterBar(current: state.status),
          _CategoryFilterBar(state: state),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(state.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          const Divider(height: 1),
          Expanded(
            child: state.loading
                ? const Center(child: CircularProgressIndicator())
                : state.tasks.isEmpty
                    ? const Center(child: Text('No tasks here yet.'))
                    : ListView.separated(
                        itemCount: state.tasks.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final task = state.tasks[i];
                          return _TaskTile(
                            task: task,
                            onTap: () => _openEditor(context, taskId: task.id),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _StatusFilterBar extends StatelessWidget {
  const _StatusFilterBar({required this.current});
  final StatusFilter current;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: SegmentedButton<StatusFilter>(
        segments: const [
          ButtonSegment(value: StatusFilter.all, label: Text('All')),
          ButtonSegment(value: StatusFilter.pending, label: Text('Pending')),
          ButtonSegment(value: StatusFilter.completed, label: Text('Completed')),
        ],
        selected: {current},
        onSelectionChanged: (s) =>
            context.read<AppState>().setStatusFilter(s.first),
      ),
    );
  }
}

class _CategoryFilterBar extends StatelessWidget {
  const _CategoryFilterBar({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('All categories'),
              selected: state.categoryFilter == null,
              onSelected: (_) => context.read<AppState>().setCategoryFilter(null),
            ),
          ),
          for (final c in state.categories)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: CircleAvatar(backgroundColor: Color(c.color), radius: 7),
                label: Text(c.name),
                selected: state.categoryFilter == c.id,
                onSelected: (_) =>
                    context.read<AppState>().setCategoryFilter(c.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task, required this.onTap});
  final Task task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final category = state.categoryById(task.categoryId);
    final due = task.dueDateTime;
    final overdue = due != null && !task.completed && due.isBefore(DateTime.now());

    return ListTile(
      onTap: onTap,
      leading: Checkbox(
        value: task.completed,
        onChanged: (_) => state.toggleCompleted(task),
      ),
      title: Text(
        task.title,
        style: TextStyle(
          decoration: task.completed ? TextDecoration.lineThrough : null,
          color: task.completed ? Theme.of(context).disabledColor : null,
        ),
      ),
      subtitle: Wrap(
        spacing: 10,
        children: [
          Text(task.completed ? 'Completed' : 'Pending'),
          if (category != null)
            Text('• ${category.name}', style: TextStyle(color: Color(category.color))),
          if (due != null)
            Text(
              '• ${DateFormat('dd/MM/yyyy HH:mm').format(due)}',
              style: TextStyle(
                  color: overdue ? Theme.of(context).colorScheme.error : null),
            ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
