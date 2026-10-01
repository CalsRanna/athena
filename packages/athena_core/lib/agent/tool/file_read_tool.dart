import 'dart:io';

import 'package:athena_core/agent/tool/tool_interface.dart';
import 'package:athena_core/util/path_normalizer.dart';
import 'package:athena_core/util/text_file_reader.dart';

class FileReadTool extends Tool implements CancellableTool {
  final TextFileReader _reader = TextFileReader();
  @override
  ExecutionMode get executionMode => ExecutionMode.parallel;

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
  Future<ToolExecutionResult> executeResult(
    Map<String, dynamic> args, {
    void Function(String)? onUpdate,
  }) => _execute(args);

  @override
  Future<ToolExecutionResult> executeCancellable(
    Map<String, dynamic> args, {
    void Function(String)? onUpdate,
    required Future<void> cancelSignal,
  }) => _execute(args, cancelSignal: cancelSignal);

  Future<ToolExecutionResult> _execute(
    Map<String, dynamic> args, {
    Future<void>? cancelSignal,
  }) async {
    final path = args['path'] as String;
    final offset = args['offset'] as int? ?? 0;
    final limit = args['limit'] as int?;

    // 引擎已把 path 解析为真实路径并据此审批；复核链接未被替换后再做
    // 敏感路径检查（基于真实路径，链接绕不过去）。
    // 路径上有不可穿越的目录时，审批与 deny 规则看到的都是词法路径，而真正
    // 落到哪是未知的（见 `path_normalizer.dart` 的「已知边界」）。执行前必须
    // 能确定目标，否则拒绝。
    final unresolved = unresolvablePathError(path);
    if (unresolved != null) return ToolExecutionResult.error(unresolved);

    final changed = realPathChangedSinceApproval(path);
    if (changed != null) {
      return ToolExecutionResult.error(symlinkChangedError(path, changed));
    }
    final normalized = normalizePathForMatch(path);
    if (isSensitivePath(normalized)) {
      // 硬拦，与 protectedWritePathError 同一口径。原文案写的是
      // 「requires approval」，但这条在审批之后无条件返回——批准在这里不起作用，
      // 那样写会让模型以为换个说法或重试就能过。
      //
      // 注意别把这条读成「凭据读不出来」：bash 里的 `cat ~/.ssh/id_rsa` 归
      // 审批管，用户会看到具体命令并自己决定。file_read 没有按路径默认弹审批的
      // 机制，所以这里直接拒绝；两者是刻意的差异，不是漏洞。
      return ToolExecutionResult.error(
        'Error: Blocked: reading credential or Athena data paths '
        '($path) is not allowed regardless of approval, because the contents '
        'would enter the conversation context. Ask the user to provide the '
        'specific value you need instead.',
      );
    }

    final file = File(normalized);
    if (!await file.exists()) {
      return ToolExecutionResult.error('Error: File not found: $path');
    }

    return ToolExecutionResult.success(
      await _reader.read(
        file,
        offset: offset,
        limit: limit,
        cancelSignal: cancelSignal,
      ),
    );
  }
}
