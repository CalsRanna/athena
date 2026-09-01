import 'dart:io';

import 'package:athena_gui/util/clipboard_image_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('pasteboard');
  late Directory tempDir;
  var imageCallCount = 0;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('clipboard_image_test');
    ClipboardImageService.tempDirProvider = () async => tempDir;
    imageCallCount = 0;
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  /// mock pasteboard 插件：files 返回文件列表，image 返回图片数据。
  void mockPasteboard({
    List<String> files = const [],
    Uint8List? image,
    bool throwError = false,
  }) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (throwError) {
        throw PlatformException(code: 'test');
      }
      switch (call.method) {
        case 'files':
          return files;
        case 'image':
          imageCallCount++;
          return image;
      }
      return null;
    });
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  /// 收集回调结果。
  Future<List<String>> readAll() async {
    final result = <String>[];
    await ClipboardImageService.readClipboardImages(result.add);
    return result;
  }

  test('剪贴板中没有图片时不回调', () async {
    mockPasteboard();
    expect(await readAll(), isEmpty);
  });

  test('多选复制的图片文件按序回调', () async {
    final files = [
      for (var i = 0; i < 3; i++)
        File('${tempDir.path}/img_$i.png')..writeAsBytesSync([i]),
    ];
    mockPasteboard(files: [for (final f in files) f.path]);
    expect(await readAll(), [for (final f in files) f.path]);
  });

  test('png/jpg/jpeg/gif/webp 均支持', () async {
    final files = [
      for (final ext in ['png', 'jpg', 'jpeg', 'gif', 'webp'])
        File('${tempDir.path}/img.$ext')..writeAsBytesSync([1]),
    ];
    mockPasteboard(files: [for (final f in files) f.path]);
    expect(await readAll(), [for (final f in files) f.path]);
  });

  test('大小写扩展名不敏感', () async {
    final file = File('${tempDir.path}/IMG.PNG')..writeAsBytesSync([1]);
    mockPasteboard(files: [file.path]);
    expect(await readAll(), [file.path]);
  });

  test('不存在的文件被跳过', () async {
    final file = File('${tempDir.path}/exists.png')..writeAsBytesSync([1]);
    mockPasteboard(files: [file.path, '${tempDir.path}/missing.png']);
    expect(await readAll(), [file.path]);
  });

  test('浏览器复制（http URL 伪路径 + 图片数据）走图片数据', () async {
    final bytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1]);
    mockPasteboard(
      files: ['https://example.com/image.png', 'data:image/png;base64,xxx'],
      image: bytes,
    );
    final paths = await readAll();
    expect(paths, hasLength(1));
    expect(await File(paths.single).readAsBytes(), bytes);
  });

  test('剪贴板中是本地文件但不支持的格式（heic/tiff）时不回调也不读图片数据',
      () async {
    final heic = File('${tempDir.path}/photo.heic')..writeAsBytesSync([1]);
    final tiff = File('${tempDir.path}/scan.tiff')..writeAsBytesSync([1]);
    mockPasteboard(
      files: [heic.path, tiff.path],
      image: Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]),
    );
    expect(await readAll(), isEmpty);
    // 文件优先：本地文件存在时绝不读取图片数据（否则会读到图标预览）
    expect(imageCallCount, 0);
  });

  test('图片文件与非图片文件混合时只回调图片且不读图片数据', () async {
    final png = File('${tempDir.path}/a.png')..writeAsBytesSync([1]);
    final txt = File('${tempDir.path}/b.txt')..writeAsBytesSync([1]);
    mockPasteboard(
      files: [txt.path, png.path],
      image: Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]),
    );
    expect(await readAll(), [png.path]);
    expect(imageCallCount, 0);
  });

  test('截图（无文件、有图片数据）时写入临时文件并回调', () async {
    final bytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 2]);
    mockPasteboard(image: bytes);
    final paths = await readAll();
    expect(paths, hasLength(1));
    expect(await File(paths.single).readAsBytes(), bytes);
  });

  test('平台读取失败时不回调', () async {
    mockPasteboard(throwError: true);
    expect(await readAll(), isEmpty);
  });

  test('空截图数据视为无图片', () async {
    mockPasteboard(image: Uint8List(0));
    expect(await readAll(), isEmpty);
  });
}
