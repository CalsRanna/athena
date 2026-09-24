import 'dart:io';

import 'package:athena_core/util/path_normalizer.dart';
import 'package:athena_core/util/text_file_reader.dart';

import 'tool_interface.dart';

class FileReadTool implements Tool {
  @override
  ExecutionMode get executionMode => ExecutionMode.parallel;
  @override
  bool canExecuteParallel(Map<String, dynamic> args) => true;

  /// Maximum lines returned per call, to avoid blowing up the LLM context.
  static const _maxReturnLines = TextFileReader.maxReturnLines;

  @override
  String get name => 'file_read';

  @override
  String get description =>
      'Read the contents of a text file with line numbers. '
      'Supports offset/limit for reading large files in chunks. '
      'Large files (>5MB) are streamed to avoid memory issues. '
      'Output includes total line count so you know whether to read more.\n'
      'Only for TEXT files (source code, config, markdown, JSON, CSV, '
      'logs, etc.). For images (png, jpg, gif, webp), use the chat '
      'image attachment feature instead — do NOT call file_read on '
      'binary/image files as it will produce garbage output.\n'
      'Use offset/limit to paginate: start with offset=0,limit=100, '
      'then offset=100,limit=100, etc.';

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
        'description':
            'Line number to start reading from (0-indexed). '
            'Optional, defaults to 0.',
      },
      'limit': {
        'type': 'integer',
        'description':
            'Maximum number of lines to read. '
            'Optional, defaults to all lines (but capped at $_maxReturnLines for safety).',
      },
    },
    'required': ['path'],
  };

  @override
  Future<String> execute(
    Map<String, dynamic> args, {
    void Function(String)? onUpdate,
  }) async {
    final path = args['path'] as String;
    final offset = args['offset'] as int? ?? 0;
    final limit = args['limit'] as int?;

    // 归一化（词法）→ canonicalize（真实路径）→ 敏感路径检查。
    // 与权限层 PermissionRule 使用同一归一化函数，保证匹配与执行一致。
    final normalized = await canonicalizePathForExecution(path);
    if (isSensitivePath(normalized)) {
      return 'Error: Blocked: reading sensitive credential paths '
          '($path) requires approval';
    }

    final file = File(normalized);
    if (!await file.exists()) {
      return 'Error: File not found: $path';
    }

    return TextFileReader().read(file, offset: offset, limit: limit);
  }
}
