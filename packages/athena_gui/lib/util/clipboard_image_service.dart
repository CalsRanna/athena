import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
/// 交给 composer 读取、验证并保留同一份字节用于预览与发送。
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

  /// 原生剪贴板没有字节进度，读取与落盘只报告真实阶段。
  /// 没有图片返回空列表；读取失败交给输入框展示错误。
  static Future<List<String>> readClipboardImages({
    VoidCallback? onPreparing,
  }) async {
    // 文件优先：文件管理器复制文件时剪贴板会同时携带图标预览数据，
    // 此时应以文件本身为准，否则发送的是图标而不是图片内容。
    final existingFiles = <String>[];
    try {
      for (final path in await Pasteboard.files()) {
        if (await File(path).exists()) existingFiles.add(path);
      }
    } on MissingPluginException {
      // 有些平台仅提供图片读取，不能因文件列表接口缺席而漏掉截图。
    }

    final ready = existingFiles
        .where((path) =>
            supportedExtensions.contains(_extensionOf(path).toLowerCase()))
        .toList();
    if (ready.isNotEmpty) {
      return ready;
    }
    // 剪贴板中存在本地文件但格式均不支持时，与"复制了 txt"一致，
    // 不再读取图片数据（避免把图标预览当作图片）
    if (existingFiles.isNotEmpty) return [];

    // 无本地文件：读取图片数据（系统截图、浏览器复制图片等）
    final bytes = await Pasteboard.image;
    if (bytes == null || bytes.isEmpty) return [];
    onPreparing?.call();
    return [await _writeTempFile(bytes)];
  }

  static String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    final slash = path.lastIndexOf(Platform.pathSeparator);
    if (dot < 0 || (slash >= 0 && dot < slash)) return '';
    return path.substring(dot + 1);
  }

  static Future<String> _writeTempFile(Uint8List bytes) async {
    final directory = await tempDirProvider();
    final temp = await directory.createTemp('athena_paste_');
    final file = File('${temp.path}${Platform.pathSeparator}image.png');
    final writing = File('${file.path}.tmp');
    await writing.writeAsBytes(bytes, flush: true);
    await writing.rename(file.path);
    return file.path;
  }
}
