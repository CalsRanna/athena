import 'package:isar/isar.dart';

part 'server.g.dart';

@collection
@Name('servers')
class Server {
  Id id = Isar.autoIncrement;
  String arguments = ''; //List<String>.join(' ')
  String command = '';
  String description = '';
  bool enabled = false;
  String environments = ''; //json.encode(Map<String, String>)
  String name = '';
  String tools = '';

  Server();

  Server copyWith({
    int? id,
    String? arguments,
    String? command,
    String? description,
    bool? enabled,
    String? environments,
    String? name,
    String? tools,
  }) {
    return Server()
      ..id = id ?? this.id
      ..arguments = arguments ?? this.arguments
      ..command = command ?? this.command
      ..description = description ?? this.description
      ..enabled = enabled ?? this.enabled
      ..environments = environments ?? this.environments
      ..name = name ?? this.name
      ..tools = tools ?? this.tools;
  }
}
