import 'package:isar/isar.dart';

part 'provider.g.dart';

@collection
@Name('providers')
class Provider {
  Id id = Isar.autoIncrement;
  bool enabled = false;
  @Name('is_preset')
  bool isPreset = false;
  String key = '';
  String name = '';
  String url = '';

  Provider();

  Provider.fromJson(Map<String, dynamic> json) {
    enabled = json['enabled'] ?? false;
    isPreset = json['is_preset'] ?? false;
    key = json['key'] ?? '';
    name = json['name'] ?? '';
    url = json['url'] ?? '';
  }

  Provider copyWith({
    int? id,
    bool? enabled,
    bool? isPreset,
    String? key,
    String? name,
    String? url,
  }) {
    return Provider()
      ..id = id ?? this.id
      ..enabled = enabled ?? this.enabled
      ..isPreset = isPreset ?? this.isPreset
      ..key = key ?? this.key
      ..name = name ?? this.name
      ..url = url ?? this.url;
  }
}
