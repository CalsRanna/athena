import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// 读取系统剪贴板中的图片（桌面端粘贴图片功能）。
///
/// 原生层通过 `athena/clipboard_image` channel 返回：
/// - `{'paths': ['<文件路径>', ...]}`：剪贴板中是多个图片文件
///   （如文件管理器多选复制；兼容格式直接给路径）
/// - `{'base64s': ['<PNG base64>', ...]}`：上述场景中非兼容格式转成 PNG
/// - `{'path': '<文件路径>'}` / `{'base64': '<PNG base64>'}`：
///   旧协议的单值返回（兼容，如系统截图）
/// - null：剪贴板中没有图片
///
/// 图片数据会先写入临时目录再返回路径，
/// 与 [Image.file] / 发送流程（按路径读取文件）保持一致。
class ClipboardImageService {
  ClipboardImageService._();

  static const MethodChannel _channel = MethodChannel('athena/clipboard_image');

  /// 测试注入：临时目录提供者，默认使用系统临时目录。
  @visibleForTesting
  static Future<Directory> Function() tempDirProvider = getTemporaryDirectory;

  /// 读取剪贴板中的全部图片并按就绪顺序回调：
  /// 文件路径立即回调（UI 可马上渲染占位），需要转换的数据
  /// 每张处理完回调一次，避免一次性解码全部造成的卡顿；
  /// 剪贴板中没有图片、平台不支持或读取失败时不做任何回调。
  static Future<void> readClipboardImages(
    void Function(String path) onImage,
  ) async {
    Map<Object?, Object?>? result;
    try {
      result = await _channel
          .invokeMethod<Map<Object?, Object?>>('readClipboardImage');
    } on MissingPluginException {
      // 平台未注册 channel（如移动端），按无图片处理
      return;
    } on PlatformException {
      // 原生读取失败（如剪贴板被占用），回退到文本粘贴
      return;
    }
    if (result == null) return;

    // 新协议：文件路径无需转换，立即回调
    for (final path in _stringList(result['paths'])) {
      if (await File(path).exists()) onImage(path);
    }
    // base64 数据逐张解码写入后回调，每张之间让出事件循环，
    // 使 UI 可以先显示占位再逐步填充
    for (final bytes in _base64List(result['base64s'])) {
      await Future<void>.delayed(Duration.zero);
      onImage(await _writeTempFile(bytes));
    }

    // 旧协议兼容：单值返回
    final path = result['path'];
    if (path is String && path.isNotEmpty && await File(path).exists()) {
      onImage(path);
      return;
    }
    final bytes = _decodeBase64(result['base64']);
    if (bytes != null) {
      await Future<void>.delayed(Duration.zero);
      onImage(await _writeTempFile(bytes));
    }
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value.whereType<String>().where((s) => s.isNotEmpty).toList();
  }

  static List<Uint8List> _base64List(Object? value) {
    if (value is! List) return const [];
    final result = <Uint8List>[];
    for (final item in value) {
      final bytes = _decodeBase64(item);
      if (bytes != null) result.add(bytes);
    }
    return result;
  }

  static Uint8List? _decodeBase64(Object? value) {
    if (value is Uint8List) return value;
    if (value is String) {
      try {
        return base64Decode(value);
      } on FormatException {
        return null;
      }
    }
    return null;
  }

  static Future<String> _writeTempFile(Uint8List bytes) async {
    final directory = await tempDirProvider();
    final file = File(
      '${directory.path}${Platform.pathSeparator}'
      'athena_paste_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}
