import 'package:isar/isar.dart';

part 'sentinel.g.dart';

@collection
@Name('sentinels')
class Sentinel {
  Id id = Isar.autoIncrement;
  String avatar = '';
  String name = '';
  String description = '';
  String prompt = '';
  List<String> tags = [];

  Sentinel();

  Sentinel copyWith({
    int? id,
    String? avatar,
    String? name,
    String? description,
    String? prompt,
    List<String>? tags,
  }) {
    return Sentinel()
      ..id = id ?? this.id
      ..avatar = avatar ?? this.avatar
      ..name = name ?? this.name
      ..description = description ?? this.description
      ..prompt = prompt ?? this.prompt
      ..tags = tags ?? this.tags;
  }
}
