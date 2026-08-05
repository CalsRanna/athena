import 'package:athena_tui/ui/text_util.dart';
import 'package:test/test.dart';

void main() {
  group('sanitizeAnsi', () {
    test('keeps plain text and newlines intact', () {
      expect(sanitizeAnsi('hello\nworld\tok'), 'hello\nworld\tok');
      expect(sanitizeAnsi(''), '');
    });

    test('strips CSI sequences (clear screen, cursor move, colors)', () {
      expect(sanitizeAnsi('a\x1b[2Jb'), 'ab');
      expect(sanitizeAnsi('a\x1b[1;31mred\x1b[0m'), 'ared');
      expect(sanitizeAnsi('\x1b[?25lhidden cursor'), 'hidden cursor');
      expect(sanitizeAnsi('\x1b[10;10H'), '');
    });

    test('strips OSC sequences (title, clipboard OSC 52)', () {
      expect(sanitizeAnsi('a\x1b]0;evil-title\x07b'), 'ab');
      expect(sanitizeAnsi('a\x1b]52;c;base64data\x07b'), 'ab');
      // ST 终止（ESC \）
      expect(sanitizeAnsi('a\x1b]52;c;data\x1b\\b'), 'ab');
    });

    test('strips other escape sequences and C0 control chars', () {
      expect(sanitizeAnsi('a\x1bXb'), 'ab'); // 两字节 ESC 序列
      expect(sanitizeAnsi('a\x07b'), 'ab'); // BEL
      expect(sanitizeAnsi('a\x08b'), 'ab'); // BS
      expect(sanitizeAnsi('a\x0Bb'), 'ab'); // VT
      expect(sanitizeAnsi('a\x7Fb'), 'ab'); // DEL
    });

    test('truncated / fragmented escape sequences are fully removed', () {
      // 分片到达：只有 ESC[ 没有最终字节
      expect(sanitizeAnsi('a\x1b[2J'), 'a');
      expect(sanitizeAnsi('\x1b[31'), '');
      // OSC 未终止
      expect(sanitizeAnsi('\x1b]52;c;x'), '');
    });

    test('trailing lone ESC is removed', () {
      expect(sanitizeAnsi('abc\x1b'), 'abc');
    });
  });
}
