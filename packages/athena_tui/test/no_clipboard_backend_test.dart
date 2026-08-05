import 'package:athena_tui/no_clipboard_backend.dart';
import 'package:nocterm/nocterm.dart' as nocterm;
import 'package:test/test.dart';

/// 记录写入内容的假 backend。
class _RecordingBackend implements nocterm.TerminalBackend {
  final buffer = StringBuffer();

  @override
  void writeRaw(String data) => buffer.write(data);

  @override
  nocterm.Size getSize() => const nocterm.Size(80, 24);

  @override
  bool get supportsSize => true;

  @override
  Stream<List<int>>? get inputStream => null;

  @override
  Stream<nocterm.Size>? get resizeStream => null;

  @override
  Stream<void>? get shutdownStream => null;

  @override
  void enableRawMode() {}

  @override
  void disableRawMode() {}

  @override
  bool get isAvailable => true;

  @override
  void notifySizeChanged(nocterm.Size newSize) {}

  @override
  void requestExit([int exitCode = 0]) {}

  @override
  void dispose() {}
}

void main() {
  group('NoClipboardBackend', () {
    test('过滤 OSC 52 剪贴板写入序列(BEL 终止)', () {
      final inner = _RecordingBackend();
      final backend = NoClipboardBackend(inner);

      backend.writeRaw('普通文本\x1b]52;c;SGVsbG8=\x07更多文本');

      expect(inner.buffer.toString(), '普通文本更多文本');
    });

    test('过滤 OSC 52 剪贴板写入序列(ST 终止)', () {
      final inner = _RecordingBackend();
      final backend = NoClipboardBackend(inner);

      backend.writeRaw('\x1b]52;c;SGVsbG8=\x1b\\');

      expect(inner.buffer.toString(), isEmpty);
    });

    test('过滤 OSC 52 清空剪贴板序列', () {
      final inner = _RecordingBackend();
      final backend = NoClipboardBackend(inner);

      backend.writeRaw('\x1b]52;c;\x07');

      expect(inner.buffer.toString(), isEmpty);
    });

    test('保留前景/背景色查询 OSC 序列', () {
      final inner = _RecordingBackend();
      final backend = NoClipboardBackend(inner);

      backend.writeRaw('\x1b]10;#6ABEB9\x07');
      backend.writeRaw('\x1b]11;#282828\x07');

      expect(inner.buffer.toString(), '\x1b]10;#6ABEB9\x07\x1b]11;#282828\x07');
    });

    test('保留主选择(p 目标)的 OSC 52', () {
      final inner = _RecordingBackend();
      final backend = NoClipboardBackend(inner);

      backend.writeRaw('\x1b]52;p;SGVsbG8=\x07');

      expect(inner.buffer.toString(), '\x1b]52;p;SGVsbG8=\x07');
    });

    test('保留普通 ANSI 控制序列', () {
      final inner = _RecordingBackend();
      final backend = NoClipboardBackend(inner);

      backend.writeRaw('\x1b[?1049h\x1b[2J\x1b[H');

      expect(inner.buffer.toString(), '\x1b[?1049h\x1b[2J\x1b[H');
    });
  });
}
