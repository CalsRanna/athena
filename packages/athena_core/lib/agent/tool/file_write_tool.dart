import 'dart:io';

import 'package:athena_core/util/path_normalizer.dart';

import 'tool_interface.dart';

class FileWriteTool implements Tool {
  @override
  ExecutionMode get executionMode => ExecutionMode.sequential;
  @override
  bool canExecuteParallel(Map<String, dynamic> args) => false;

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

    // 引擎已把 path 解析为真实路径（applyRunWorkspace）并据此审批；
    // 这里复核审批后链接没有被替换，保证写入的正是审批时看到的文件。
    final changed = realPathChangedSinceApproval(path);
    if (changed != null) return symlinkChangedError(path, changed);
    final normalized = normalizePathForMatch(path);
    if (isProtectedWritePath(normalized)) {
      return protectedWritePathError(path);
    }

    final file = File(normalized);
    await file.parent.create(recursive: true);
    await file.writeAsString(content);

    return 'Successfully wrote ${content.length} bytes to $path';
  }
}
