class McpTool {
  final String name;
  final String description;
  final McpToolInputSchema inputSchema;
  final List<String> required;

  McpTool({
    required this.name,
    required this.description,
    required this.inputSchema,
    this.required = const <String>[],
  });

  factory McpTool.fromJson(Map<String, dynamic> json) {
    List<String> required = [];
    if (json['required'] != null) {
      required = List<String>.from(json['required']);
    }
    return McpTool(
      name: json['name'],
      description: json['description'],
      inputSchema: McpToolInputSchema.fromJson(json['inputSchema']),
      required: required,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'inputSchema': inputSchema.toJson(),
      'required': required,
    };
  }

  @override
  String toString() {
    return toJson().toString();
  }
}

class McpToolInputSchema {
  final String type;
  final Map<String, McpToolProperty>? properties;

  McpToolInputSchema({required this.type, this.properties});

  factory McpToolInputSchema.fromJson(Map<String, dynamic> json) {
    Map<String, McpToolProperty>? properties;
    if (json['properties'] != null) {
      var propertiesJson = json['properties'] as Map<String, dynamic>;
      properties = propertiesJson.map(
        (key, value) => MapEntry(
          key,
          McpToolProperty.fromJson(value as Map<String, dynamic>),
        ),
      );
    }

    return McpToolInputSchema(type: json['type'], properties: properties);
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json.putIfAbsent('type', () => type);
    json.putIfAbsent('properties', () => properties ?? {});
    return json;
  }

  @override
  String toString() {
    return toJson().toString();
  }
}

class McpToolProperty {
  final String type;
  final String? description;

  McpToolProperty({required this.type, this.description});

  factory McpToolProperty.fromJson(Map<String, dynamic> json) {
    return McpToolProperty(
      type: json['type'],
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json.putIfAbsent('type', () => type);
    if (description != null) {
      json.putIfAbsent('description', () => description);
    }
    return json;
  }

  @override
  String toString() {
    return toJson().toString();
  }
}
