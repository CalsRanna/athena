import 'dart:collection';

/// Bounded output with Unicode-safe head/tail retention and paged reads.
class CappedTextBuffer {
  CappedTextBuffer({this.headChars = 1 << 20, this.tailChars = 1 << 20}) {
    if (headChars < 1 || tailChars < 1) {
      throw ArgumentError('headChars and tailChars must be positive');
    }
  }

  final int headChars;
  final int tailChars;
  final List<TextChunk> _head = [];
  final Queue<TextChunk> _tail = Queue();
  int _headLength = 0;
  int _tailLength = 0;
  int totalCharacters = 0;

  bool get isEmpty => totalCharacters == 0;
  bool get endsWithNewline =>
      !isEmpty &&
      (_tail.isNotEmpty ? _tail.last : _head.last).text.endsWith('\n');
  int get retainedCharacters => _headLength + _tailLength;
  int get droppedCharacters => totalCharacters - retainedCharacters;

  void add(String text) {
    final runes = text.runes.toList();
    totalCharacters += runes.length;
    // 切成小块后分页能跳过整块，读最后一页也不需要重建整份输出。
    for (var start = 0; start < runes.length;) {
      final headRemaining = headChars - _headLength;
      final size = (runes.length - start).clamp(
        0,
        headRemaining > 0 ? headRemaining.clamp(1, 4096) : 4096,
      );
      final chunk = TextChunk(
        String.fromCharCodes(runes.sublist(start, start + size)),
        size,
      );
      start += size;
      if (headRemaining > 0) {
        _head.add(chunk);
        _headLength += size;
      } else {
        _tail.add(chunk);
        _tailLength += size;
      }
    }
    while (_tailLength > tailChars) {
      final first = _tail.removeFirst();
      final excess = _tailLength - tailChars;
      if (first.characters > excess) {
        _tail.addFirst(
          TextChunk(
            String.fromCharCodes(first.text.runes.skip(excess)),
            first.characters - excess,
          ),
        );
        _tailLength -= excess;
      } else {
        _tailLength -= first.characters;
      }
    }
  }

  Iterable<TextChunk> get chunks sync* {
    yield* _head;
    if (droppedCharacters > 0) {
      final notice =
          '\n[output truncated: $droppedCharacters characters dropped from the middle; showing head and tail]\n';
      yield TextChunk(notice, notice.length);
    }
    yield* _tail;
  }

  static ({String text, int nextOffset, bool hasMore}) readChunks(
    Iterable<TextChunk> chunks, {
    required int offset,
    required int limit,
  }) {
    if (offset < 0 || limit < 1 || limit > 24000) {
      throw ArgumentError('offset must be >= 0; limit must be 1-24000');
    }
    var skipped = 0;
    final selected = <int>[];
    for (final chunk in chunks) {
      if (skipped + chunk.characters <= offset) {
        skipped += chunk.characters;
        continue;
      }
      selected.addAll(
        chunk.text.runes
            .skip((offset - skipped).clamp(0, chunk.characters))
            .take(limit + 1 - selected.length),
      );
      skipped += chunk.characters;
      if (selected.length > limit) break;
    }
    final hasMore = selected.length > limit;
    if (hasMore) selected.removeLast();
    return (
      text: String.fromCharCodes(selected),
      nextOffset: selected.isEmpty
          ? offset.clamp(0, skipped)
          : offset + selected.length,
      hasMore: hasMore,
    );
  }
}

class TextChunk {
  const TextChunk(this.text, this.characters);
  final String text;
  final int characters;
}
