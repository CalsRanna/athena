import 'package:nocterm/nocterm.dart';

/// 包装 [TerminalBackend],在输出层过滤 OSC 52 剪贴板写入序列。
///
/// 背景:macOS 26.4+ 对程序通过 OSC 52 写系统剪贴板会弹出安全警告
/// ("A terminal program tried to write to your clipboard")。nocterm 在
/// 粘贴事件处理时会调用 `ClipboardManager.copy` 把粘贴内容**写回**系统
/// 剪贴板(terminal_binding.dart),当终端(如 Warp)在启动时把剪贴板内容
/// 作为粘贴事件推给应用时,就会触发该警告。
///
/// 此包装拦截 `ESC ] 52 ; c ; <base64>`(BEL/ST 终止)序列,让 athena
/// 完全不写系统剪贴板,从而消除警告。不影响其他 OSC 序列(如
/// `ESC ] 10;`/`ESC ] 11;` 前景/背景色查询)。
class NoClipboardBackend implements TerminalBackend {
  NoClipboardBackend(this._inner);

  final TerminalBackend _inner;

  /// OSC 52 剪贴板写入(目标 c):`\x1b]52;c;<base64>` 以 BEL(`\x07`)
  /// 或 ST(`\x1b\`)终止。
  static final RegExp _osc52Copy =
      RegExp(r'\x1b\]52;c;[^\x07\x1b\\]*(\x07|\x1b\\)');

  @override
  void writeRaw(String data) {
    final filtered = data.replaceAll(_osc52Copy, '');
    if (filtered.isNotEmpty) {
      _inner.writeRaw(filtered);
    }
  }

  @override
  Size getSize() => _inner.getSize();

  @override
  bool get supportsSize => _inner.supportsSize;

  @override
  Stream<List<int>>? get inputStream => _inner.inputStream;

  @override
  Stream<Size>? get resizeStream => _inner.resizeStream;

  @override
  Stream<void>? get shutdownStream => _inner.shutdownStream;

  @override
  void enableRawMode() => _inner.enableRawMode();

  @override
  void disableRawMode() => _inner.disableRawMode();

  @override
  bool get isAvailable => _inner.isAvailable;

  @override
  void requestExit([int exitCode = 0]) => _inner.requestExit(exitCode);

  @override
  void notifySizeChanged(Size newSize) => _inner.notifySizeChanged(newSize);

  @override
  void dispose() => _inner.dispose();
}
