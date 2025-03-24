class McpServerOption {
  final String command;
  final List<String> args;
  final Map<String, String> env;
  final String author;

  const McpServerOption({
    required this.command,
    required this.args,
    this.env = const {},
    this.author = '',
  });

  factory McpServerOption.fromJson(Map<String, dynamic> json) {
    return McpServerOption(
      command: json['command']?.toString() ?? '',
      args: (json['args'] as List<dynamic>).cast<String>(),
      env:
          (json['env'] as Map<String, dynamic>?)?.cast<String, String>() ??
          const {},
    );
  }
}
