import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path_provider/path_provider.dart';

/// 读取系统剪贴板中的图片（桌面端粘贴图片功能）。
///
/// 底层使用 pasteboard 插件（macOS/Linux/Windows/iOS/Android 全平台）：
/// - [Pasteboard.files]：剪贴板中的文件列表（文件管理器多选复制等）
/// - [Pasteboard.image]：剪贴板中的图片数据（系统截图、浏览器复制图片等）
///
/// 语义约定（与各平台 LLM 支持的图片格式保持一致）：
/// - 支持 png/jpg/jpeg/gif/webp，直接使用原始文件，不做格式转换
/// - heic/tiff 等模型不支持的格式直接忽略（与"复制了 txt"行为一致）
/// - 文件优先：剪贴板中存在本地文件时不读取图片数据，
///   否则会把文件管理器附带的图标预览当成图片粘贴
///
/// 图片数据会先写入临时目录再返回路径，
/// 与 [Image.file] / 发送流程（按路径读取文件）保持一致。
class ClipboardImageService {
  ClipboardImageService._();

  /// 模型通用的图片格式白名单（粘贴时按此过滤）。
  @visibleForTesting
  static const Set<String> supportedExtensions = {
    'png',
    'jpg',
    'jpeg',
    'gif',
    'webp',
  };

  /// 测试注入：临时目录提供者，默认使用系统临时目录。
  @visibleForTesting
  static Future<Directory> Function() tempDirProvider = getTemporaryDirectory;

  /// 读取剪贴板中的全部图片并按就绪顺序回调：
  /// 文件路径立即回调（UI 可马上渲染占位），图片数据
  /// 处理完回调一次，避免一次性解码全部造成的卡顿；
  /// 剪贴板中没有可发送的图片时不做任何回调。
  static Future<void> readClipboardImages(
    void Function(String path) onImage,
  ) async {
    // 文件优先：文件管理器复制文件时剪贴板会同时携带图标预览数据，
    // 此时应以文件本身为准，否则发送的是图标而不是图片内容。
    final existingFiles = <String>[];
    try {
      for (final path in await Pasteboard.files()) {
        if (await File(path).exists()) existingFiles.add(path);
      }
    } catch (_) {
      // 平台不支持或读取失败（如移动端部分场景），按无图片处理
      return;
    }

    final ready = existingFiles
        .where((path) =>
            supportedExtensions.contains(_extensionOf(path).toLowerCase()))
        .toList();
    if (ready.isNotEmpty) {
      for (final path in ready) {
        onImage(path);
      }
      return;
    }
    // 剪贴板中存在本地文件但格式均不支持时，与"复制了 txt"一致，
    // 不再读取图片数据（避免把图标预览当作图片）
    if (existingFiles.isNotEmpty) return;

    // 无本地文件：读取图片数据（系统截图、浏览器复制图片等）
    Uint8List? bytes;
    try {
      bytes = await Pasteboard.image;
    } catch (_) {
      return;
    }
    if (bytes == null || bytes.isEmpty) return;
    onImage(await _writeTempFile(bytes));
  }

  static String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    final slash = path.lastIndexOf(Platform.pathSeparator);
    if (dot < 0 || (slash >= 0 && dot < slash)) return '';
    return path.substring(dot + 1);
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
