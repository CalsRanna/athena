import 'dart:io';

import 'package:athena/agent/permission/sandbox.dart';

import 'tool_interface.dart';

class ListDirectoryTool implements Tool {
  final PathSandbox sandbox;

  ListDirectoryTool({required this.sandbox});

  @override
  String get name => 'list_directory';

  @override
  String get description => 'List files and directories in a given path. '
      'Use when you need to browse the project structure or verify file locations. '
      'Supports depth control for recursive listing.';

  @override
  DangerLevel get dangerLevel => DangerLevel.needsApproval;

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'path': {
            'type': 'string',
            'description': 'The directory path to list. '
                'Defaults to the current working directory.',
          },
          'depth': {
            'type': 'integer',
            'description': 'Maximum recursion depth. 1 = current dir only. '
                'Defaults to 1. Max 3.',
          },
        },
        'required': [],
      };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final path = args['path'] as String? ?? Directory.current.path;
    final depth = (args['depth'] as int? ?? 1).clamp(1, 3);

    if (!sandbox.canRead(path)) {
      return 'Error: path "$path" is in a restricted system area and cannot be accessed.';
    }

    final dir = Directory(path);
    if (!await dir.exists()) {
      return 'Error: Directory not found: $path';
    }

    final buffer = StringBuffer();
    _listDir(dir, '', depth, buffer, 0);
    return buffer.toString().trim();
  }

  void _listDir(
    Directory dir,
    String prefix,
    int maxDepth,
    StringBuffer buffer,
    int currentDepth,
  ) {
    if (currentDepth >= maxDepth) return;

    try {
      final entries = dir.listSync()
        ..sort((a, b) {
          final aIsDir = a is Directory;
          final bIsDir = b is Directory;
          if (aIsDir && !bIsDir) return -1;
          if (!aIsDir && bIsDir) return 1;
          return a.path.compareTo(b.path);
        });

      for (final entry in entries) {
        final name = entry.path.split('/').last;
        final isDir = entry is Directory;
        buffer.writeln('$prefix${isDir ? '/' : ''}$name${isDir ? '/' : ''}');
        if (isDir && currentDepth + 1 < maxDepth) {
          _listDir(entry, '$prefix  ', maxDepth, buffer, currentDepth + 1);
        }
      }
    } catch (e) {
      buffer.writeln('$prefix[Error: $e]');
    }
  }
}
