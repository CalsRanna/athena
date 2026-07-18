import 'dart:convert';
import 'dart:io';

import 'tool_interface.dart';

class FileReadTool implements Tool {
  @override
  ExecutionMode get executionMode => ExecutionMode.parallel;
  /// When file exceeds this size (bytes), switch to streaming to avoid loading the entire file into memory.
  static const _streamThreshold = 5 * 1024 * 1024; // 5MB

  /// Maximum lines returned per call, to avoid blowing up the LLM context.
  static const _maxReturnLines = 2000;

  @override
  String get name => 'file_read';

  @override
  String get description => 'Read the contents of a text file with line numbers. '
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
            'description': 'Line number to start reading from (0-indexed). '
                'Optional, defaults to 0.',
          },
          'limit': {
            'type': 'integer',
            'description': 'Maximum number of lines to read. '
                'Optional, defaults to all lines (but capped at $_maxReturnLines for safety).',
          },
        },
        'required': ['path'],
      };

  @override
  Future<String> execute(Map<String, dynamic> args, {void Function(String)? onUpdate}) async {
    final path = args['path'] as String;
    final offset = args['offset'] as int? ?? 0;
    final limit = args['limit'] as int?;

    final file = File(path);
    if (!await file.exists()) {
      return 'Error: File not found: $path';
    }

    final fileSize = await file.length();

    if (fileSize < _streamThreshold) {
      return _readSmall(file, offset, limit);
    } else {
      return _readLarge(file, offset, limit, fileSize);
    }
  }

  /// Small file: read all at once, simple and fast.
  Future<String> _readSmall(File file, int offset, int? limit) async {
    final lines = await file.readAsLines();
    final total = lines.length;
    final start = offset.clamp(0, total);
    final effectiveLimit = (limit ?? total).clamp(0, _maxReturnLines);
    final end = (start + effectiveLimit).clamp(start, total);
    final selected = lines.sublist(start, end);

    return _formatOutput(selected, start, total, offset, limit);
  }

  /// Large file: streaming read + pre-scan line count, to avoid memory explosion.
  Future<String> _readLarge(
      File file, int offset, int? limit, int fileSize) async {
    // First pass: count newlines (pure byte scan, no string allocation, very fast).
    final total = await _countLines(file);

    // Second pass: stream-read the required line range.
    final start = offset.clamp(0, total);
    final effectiveLimit = (limit ?? total).clamp(0, _maxReturnLines);
    final end = (start + effectiveLimit).clamp(start, total);

    final selected = await _streamLines(file, start, end);

    return _formatOutput(selected, start, total, offset, limit,
        fileSize: fileSize);
  }

  /// Format output: line number prefix + header statistics.
  String _formatOutput(
    List<String> lines,
    int start,
    int total,
    int requestedOffset,
    int? requestedLimit, {
    int? fileSize,
  }) {
    final buffer = StringBuffer();

    // Header: give LLM full context of position within the file
    final first = start + 1;
    final last = start + lines.length;
    buffer.writeln('[lines $first-$last / $total total]');
    if (requestedOffset != 0 || requestedLimit != null) {
      buffer.write('(requested: offset=$requestedOffset');
      if (requestedLimit != null) {
        buffer.write(', limit=$requestedLimit');
      }
      buffer.writeln(')');
    }
    if (lines.length == last && last < total) {
      buffer.writeln(
          'Hint: ${total - last} more lines available. Use offset=$last to continue.');
    }
    if (fileSize != null) {
      buffer.writeln('File size: ${_formatSize(fileSize)} (streamed)');
    }
    buffer.writeln();

    // Body: line number + content
    for (var i = 0; i < lines.length; i++) {
      buffer.write('${start + i + 1}\t');
      buffer.writeln(lines[i]);
    }

    return buffer.toString();
  }

  /// Count newlines by scanning file bytes (streaming, no string allocation).
  Future<int> _countLines(File file) async {
    var count = 0;
    final stream = file.openRead();
    await for (final chunk in stream) {
      for (final byte in chunk) {
        if (byte == 0x0A) count++; // \n
      }
    }
    // If file is non-empty and doesn't end with \n, count the last line too.
    if (count == 0) {
      // Empty file, or single line without newline
      return file.lengthSync() > 0 ? 1 : 0;
    }
    // Check if file ends with \n
    final raf = await file.open(mode: FileMode.read);
    try {
      if (await file.length() > 0) {
        await raf.setPosition(await file.length() - 1);
        final lastByte = await raf.read(1);
        if (lastByte.isNotEmpty && lastByte[0] != 0x0A) {
          count++; // Last line doesn't end with \n
        }
      }
    } finally {
      await raf.close();
    }
    return count;
  }

  /// Stream-read the specified line range [start, end).
  Future<List<String>> _streamLines(File file, int start, int end) async {
    final lines = <String>[];
    var lineIndex = 0;
    final stream = file
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in stream) {
      if (lineIndex >= end) break;
      if (lineIndex >= start) {
        lines.add(line);
      }
      lineIndex++;
    }

    return lines;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
