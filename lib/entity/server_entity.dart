import 'dart:convert';

import 'package:athena/extension/json_map_extension.dart';

class ServerEntity {
  final int? id;
  final String name;
  final String command;
  final List<String> arguments;
  final Map<String, String> environmentVariables;
  final bool enabled;
  final String description;
  final List<String> tools;

  ServerEntity({
    this.id,
    required this.name,
    required this.command,
    this.arguments = const [],
    this.environmentVariables = const {},
    this.enabled = true,
    this.description = '',
    this.tools = const [],
  });

  factory ServerEntity.fromJson(Map<String, dynamic> json) {
    return ServerEntity(
      id: json.getIntOrNull('id'),
      name: json.getString('name'),
      command: json.getString('command'),
      arguments: json.getList<String>('arguments'),
      environmentVariables: json.getMap<String, String>('environment_variables'),
      enabled: json.getBool('enabled', defaultValue: true),
      description: json.getString('description'),
      tools: json.getList<String>('tools'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'command': command,
      'arguments': jsonEncode(arguments),
      'environment_variables': jsonEncode(environmentVariables),
      'enabled': enabled ? 1 : 0,
      'description': description,
      'tools': jsonEncode(tools),
    };
  }

  ServerEntity copyWith({
    int? id,
    String? name,
    String? command,
    List<String>? arguments,
    Map<String, String>? environmentVariables,
    bool? enabled,
    String? description,
    List<String>? tools,
  }) {
    return ServerEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      command: command ?? this.command,
      arguments: arguments ?? this.arguments,
      environmentVariables: environmentVariables ?? this.environmentVariables,
      enabled: enabled ?? this.enabled,
      description: description ?? this.description,
      tools: tools ?? this.tools,
    );
  }
}
