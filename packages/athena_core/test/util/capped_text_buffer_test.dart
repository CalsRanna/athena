import 'package:athena_core/util/capped_text_buffer.dart';
import 'package:test/test.dart';

void main() {
  test('output stays bounded and reports omitted characters', () {
    final buffer = CappedTextBuffer(headChars: 5, tailChars: 5);
    buffer.add('HELLO${'x' * 1000}WORLD');
    expect(buffer.retainedCharacters, 10);
    expect(buffer.droppedCharacters, 1000);
    final text = buffer.chunks.map((c) => c.text).join();
    expect(text, startsWith('HELLO'));
    expect(text, endsWith('WORLD'));
    expect(text, contains('1000 characters dropped'));
  });

  test('paging preserves non-BMP characters across head and tail', () {
    final buffer = CappedTextBuffer(headChars: 3, tailChars: 3);
    for (final text in ['A😀', '中文', 'B🌟']) {
      buffer.add(text);
    }
    final all = buffer.chunks.map((c) => c.text).join();
    final first = CappedTextBuffer.readChunks(
      buffer.chunks,
      offset: 0,
      limit: 2,
    );
    final second = CappedTextBuffer.readChunks(
      buffer.chunks,
      offset: first.nextOffset,
      limit: 4,
    );
    expect(first.text, 'A😀');
    expect(first.text + second.text, all);
    expect(second.hasMore, isFalse);
    expect(buffer.retainedCharacters, 6);
  });
}
