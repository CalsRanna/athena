import 'dart:io';

import 'package:athena_core/agent/tool/tool_interface.dart';
import 'package:athena_core/util/atomic_file_write.dart';
import 'package:athena_core/util/path_normalizer.dart';

class FileWriteTool extends Tool {
  @override
  String get name => 'file_write';

  @override
  String get description =>
      'Write content to a file. Creates the file if it '
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
  Future<String> execute(
    Map<String, dynamic> args, {
    void Function(String)? onUpdate,
  }) async {
    final path = args['path'] as String;
    final content = args['content'] as String;

    // 引擎已把 path 解析为真实路径（applyRunWorkspace）并据此审批；
    // 这里复核审批后链接没有被替换，保证写入的正是审批时看到的文件。
    // 路径上有不可穿越的目录时，审批与 deny 规则看到的都是词法路径，而真正
    // 落到哪是未知的（见 `path_normalizer.dart` 的「已知边界」）。执行前必须
    // 能确定目标，否则拒绝。
    final unresolved = unresolvablePathError(path);
    if (unresolved != null) return unresolved;

    final changed = realPathChangedSinceApproval(path);
    if (changed != null) return symlinkChangedError(path, changed);
    final normalized = normalizePathForMatch(path);
    if (isProtectedWritePath(normalized)) {
      return protectedWritePathError(path);
    }

    // 原子替换，且不跟随最后一段符号链接：审批到这里之间目标若被换成链接，
    // 直接写会改坏链接指向的文件（见 replaceFileContent）
    await replaceFileContent(File(normalized), content);

    return 'Successfully wrote ${content.length} bytes to $path';
  }
}
