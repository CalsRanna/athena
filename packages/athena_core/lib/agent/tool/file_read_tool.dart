import 'dart:convert';
import 'dart:io';

import 'package:athena_core/agent/tool/tool_interface.dart';
import 'package:athena_core/agent/tool/tool_result.dart';
import 'package:athena_core/util/path_normalizer.dart';
import 'package:athena_core/util/text_file_reader.dart';

class FileReadTool extends Tool implements CancellableTool {
  final TextFileReader _reader = TextFileReader();
  @override
  ExecutionMode get executionMode => ExecutionMode.parallel;

  /// Maximum lines returned per call, to avoid blowing up the LLM context.
  static const _maxReturnLines = TextFileReader.maxReturnLines;

  /// 单张图片的原始字节上限。Messages 协议单图上限 5MB，base64 膨胀约
  /// 1/3，超过这个值的图连请求都发不出去，不如在这里就明确拒绝。
  static const _maxImageBytes = 3500 * 1024;

  @override
  String get name => 'file_read';

  @override
  String get description =>
      'Read a file. Text files are returned with line numbers; image files '
      '(png, jpg, gif, webp) are returned as an image you can see directly. '
      'Supports offset/limit for reading large TEXT files in chunks. '
      'Large text files (>5MB) are streamed to avoid memory issues. '
      'Output includes total line count so you know whether to read more.\n'
      'Images larger than 3.5MB are rejected — ask the user to downscale. '
      'Use offset/limit to paginate text: start with offset=0,limit=100, '
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
            'Optional, defaults to 0. Ignored for images.',
      },
      'limit': {
        'type': 'integer',
        'description':
            'Maximum number of lines to read. '
            'Optional, defaults to all lines (but capped at $_maxReturnLines for safety). '
            'Ignored for images.',
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

    final imageResult = await _readImage(file, path);
    if (imageResult != null) return imageResult;

    return ToolExecutionResult.success(
      await _reader.read(
        file,
        offset: offset,
        limit: limit,
        cancelSignal: cancelSignal,
      ),
    );
  }

  /// 按文件头判断是否为图片并读出；不是图片时返回 null，交给文本路径。
  Future<ToolExecutionResult?> _readImage(File file, String displayPath) async {
    final head = await _readHead(file);
    if (head == null) return null;
    final mediaType = _imageMediaType(head);
    if (mediaType == null) return null;

    final length = await file.length();
    if (length > _maxImageBytes) {
      return ToolExecutionResult.error(
        'Error: Image is ${(length / 1024).toStringAsFixed(0)} KB, larger '
        'than the ${_maxImageBytes ~/ 1024} KB limit. Ask the user to '
        'downscale it, or use bash to inspect its metadata instead.',
      );
    }
    final bytes = await file.readAsBytes();
    return ToolExecutionResult.success(
      'Read image file $displayPath ($mediaType, '
      '${(bytes.length / 1024).toStringAsFixed(1)} KB). '
      'The image is attached to this turn.',
      images: [
        ToolResultImage(data: base64Encode(bytes), mediaType: mediaType),
      ],
    );
  }

  Future<List<int>?> _readHead(File file) async {
    RandomAccessFile? handle;
    try {
      handle = await file.open();
      return await handle.read(12);
    } on FileSystemException {
      return null;
    } finally {
      await handle?.close();
    }
  }

  /// 按魔数识别图片格式；识别不出返回 null（按文本处理）。
  ///
  /// 以内容而不是扩展名为准：`.txt` 里放一张 PNG 也能被看见，误判成本
  /// 只是把非图片当图片。
  String? _imageMediaType(List<int> head) {
    bool startsWith(List<int> signature, [int offset = 0]) {
      if (head.length < offset + signature.length) return false;
      for (var i = 0; i < signature.length; i++) {
        if (head[offset + i] != signature[i]) return false;
      }
      return true;
    }

    if (startsWith(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
      return 'image/png';
    }
    if (startsWith(const [0xFF, 0xD8, 0xFF])) return 'image/jpeg';
    if (startsWith(const [0x47, 0x49, 0x46, 0x38])) return 'image/gif';
    if (startsWith(const [0x52, 0x49, 0x46, 0x46]) &&
        startsWith(const [0x57, 0x45, 0x42, 0x50], 8)) {
      return 'image/webp';
    }
    return null;
  }
}
