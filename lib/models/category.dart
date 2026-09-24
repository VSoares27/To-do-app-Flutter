/// Category model. `color` is stored as an ARGB int so the list screen can
/// render a colored dot per category.
class Category {
  final int? id;
  final String name;
  final int color;

  const Category({this.id, required this.name, this.color = 0xFF4F46E5});

  Category copyWith({int? id, String? name, int? color}) => Category(
        id: id ?? this.id,
        name: name ?? this.name,
        color: color ?? this.color,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'color': color,
      };

  factory Category.fromMap(Map<String, Object?> map) => Category(
        id: map['id'] as int?,
        name: (map['name'] as String?) ?? '',
        color: (map['color'] as int?) ?? 0xFF4F46E5,
      );
}
