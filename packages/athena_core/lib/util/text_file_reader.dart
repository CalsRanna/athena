import 'dart:convert';
import 'dart:io';
import 'dart:collection';

import 'package:athena_core/util/cancellable_stream.dart';

// Callers validate file access before using this shared pagination reader.
class TextFileReader {
  static const _streamThreshold = 5 * 1024 * 1024;
  static const maxReturnLines = 2000;

  final LinkedHashMap<String, _LineIndex> _indexes = LinkedHashMap();

  Future<String> read(
    File file, {
    int offset = 0,
    int? limit,
    Future<void>? cancelSignal,
  }) async {
    final stat = await file.stat();
    if (stat.size < _streamThreshold) {
      final lines = await cancellableStream(
        file.openRead().transform(utf8.decoder).transform(const LineSplitter()),
        cancelSignal,
      ).toList();
      final start = offset.clamp(0, lines.length);
      final end = (start + (limit ?? lines.length).clamp(0, maxReturnLines))
          .clamp(start, lines.length);
      return _formatOutput(
        lines.sublist(start, end),
        start,
        lines.length,
        offset,
        limit,
      );
    }
    var index = _indexes.remove(file.path);
    if (index == null || !index.matches(stat)) {
      index = await _buildIndex(file, stat, cancelSignal);
    }
    _indexes[file.path] = index;
    if (_indexes.length > 8) _indexes.remove(_indexes.keys.first);
    final start = offset.clamp(0, index.total);
    final end = (start + (limit ?? index.total).clamp(0, maxReturnLines)).clamp(
      start,
      index.total,
    );
    final checkpoint = index.checkpoint(start);
    final lines = <String>[];
    if (end > start) {
      var current = checkpoint.line;
      final stream = file
          .openRead(checkpoint.byte)
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      await for (final line in cancellableStream(stream, cancelSignal)) {
        if (current >= start) lines.add(line);
        if (++current >= end) break;
      }
    }
    if (!index.matches(await file.stat())) {
      _indexes.remove(file.path);
      throw FileSystemException(
        'File changed while reading; read it again',
        file.path,
      );
    }
    return _formatOutput(
      lines,
      start,
      index.total,
      offset,
      limit,
      fileSize: stat.size,
    );
  }

  Future<_LineIndex> _buildIndex(
    File file,
    FileStat stat,
    Future<void>? cancelSignal,
  ) async {
    final index = _LineIndex(stat);
    var position = 0;
    var pendingCr = false;
    var lastBoundary = 0;
    void boundary(int byte) {
      index.total++;
      lastBoundary = byte;
      if (index.total % index.stride == 0) {
        index.points.add((line: index.total, byte: byte));
        if (index.points.length > 4096) {
          index.stride *= 2;
          index.points.removeWhere((point) => point.line % index.stride != 0);
        }
      }
    }

    await for (final chunk in cancellableStream(
      file.openRead(),
      cancelSignal,
    )) {
      for (final byte in chunk) {
        if (pendingCr) {
          boundary(position + (byte == 0x0A ? 1 : 0));
          pendingCr = false;
          if (byte == 0x0A) {
            position++;
            continue;
          }
        }
        if (byte == 0x0D) {
          pendingCr = true;
        } else if (byte == 0x0A) {
          boundary(position + 1);
        }
        position++;
        // LineSplitter 需要攒完整一行；行数上限挡不住超大的单行 JSON。
        if (position - lastBoundary > 1 << 20) {
          throw FileSystemException(
            'A line exceeds the 1MiB read limit; use a narrower shell command',
            file.path,
          );
        }
      }
    }
    if (pendingCr) boundary(position);
    if (position > lastBoundary) index.total++;
    if (!index.matches(await file.stat())) {
      throw FileSystemException(
        'File changed while indexing; read it again',
        file.path,
      );
    }
    return index;
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

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

class _LineIndex {
  _LineIndex(this.stat);
  final FileStat stat;
  int total = 0;
  int stride = 256;
  final List<({int line, int byte})> points = [(line: 0, byte: 0)];

  bool matches(FileStat other) =>
      stat.size == other.size &&
      stat.modified == other.modified &&
      stat.changed == other.changed;

  ({int line, int byte}) checkpoint(int line) {
    var low = 0;
    var high = points.length;
    while (low + 1 < high) {
      final middle = (low + high) ~/ 2;
      if (points[middle].line <= line) {
        low = middle;
      } else {
        high = middle;
      }
    }
    return points[low];
  }
}
