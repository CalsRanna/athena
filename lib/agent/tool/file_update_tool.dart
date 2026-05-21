import 'dart:io';

import 'tool_interface.dart';

class FileUpdateTool implements Tool {
  @override
  String get name => 'file_update';

  @override
  String get description => 'Replace a string in a file. '
      'Finds the first occurrence of old_string and replaces it with new_string. '
      'Use when you need to modify a specific section of an existing file. '
      'For creating or overwriting an entire file, use file_write instead.';

  @override
  DangerLevel get dangerLevel => DangerLevel.needsApproval;

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'path': {
            'type': 'string',
            'description': 'The path to the file to update.',
          },
          'old_string': {
            'type': 'string',
            'description': 'The exact text to find and replace. '
                'Must match exactly including whitespace and indentation. '
                'Only the first occurrence is replaced.',
          },
          'new_string': {
            'type': 'string',
            'description': 'The text to replace it with.',
          },
        },
        'required': ['path', 'old_string', 'new_string'],
      };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final path = args['path'] as String;
    final oldString = args['old_string'] as String;
    final newString = args['new_string'] as String;

    final file = File(path);
    if (!await file.exists()) {
      return 'Error: File not found: $path';
    }

    final content = await file.readAsString();
    final index = content.indexOf(oldString);
    if (index == -1) {
      return 'Error: old_string not found in file. '
          'Make sure the string matches exactly, including whitespace.';
    }

    final updated =
        '${content.substring(0, index)}$newString${content.substring(index + oldString.length)}';
    await file.writeAsString(updated);

    return 'Successfully updated $path';
  }
}
