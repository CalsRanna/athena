import 'dart:io';

import 'package:athena/agent/permission/sandbox.dart';

import 'tool_interface.dart';

class FileDeleteTool implements Tool {
  final PathSandbox sandbox;

  FileDeleteTool({required this.sandbox});

  @override
  String get name => 'file_delete';

  @override
  String get description => 'Delete a file. '
      'Use with caution - this operation cannot be undone.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'path': {
            'type': 'string',
            'description': 'The path to the file to delete.',
          },
        },
        'required': ['path'],
      };

  @override
  DangerLevel get dangerLevel => DangerLevel.needsApproval;

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final path = args['path'] as String;

    if (!sandbox.canWrite(path)) {
      return 'Error: path "$path" is in a restricted system area and cannot be accessed.';
    }

    final file = File(path);
    if (!await file.exists()) {
      return 'Error: File not found: $path';
    }

    await file.delete();
    return 'Successfully deleted $path';
  }
}
