import 'dart:io';

import 'package:athena/agent/permission/sandbox.dart';

import 'tool_interface.dart';

class FileReadTool implements Tool {
  final PathSandbox sandbox;

  FileReadTool({required this.sandbox});

  @override
  String get name => 'file_read';

  @override
  String get description => 'Read the contents of a file. '
      'Use when you need to examine a file\'s contents.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'path': {
            'type': 'string',
            'description': 'The path to the file to read.',
          },
          'offset': {
            'type': 'integer',
            'description': 'Line number to start reading from (0-indexed). '
                'Optional, defaults to 0.',
          },
          'limit': {
            'type': 'integer',
            'description': 'Maximum number of lines to read. Optional.',
          },
        },
        'required': ['path'],
      };

  @override
  DangerLevel get dangerLevel => DangerLevel.needsApproval;

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final path = args['path'] as String;
    final offset = args['offset'] as int? ?? 0;
    final limit = args['limit'] as int?;

    if (!sandbox.canRead(path)) {
      return 'Error: path "$path" is in a restricted system area and cannot be accessed.';
    }

    final file = File(path);
    if (!await file.exists()) {
      return 'Error: File not found: $path';
    }

    final lines = await file.readAsLines();
    final start = offset.clamp(0, lines.length);
    final end = limit != null
        ? (start + limit).clamp(start, lines.length)
        : lines.length;

    final selected = lines.sublist(start, end);
    final buffer = StringBuffer();
    for (var i = 0; i < selected.length; i++) {
      buffer.writeln('${start + i + 1}\t${selected[i]}');
    }
    return buffer.toString();
  }
}
