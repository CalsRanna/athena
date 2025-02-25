import 'package:isar/isar.dart';

part 'tool.g.dart';

@collection
@Name('tools')
class Tool {
  Id id = Isar.autoIncrement;
  String description = '';
  String key = '';
  String name = '';

  Tool();

  Tool.fromJson(Map<String, dynamic> json) {
    description = json['description'];
    name = json['name'];
  }

  Tool copyWith({
    int? id,
    String? description,
    String? key,
    String? name,
  }) {
    return Tool()
      ..id = id ?? this.id
      ..description = description ?? this.description
      ..key = key ?? this.key
      ..name = name ?? this.name;
  }
}
