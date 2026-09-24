import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/task_repository.dart';
import '../models/task.dart';
import '../state/app_state.dart';

/// Create or edit a task. Only the task id is passed in; the row is loaded
/// from SQLite here so the form always shows fresh values.
class TaskEditorScreen extends StatefulWidget {
  const TaskEditorScreen({super.key, this.taskId});
  final int? taskId;

  @override
  State<TaskEditorScreen> createState() => _TaskEditorScreenState();
}

class _TaskEditorScreenState extends State<TaskEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _repo = TaskRepository();

  bool _loading = true;
  bool _completed = false;
  int? _categoryId;
  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  Task? _existing;

  @override
  void initState() {
    super.initState();
    _loadTask();
  }

  Future<void> _loadTask() async {
    if (widget.taskId == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final task = await _repo.findById(widget.taskId!);
      if (task != null) {
        _existing = task;
        _titleCtrl.text = task.title;
        _descCtrl.text = task.description;
        _completed = task.completed;
        _categoryId = task.categoryId;
        final due = task.dueDateTime;
        if (due != null) {
          _dueDate = DateTime(due.year, due.month, due.day);
          _dueTime = TimeOfDay(hour: due.hour, minute: due.minute);
        }
      }
    } catch (e) {
      if (mounted) _snack('Could not load the task: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  DateTime? get _dueDateTime {
    if (_dueDate == null) return null;
    final t = _dueTime ?? const TimeOfDay(hour: 9, minute: 0);
    return DateTime(_dueDate!.year, _dueDate!.month, _dueDate!.day, t.hour, t.minute);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dueTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) setState(() => _dueTime = picked);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final state = context.read<AppState>();
    final task = (_existing ??
            Task(title: '', createdAt: DateTime.now()))
        .copyWith(
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      completed: _completed,
      dueDateTime: _dueDateTime,
      clearDueDateTime: _dueDateTime == null,
      categoryId: _categoryId,
      clearCategory: _categoryId == null,
    );

    await state.saveTask(task);
    if (!mounted) return;
    if (state.error != null) {
      _snack(state.error!);
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    if (_existing == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete task?'),
        content: const Text('This also cancels its reminder.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    await context.read<AppState>().deleteTask(_existing!);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<AppState>().categories;
    final due = _dueDateTime;

    return Scaffold(
      appBar: AppBar(
        title: Text(_existing == null ? 'New task' : 'Edit task'),
        actions: [
          if (_existing != null)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Title *', border: OutlineInputBorder()),
                    textInputAction: TextInputAction.next,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Title is required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descCtrl,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int?>(
                    value: _categoryId,
                    decoration: const InputDecoration(
                        labelText: 'Category (optional)',
                        border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem<int?>(
                          value: null, child: Text('No category')),
                      for (final c in categories)
                        DropdownMenuItem<int?>(value: c.id, child: Text(c.name)),
                    ],
                    onChanged: (v) => setState(() => _categoryId = v),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.event),
                          title: Text(_dueDate == null
                              ? 'No due date'
                              : DateFormat('dd/MM/yyyy').format(_dueDate!)),
                          trailing: TextButton(
                              onPressed: _pickDate, child: const Text('Pick')),
                        ),
                        ListTile(
                          leading: const Icon(Icons.schedule),
                          title: Text(_dueTime == null
                              ? 'No time (09:00 used if a date is set)'
                              : _dueTime!.format(context)),
                          trailing: TextButton(
                              onPressed: _pickTime, child: const Text('Pick')),
                        ),
                        if (_dueDate != null)
                          Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8, bottom: 8),
                              child: TextButton.icon(
                                onPressed: () => setState(() {
                                  _dueDate = null;
                                  _dueTime = null;
                                }),
                                icon: const Icon(Icons.clear),
                                label: const Text('Remove due date'),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (due != null && !due.isAfter(DateTime.now()))
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                          'This date is in the past, so no reminder will be scheduled.'),
                    ),
                  SwitchListTile(
                    value: _completed,
                    onChanged: (v) => setState(() => _completed = v),
                    title: const Text('Completed'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _save,
                          child: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
