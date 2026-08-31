import 'dart:convert';
import 'dart:io';

import 'package:athena_gui/util/clipboard_image_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('athena/clipboard_image');
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('clipboard_image_test');
    ClipboardImageService.tempDirProvider = () async => tempDir;
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  void mockNative(Object? Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => handler(call));
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
    mockNative((_) => null);
    expect(await readAll(), isEmpty);
  });

  test('剪贴板中是图片文件时回调其路径', () async {
    final file = File('${tempDir.path}/screenshot.png');
    await file.writeAsBytes([1, 2, 3]);
    mockNative((_) => {'path': file.path});
    expect(await readAll(), [file.path]);
  });

  test('返回的文件不存在时视为无图片', () async {
    mockNative((_) => {'path': '${tempDir.path}/missing.png'});
    expect(await readAll(), isEmpty);
  });

  test('剪贴板中是图片数据（base64 字符串）时写入临时文件并回调', () async {
    final bytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1, 2, 3]);
    mockNative((_) => {'base64': base64Encode(bytes)});
    final paths = await readAll();
    expect(paths, hasLength(1));
    expect(await File(paths.single).readAsBytes(), bytes);
  });

  test('剪贴板中是图片数据（Windows Uint8List）时写入临时文件并回调', () async {
    final bytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 4, 5, 6]);
    mockNative((_) => {'base64': bytes});
    final paths = await readAll();
    expect(paths, hasLength(1));
    expect(await File(paths.single).readAsBytes(), bytes);
  });

  test('多选复制时全部图片文件路径按序回调', () async {
    final files = [
      for (var i = 0; i < 3; i++)
        File('${tempDir.path}/img_$i.png')..writeAsBytesSync([i]),
    ];
    mockNative(
      (_) => {'paths': [for (final f in files) f.path]},
    );
    expect(await readAll(), [for (final f in files) f.path]);
  });

  test('paths 中不存在的文件被跳过', () async {
    final file = File('${tempDir.path}/exists.png')..writeAsBytesSync([1]);
    mockNative((_) => {'paths': [file.path, '${tempDir.path}/missing.png']});
    expect(await readAll(), [file.path]);
  });

  test('paths 与 base64s 混合时文件路径先回调', () async {
    final file = File('${tempDir.path}/a.png')..writeAsBytesSync([1]);
    final bytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 9]);
    mockNative(
      (_) => {'paths': [file.path], 'base64s': [base64Encode(bytes)]},
    );
    final paths = await readAll();
    expect(paths, hasLength(2));
    expect(paths.first, file.path);
    expect(await File(paths.last).readAsBytes(), bytes);
  });

  test('base64s 为字符串数组时全部写入临时文件', () async {
    final bytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 7]);
    mockNative((_) => {'base64s': [base64Encode(bytes), base64Encode(bytes)]});
    final paths = await readAll();
    expect(paths, hasLength(2));
    for (final path in paths) {
      expect(await File(path).readAsBytes(), bytes);
    }
  });

  test('平台未注册 channel 时不回调', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    expect(await readAll(), isEmpty);
  });

  test('非法 base64 不回调', () async {
    mockNative((_) => {'base64': 'not a base64!!'});
    expect(await readAll(), isEmpty);
  });

  test('原生返回空 map 视为无图片', () async {
    mockNative((_) => <Object, Object>{});
    expect(await readAll(), isEmpty);
  });
}
