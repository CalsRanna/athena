import 'package:isar/isar.dart';

part 'provider.g.dart';

@collection
@Name('providers')
class Provider {
  Id id = Isar.autoIncrement;
  bool enabled = false;
  String key = '';
  String name = '';
  String url = '';

  Provider();

  Provider copyWith({bool? enabled, String? key, String? name, String? url}) {
    return Provider()
      ..id = id
      ..enabled = enabled ?? this.enabled
      ..key = key ?? this.key
      ..name = name ?? this.name
      ..url = url ?? this.url;
  }
}
