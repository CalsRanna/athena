import 'dart:io';

import 'tool_interface.dart';

class FileWriteTool implements Tool {

  FileWriteTool();

  @override
  String get name => 'file_write';

  @override
  String get description => 'Write content to a file. Creates the file if it '
      'does not exist, overwrites it if it does. '
      'Use when you need to create or update a file.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'path': {
            'type': 'string',
            'description': 'The path to the file to write.',
          },
          'content': {
            'type': 'string',
            'description': 'The content to write to the file.',
          },
        },
        'required': ['path', 'content'],
      };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final path = args['path'] as String;
    final content = args['content'] as String;

    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(content);

    return 'Successfully wrote ${content.length} bytes to $path';
  }
}
