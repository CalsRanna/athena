import 'dart:convert';

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
    List<String> argsList = [];
    if (json['arguments'] != null) {
      if (json['arguments'] is String) {
        try {
          argsList = List<String>.from(jsonDecode(json['arguments'] as String));
        } catch (e) {
          argsList = [];
        }
      } else if (json['arguments'] is List) {
        argsList = List<String>.from(json['arguments']);
      }
    }

    Map<String, String> envMap = {};
    if (json['environment_variables'] != null) {
      if (json['environment_variables'] is String) {
        try {
          var decoded = jsonDecode(json['environment_variables'] as String);
          envMap = Map<String, String>.from(decoded);
        } catch (e) {
          envMap = {};
        }
      } else if (json['environment_variables'] is Map) {
        envMap = Map<String, String>.from(json['environment_variables']);
      }
    }

    List<String> toolsList = [];
    if (json['tools'] != null) {
      if (json['tools'] is String) {
        try {
          toolsList = List<String>.from(jsonDecode(json['tools'] as String));
        } catch (e) {
          toolsList = [];
        }
      } else if (json['tools'] is List) {
        toolsList = List<String>.from(json['tools']);
      }
    }

    return ServerEntity(
      id: json['id'] as int?,
      name: json['name'] as String? ?? '',
      command: json['command'] as String? ?? '',
      arguments: argsList,
      environmentVariables: envMap,
      enabled: (json['enabled'] as int?) == 1,
      description: json['description'] as String? ?? '',
      tools: toolsList,
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
