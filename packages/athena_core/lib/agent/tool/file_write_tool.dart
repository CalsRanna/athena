import 'dart:io';

import 'package:athena_core/util/path_normalizer.dart';

import 'tool_interface.dart';

class FileWriteTool implements Tool {
  @override
  ExecutionMode get executionMode => ExecutionMode.sequential;
  @override
  bool canExecuteParallel(Map<String, dynamic> args) => false;
  @override
  ToolRisk get risk => ToolRisk.dangerous;

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
  Future<String> execute(Map<String, dynamic> args, {void Function(String)? onUpdate}) async {
    final path = args['path'] as String;
    final content = args['content'] as String;

    // 归一化（词法）→ canonicalize 已存在部分（best-effort）：
    // 与权限层 PermissionRule 匹配使用同一路径，堵住 `..` 穿越
    // 在「规则命中」与「实际写入」之间不一致的问题。
    final normalized = await canonicalizePathForExecution(path);

    final file = File(normalized);
    await file.parent.create(recursive: true);
    await file.writeAsString(content);

    return 'Successfully wrote ${content.length} bytes to $path';
  }
}
