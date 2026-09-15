import 'dart:convert';
import 'dart:io';

// Callers validate file access before using this shared pagination reader.
class TextFileReader {
  static const _streamThreshold = 5 * 1024 * 1024;
  static const maxReturnLines = 2000;

  Future<String> read(File file, {int offset = 0, int? limit}) async {
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
    final effectiveLimit = (limit ?? total).clamp(0, maxReturnLines);
    final end = (start + effectiveLimit).clamp(start, total);
    final selected = lines.sublist(start, end);

    return _formatOutput(selected, start, total, offset, limit);
  }

  /// Large file: streaming read + pre-scan line count, to avoid memory explosion.
  Future<String> _readLarge(
    File file,
    int offset,
    int? limit,
    int fileSize,
  ) async {
    // First pass: count newlines (pure byte scan, no string allocation, very fast).
    final total = await _countLines(file);

    // Second pass: stream-read the required line range.
    final start = offset.clamp(0, total);
    final effectiveLimit = (limit ?? total).clamp(0, maxReturnLines);
    final end = (start + effectiveLimit).clamp(start, total);

    final selected = await _streamLines(file, start, end);

    return _formatOutput(
      selected,
      start,
      total,
      offset,
      limit,
      fileSize: fileSize,
    );
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
    if (lines.isNotEmpty && last < total) {
      buffer.writeln(
        'Hint: ${total - last} more lines available. Use offset=$last to continue.',
      );
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

  /// Count newlines by scanning file bytes (streaming, no string allocation,
  /// single pass — 不重复打开文件，也不混入同步 IO)。
  Future<int> _countLines(File file) async {
    var count = 0;
    var bytesRead = 0;
    var lastByte = -1;
    await for (final chunk in file.openRead()) {
      bytesRead += chunk.length;
      for (final byte in chunk) {
        if (byte == 0x0A) count++; // \n
        lastByte = byte;
      }
    }
    // 非空且不以 \n 结尾：末尾无换行的一行也要计入。
    if (bytesRead == 0) return 0; // 空文件
    if (lastByte != 0x0A) count++;
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
