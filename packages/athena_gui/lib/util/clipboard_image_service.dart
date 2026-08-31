import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// 读取系统剪贴板中的图片（桌面端粘贴图片功能）。
///
/// 原生层通过 `athena/clipboard_image` channel 返回：
/// - `{'path': '<文件路径>'}`：剪贴板中是图片文件（如文件管理器复制）
/// - `{'base64': '<PNG base64>'}`：剪贴板中是图片数据（如系统截图）
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

  /// 读取剪贴板图片，返回可发送的本地文件路径；
  /// 剪贴板中没有图片、平台不支持或读取失败时返回 null。
  static Future<String?> readClipboardImage() async {
    Map<Object?, Object?>? result;
    try {
      result = await _channel
          .invokeMethod<Map<Object?, Object?>>('readClipboardImage');
    } on MissingPluginException {
      // 平台未注册 channel（如移动端），按无图片处理
      return null;
    } on PlatformException {
      // 原生读取失败（如剪贴板被占用），回退到文本粘贴
      return null;
    }
    if (result == null) return null;

    final path = result['path'];
    if (path is String && path.isNotEmpty) {
      if (await File(path).exists()) return path;
      return null;
    }

    final base64 = result['base64'];
    Uint8List bytes;
    if (base64 is Uint8List) {
      bytes = base64;
    } else if (base64 is String) {
      try {
        bytes = base64Decode(base64);
      } on FormatException {
        return null;
      }
    } else {
      return null;
    }
    return _writeTempFile(bytes);
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
