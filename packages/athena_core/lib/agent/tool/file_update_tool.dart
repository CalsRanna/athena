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
  Future<String> execute(
    Map<String, dynamic> args, {
    void Function(String)? onUpdate,
  }) async {
    final path = args['path'] as String;
    final rawOld = args['old_string'] as String;
    final rawNew = args['new_string'] as String;
    final replaceAll = args['replace_all'] as bool? ?? false;

    if (rawOld == rawNew) {
      return 'Error: old_string and new_string must differ';
    }

    final oldString = _preprocess(rawOld);
    final newString = _preprocess(rawNew);

    if (oldString.isEmpty) {
      return 'Error: old_string must not be empty';
    }

    // 引擎已把 path 解析为真实路径并据此审批；复核审批后链接没有被替换
    // 路径上有不可穿越的目录时，审批与 deny 规则看到的都是词法路径，而真正
    // 落到哪是未知的（见 `path_normalizer.dart` 的「已知边界」）。执行前必须
    // 能确定目标，否则拒绝。
    final unresolved = unresolvablePathError(path);
    if (unresolved != null) return unresolved;

    final changed = realPathChangedSinceApproval(path);
    if (changed != null) return symlinkChangedError(path, changed);
    final resolvedPath = normalizePathForMatch(path);
    if (isProtectedWritePath(resolvedPath)) {
      return protectedWritePathError(path);
    }
    final file = File(resolvedPath);
    if (!await file.exists()) {
      return 'Error: File not found: $path';
    }

    final mtimeBefore = await file.lastModified();
    final content = await file.readAsString();
    final lineEnding = _detectLineEnding(content);
    final normalized = _normalizeQuotes(content);

    final matchCount = _countMatches(normalized, oldString);
    if (matchCount == 0) {
      final rawCount = _countMatches(content, oldString);
      if (rawCount == 0) {
        return 'Error: old_string not found in file. '
            'Make sure the string matches exactly, including whitespace and indentation.';
      }
      final updated = _applyReplace(
        content,
        oldString,
        newString,
        replaceAll,
        lineEnding,
      );
      return _writeSafely(file, mtimeBefore, updated);
    }

    if (!replaceAll && matchCount > 1) {
      return 'Error: old_string appears $matchCount times in the file. '
          'Use replace_all: true to replace all occurrences, '
          'or provide more surrounding context to make old_string unique.';
    }

    // 匹配走归一化串，替换切回原文：见 _applyReplacePreservingOriginal
    final updated = _applyReplacePreservingOriginal(
      content,
      normalized,
      oldString,
      newString,
      replaceAll,
    );
    return _writeSafely(
      file,
      mtimeBefore,
      _normalizeLineEndings(updated, lineEnding),
    );
  }

  String _preprocess(String text) {
    return _normalizeQuotes(
      text.replaceAll(RegExp(r'^[ \t]*\d+\t', multiLine: true), ''),
    );
  }

  String _normalizeQuotes(String text) {
    return text
        .replaceAll('\u201c', '"')
        .replaceAll('\u201d', '"')
        .replaceAll('\u2018', "'")
        .replaceAll('\u2019', "'")
        .replaceAll('\u00ab', '"')
        .replaceAll('\u00bb', '"');
  }

  /// 在 [normalized] 上定位、在 [original] 上替换。
  ///
  /// 匹配必须走归一化串——模型从 file_read 看到的是原文，但它可能拿直引号
  /// 去匹配弯引号文件。替换**不能**落在归一化串上：把归一化结果写回去会把
  /// 全文的弯引号拉直，改一行就毁掉整份文档的排版。
  ///
  /// [_normalizeQuotes] 只做单字符到单字符的替换、不改变长度，所以两个串的
  /// 下标一一对应：用它定位、按同样的下标切 [original]，未被替换的字节逐字
  /// 保留。这也正是「先归一化再事后还原引号」那条路走不通的原因——替换前后
  /// 长度一变，就再也认不出哪些区域是没被碰过的。
  String _applyReplacePreservingOriginal(
    String original,
    String normalized,
    String oldString,
    String newString,
    bool replaceAll,
  ) {
    final first = normalized.indexOf(oldString);
    if (first < 0) return original;

    if (!replaceAll) {
      // 与 [_applyReplace] 同一条既有行为：整行删掉时顺手吃掉它留下的换行
      var after = original.substring(first + oldString.length);
      if (newString.isEmpty &&
          !oldString.endsWith('\n') &&
          after.startsWith('\n')) {
        after = after.substring(1);
      }
      return '${original.substring(0, first)}$newString$after';
    }

    final buffer = StringBuffer();
    var consumed = 0;
    var cursor = 0;
    while (true) {
      final index = normalized.indexOf(oldString, cursor);
      if (index < 0) break;
      buffer.write(original.substring(consumed, index));
      buffer.write(newString);
      consumed = index + oldString.length;
      cursor = consumed;
    }
    buffer.write(original.substring(consumed));
    return buffer.toString();
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

  String _applyReplace(
    String content,
    String oldString,
    String newString,
    bool replaceAll,
    String? lineEnding,
  ) {
    if (replaceAll) {
      return content.replaceAll(oldString, newString);
    }

    final index = content.indexOf(oldString);
    final before = content.substring(0, index);
    final after = content.substring(index + oldString.length);

    var trailing = after;
    if (newString.isEmpty &&
        !oldString.endsWith('\n') &&
        trailing.startsWith('\n')) {
      trailing = trailing.substring(1);
    }

    return '$before$newString$trailing';
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

  Future<String> _writeSafely(
    File file,
    DateTime mtimeBefore,
    String updated,
  ) async {
    final mtimeNow = await file.lastModified();
    if (mtimeNow != mtimeBefore) {
      return 'Error: File was modified externally since reading. '
          'Re-read the file and try again.';
    }

    // 同 file_write：原子替换，且不跟随最后一段符号链接
    await replaceFileContent(file, updated);
    return 'Successfully updated ${file.path}';
  }
}
