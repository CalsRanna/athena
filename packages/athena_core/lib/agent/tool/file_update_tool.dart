import 'dart:io';

import 'package:athena_core/agent/tool/tool_interface.dart';
import 'package:athena_core/util/atomic_file_write.dart';
import 'package:athena_core/util/path_normalizer.dart';

class FileUpdateTool extends Tool {
  FileUpdateTool();

  @override
  String get name => 'file_update';

  @override
  String get description =>
      'Perform exact string replacements in a file. '
      'Finds old_string occurrences and replaces them with new_string. '
      'When replace_all is false (default), old_string must appear exactly once. '
      'Use for targeted edits without rewriting the entire file. '
      'For creating or overwriting a whole file, use file_write.';

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
        'description':
            'The exact text to find and replace. '
            'Must match including whitespace and indentation. '
            'Line number prefixes from file_read output are automatically stripped.',
      },
      'new_string': {
        'type': 'string',
        'description':
            'The text to replace it with (must differ from old_string).',
      },
      'replace_all': {
        'type': 'boolean',
        'description':
            'Replace all occurrences (default: false). '
            'When false, old_string must appear exactly once.',
      },
    },
    'required': ['path', 'old_string', 'new_string'],
  };

  @override
  Future<ToolExecutionResult> executeResult(
    Map<String, dynamic> args, {
    void Function(String)? onUpdate,
  }) async {
    final path = args['path'] as String;
    final rawOld = args['old_string'] as String;
    final rawNew = args['new_string'] as String;
    final replaceAll = args['replace_all'] as bool? ?? false;

    if (rawOld == rawNew) {
      return ToolExecutionResult.error(
        'Error: old_string and new_string must differ',
      );
    }

    final oldString = _preprocess(rawOld);
    final newString = _preprocess(rawNew);

    if (oldString.isEmpty) {
      return ToolExecutionResult.error('Error: old_string must not be empty');
    }

    // 引擎已把 path 解析为真实路径并据此审批；复核审批后链接没有被替换
    // 路径上有不可穿越的目录时，审批与 deny 规则看到的都是词法路径，而真正
    // 落到哪是未知的（见 `path_normalizer.dart` 的「已知边界」）。执行前必须
    // 能确定目标，否则拒绝。
    final unresolved = unresolvablePathError(path);
    if (unresolved != null) return ToolExecutionResult.error(unresolved);

    final changed = realPathChangedSinceApproval(path);
    if (changed != null) {
      return ToolExecutionResult.error(symlinkChangedError(path, changed));
    }
    final resolvedPath = normalizePathForMatch(path);
    if (isProtectedWritePath(resolvedPath)) {
      return ToolExecutionResult.error(protectedWritePathError(path));
    }
    final file = File(resolvedPath);
    if (!await file.exists()) {
      return ToolExecutionResult.error('Error: File not found: $path');
    }

    final mtimeBefore = await file.lastModified();
    final content = await file.readAsString();
    final lineEnding = _detectLineEnding(content);
    // 只在匹配副本里统一 CRLF；原文位置映射保证未编辑区域逐字保留。
    final normalized = _NormalizedText(_normalizeQuotes(content));
    final matchCount = _countMatches(normalized.text, oldString);
    if (matchCount == 0) {
      return ToolExecutionResult.error(
        'Error: old_string not found in file. '
        'Make sure the string matches exactly, including whitespace and indentation.',
      );
    }
    if (!replaceAll && matchCount > 1) {
      return ToolExecutionResult.error(
        'Error: old_string appears $matchCount times in the file. '
        'Use replace_all: true to replace all occurrences, '
        'or provide more surrounding context to make old_string unique.',
      );
    }
    final replacement = _normalizeLineEndings(newString, lineEnding);
    final buffer = StringBuffer();
    var consumed = 0;
    var cursor = 0;
    while (true) {
      final index = normalized.text.indexOf(oldString, cursor);
      if (index < 0) break;
      final start = normalized.originalOffset(index);
      var end = normalized.originalOffset(index + oldString.length);
      if (replacement.isEmpty &&
          !oldString.endsWith('\n') &&
          (start == 0 || content[start - 1] == '\n')) {
        if (content.startsWith('\r\n', end)) {
          end += 2;
        } else if (content.startsWith('\n', end)) {
          end++;
        }
      }
      buffer.write(content.substring(consumed, start));
      buffer.write(replacement);
      consumed = end;
      cursor = index + oldString.length;
      if (!replaceAll) break;
    }
    buffer.write(content.substring(consumed));
    return _writeSafely(file, mtimeBefore, buffer.toString());
  }

  String _preprocess(String text) => _normalizeQuotes(
    text
        .replaceAll('\r\n', '\n')
        .replaceAll(RegExp(r'^[ \t]*\d+\t', multiLine: true), ''),
  );

  String _normalizeQuotes(String text) {
    return text
        .replaceAll('\u201c', '"')
        .replaceAll('\u201d', '"')
        .replaceAll('\u2018', "'")
        .replaceAll('\u2019', "'")
        .replaceAll('\u00ab', '"')
        .replaceAll('\u00bb', '"');
  }

  int _countMatches(String content, String search) {
    var count = 0;
    var index = 0;
    while ((index = content.indexOf(search, index)) != -1) {
      count++;
      index += search.length;
    }
    return count;
  }

  String? _detectLineEnding(String content) {
    final crlfCount = '\r\n'.allMatches(content).length;
    final lfCount = '\n'.allMatches(content).length - crlfCount;
    if (crlfCount > lfCount) return '\r\n';
    if (lfCount > 0) return '\n';
    return null;
  }

  String _normalizeLineEndings(String content, String? target) {
    if (target == '\r\n') {
      return content.replaceAll(RegExp(r'\r?\n'), '\r\n');
    }
    if (target == '\n') {
      return content.replaceAll('\r\n', '\n');
    }
    return content;
  }

  Future<ToolExecutionResult> _writeSafely(
    File file,
    DateTime mtimeBefore,
    String updated,
  ) async {
    final mtimeNow = await file.lastModified();
    if (mtimeNow != mtimeBefore) {
      return ToolExecutionResult.error(
        'Error: File was modified externally since reading. '
        'Re-read the file and try again.',
      );
    }

    // 同 file_write：原子替换，且不跟随最后一段符号链接
    await replaceFileContent(file, updated);
    return ToolExecutionResult.success('Successfully updated ${file.path}');
  }
}

class _NormalizedText {
  _NormalizedText(String original) : text = original.replaceAll('\r\n', '\n') {
    for (final match in RegExp(r'\r\n').allMatches(original)) {
      _removedAt.add(match.start - _removedAt.length);
    }
  }

  final String text;
  final List<int> _removedAt = [];

  int originalOffset(int offset) {
    var low = 0;
    var high = _removedAt.length;
    while (low < high) {
      final middle = (low + high) ~/ 2;
      if (_removedAt[middle] < offset) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return offset + low;
  }
}
