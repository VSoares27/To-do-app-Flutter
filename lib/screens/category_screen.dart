import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../state/app_state.dart';

const _palette = [
  0xFF4F46E5,
  0xFF0EA5E9,
  0xFF16A34A,
  0xFFF59E0B,
  0xFFDC2626,
  0xFF9333EA,
];

class CategoryScreen extends StatelessWidget {
  const CategoryScreen({super.key});

  Future<void> _edit(BuildContext context, {Category? category}) async {
    final ctrl = TextEditingController(text: category?.name ?? '');
    int color = category?.color ?? _palette.first;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          title: Text(category == null ? 'New category' : 'Rename category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  for (final c in _palette)
                    GestureDetector(
                      onTap: () => setInner(() => color = c),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: color == c ? Colors.black : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );

    if (result != true) return;
    final name = ctrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Category name is required.')));
      return;
    }
    final state = context.read<AppState>();
    if (category == null) {
      await state.addCategory(name, color);
    } else {
      await state.renameCategory(category.copyWith(color: color), name);
    }
  }

  Future<void> _delete(BuildContext context, Category category) async {
    final state = context.read<AppState>();
    final count = await state.categoryTaskCount(category.id ?? -1);
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${category.name}"?'),
        content: Text(count == 0
            ? 'No tasks use this category.'
            : '$count task(s) use it and will become uncategorized.'),
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
    await state.deleteCategory(category);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(context),
        child: const Icon(Icons.add),
      ),
      body: state.categories.isEmpty
          ? const Center(child: Text('No categories yet.'))
          : ListView.separated(
              itemCount: state.categories.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final c = state.categories[i];
                return ListTile(
                  leading: CircleAvatar(backgroundColor: Color(c.color), radius: 10),
                  title: Text(c.name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _edit(context, category: c),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _delete(context, c),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
