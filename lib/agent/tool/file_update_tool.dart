import 'dart:io';

import 'package:athena/agent/permission/sandbox.dart';

import 'tool_interface.dart';

class FileUpdateTool implements Tool {
  final PathSandbox sandbox;

  FileUpdateTool({required this.sandbox});

  @override
  String get name => 'file_update';

  @override
  String get description => 'Perform exact string replacements in a file. '
      'Finds old_string occurrences and replaces them with new_string. '
      'When replace_all is false (default), old_string must appear exactly once. '
      'Use for targeted edits without rewriting the entire file. '
      'For creating or overwriting a whole file, use file_write.';

  @override
  DangerLevel get dangerLevel => DangerLevel.needsApproval;

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
            'description': 'The exact text to find and replace. '
                'Must match including whitespace and indentation. '
                'Line number prefixes from file_read output are automatically stripped.',
          },
          'new_string': {
            'type': 'string',
            'description': 'The text to replace it with (must differ from old_string).',
          },
          'replace_all': {
            'type': 'boolean',
            'description': 'Replace all occurrences (default: false). '
                'When false, old_string must appear exactly once.',
          },
        },
        'required': ['path', 'old_string', 'new_string'],
      };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final path = args['path'] as String;
    final rawOld = args['old_string'] as String;
    final rawNew = args['new_string'] as String;
    final replaceAll = args['replace_all'] as bool? ?? false;

    if (!sandbox.canWrite(path)) {
      return 'Error: path "$path" is in a restricted system area and cannot be accessed.';
    }

    if (rawOld == rawNew) {
      return 'Error: old_string and new_string must differ';
    }

    final oldString = _preprocess(rawOld);
    final newString = _preprocess(rawNew);

    if (oldString.isEmpty) {
      return 'Error: old_string must not be empty';
    }

    final file = File(path);
    if (!await file.exists()) {
      return 'Error: File not found: $path';
    }

    final mtimeBefore = await file.lastModified();
    final content = await file.readAsString();
    final lineEnding = _detectLineEnding(content);
    final normalized = _normalizeQuotes(content);

    final matchCount = _countMatches(normalized, oldString);
    if (matchCount == 0) {
      // Attempt matching with original quotes in case normalization was wrong
      final rawCount = _countMatches(content, oldString);
      if (rawCount == 0) {
        return 'Error: old_string not found in file. '
            'Make sure the string matches exactly, including whitespace and indentation.';
      }
      // Raw match works, don't normalize
      final updated = _applyReplace(content, oldString, newString, replaceAll, lineEnding);
      return _writeSafely(file, mtimeBefore, updated);
    }

    if (!replaceAll && matchCount > 1) {
      return 'Error: old_string appears $matchCount times in the file. '
          'Use replace_all: true to replace all occurrences, '
          'or provide more surrounding context to make old_string unique.';
    }

    final updated = _applyReplace(normalized, oldString, newString, replaceAll, lineEnding);
    // Restore original quote style
    final restored = _restoreQuotes(updated, content);
    return _writeSafely(file, mtimeBefore, _normalizeLineEndings(restored, lineEnding));
  }

  /// Strip line number prefixes from file_read output.
  ///
  /// file_read outputs "42\tcontent" format. Models may copy these prefixes
  /// into old_string. Strip both "42\t" and "    42\t" (cat -n style) formats.
  String _preprocess(String text) {
    // Strip leading line number prefix on each line: optional spaces, digits, then tab
    return text.replaceAll(RegExp(r'^[ \t]*\d+\t', multiLine: true), '');
  }

  /// Normalize smart/curly quotes to straight quotes for matching.
  ///
  /// Models may output " (U+201C/U+201D) or ' (U+2018/U+2019) while files
  /// use straight quotes. Normalize all to straight for comparison.
  String _normalizeQuotes(String text) {
    return text
        .replaceAll('“', '"') // left double
        .replaceAll('”', '"') // right double
        .replaceAll('‘', "'") // left single
        .replaceAll('’', "'") // right single
        .replaceAll('«', '"') // left guillemet
        .replaceAll('»', '"'); // right guillemet
  }

  /// Restore original quote style in the file.
  ///
  /// After applying replacements on normalized content, convert back
  /// to the quote style found in the original content.
  String _restoreQuotes(String updated, String original) {
    for (final pair in [
      ('"', ['“', '”']),
      ("'", ['‘', '’']),
    ]) {
      final straight = pair.$1;
      if (!original.contains(straight)) continue;
      // If original uses curly quotes, convert new content's straight quotes back
      final hasCurly = pair.$2.any((c) => original.contains(c));
      if (hasCurly) {
        // Keep curly quotes as-is since normalization already handled matching
        return updated;
      }
    }
    return updated;
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

    // When deleting (newString is empty) and old_string doesn't end with
    // a newline, remove the following newline too to avoid leaving a blank line.
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

  Future<String> _writeSafely(File file, DateTime mtimeBefore, String updated) async {
    // Re-read to detect external modification between our read and write
    final mtimeNow = await file.lastModified();
    if (mtimeNow != mtimeBefore) {
      return 'Error: File was modified externally since reading. '
          'Re-read the file and try again.';
    }

    await file.writeAsString(updated);
    return 'Successfully updated ${file.path}';
  }
}
