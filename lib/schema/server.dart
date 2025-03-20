import 'package:isar/isar.dart';

part 'server.g.dart';

@collection
@Name('servers')
class Server {
  Id id = Isar.autoIncrement;
  String arguments = ''; //List<String>.join(' ')
  String command = '';
  String description = '';
  String environments = ''; //json.encode(Map<String, String>)
  String name = '';

  Server();

  Server copyWith({
    int? id,
    String? arguments,
    String? command,
    String? description,
    String? environments,
    String? name,
  }) {
    return Server()
      ..id = id ?? this.id
      ..arguments = arguments ?? this.arguments
      ..command = command ?? this.command
      ..description = description ?? this.description
      ..environments = environments ?? this.environments
      ..name = name ?? this.name;
  }
}
