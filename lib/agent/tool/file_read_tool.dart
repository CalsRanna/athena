import 'dart:convert';
import 'dart:io';

import 'tool_interface.dart';

class FileReadTool implements Tool {
  /// 文件超过此大小（字节）时改用流式读取，避免整文件加载到内存。
  static const _streamThreshold = 5 * 1024 * 1024; // 5MB

  /// 单次最多返回的行数，防止 LLM 上下文撑爆。
  static const _maxReturnLines = 2000;

  FileReadTool();

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
  Future<String> execute(Map<String, dynamic> args) async {
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

  /// 小文件：一次性读入内存，简单快速。
  Future<String> _readSmall(File file, int offset, int? limit) async {
    final lines = await file.readAsLines();
    final total = lines.length;
    final start = offset.clamp(0, total);
    final effectiveLimit = (limit ?? total).clamp(0, _maxReturnLines);
    final end = (start + effectiveLimit).clamp(start, total);
    final selected = lines.sublist(start, end);

    return _formatOutput(selected, start, total, offset, limit);
  }

  /// 大文件：流式读取 + 预扫换行计数，避免内存爆炸。
  Future<String> _readLarge(
      File file, int offset, int? limit, int fileSize) async {
    // 第一遍：数换行符（纯字节扫描，不分配字符串，非常快）。
    final total = await _countLines(file);

    // 第二遍：流式读取所需行。
    final start = offset.clamp(0, total);
    final effectiveLimit = (limit ?? total).clamp(0, _maxReturnLines);
    final end = (start + effectiveLimit).clamp(start, total);

    final selected = await _streamLines(file, start, end);

    return _formatOutput(selected, start, total, offset, limit,
        fileSize: fileSize);
  }

  /// 格式化为输出：行号前缀 + 头部统计信息。
  String _formatOutput(
    List<String> lines,
    int start,
    int total,
    int requestedOffset,
    int? requestedLimit, {
    int? fileSize,
  }) {
    final buffer = StringBuffer();

    // 头部：给出完整上下文让 LLM 知道位置
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

    // 正文：行号 + 内容
    for (var i = 0; i < lines.length; i++) {
      buffer.write('${start + i + 1}\t');
      buffer.writeln(lines[i]);
    }

    return buffer.toString();
  }

  /// 扫描文件统计换行数（只计 \n，字节流方式避免字符串分配）。
  Future<int> _countLines(File file) async {
    var count = 0;
    final stream = file.openRead();
    await for (final chunk in stream) {
      for (final byte in chunk) {
        if (byte == 0x0A) count++; // \n
      }
    }
    // 如果文件非空且不以 \n 结尾，最后一行也要算。
    if (count == 0) {
      // 空文件或只有一行且无换行
      return file.lengthSync() > 0 ? 1 : 0;
    }
    // 检查文件是否以 \n 结尾
    final raf = await file.open(mode: FileMode.read);
    try {
      if (await file.length() > 0) {
        await raf.setPosition(await file.length() - 1);
        final lastByte = await raf.read(1);
        if (lastByte.isNotEmpty && lastByte[0] != 0x0A) {
          count++; // 最后一行没有 \n 结尾
        }
      }
    } finally {
      await raf.close();
    }
    return count;
  }

  /// 流式读取指定行范围 [start, end)。
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
