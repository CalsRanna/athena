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

  test('剪贴板中没有图片时返回 null', () async {
    mockNative((_) => null);
    expect(await ClipboardImageService.readClipboardImage(), isNull);
  });

  test('剪贴板中是图片文件时返回其路径', () async {
    final file = File('${tempDir.path}/screenshot.png');
    await file.writeAsBytes([1, 2, 3]);
    mockNative((_) => {'path': file.path});
    expect(await ClipboardImageService.readClipboardImage(), file.path);
  });

  test('返回的文件不存在时视为无图片', () async {
    mockNative((_) => {'path': '${tempDir.path}/missing.png'});
    expect(await ClipboardImageService.readClipboardImage(), isNull);
  });

  test('剪贴板中是图片数据（base64 字符串）时写入临时文件', () async {
    final bytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1, 2, 3]);
    mockNative((_) => {'base64': base64Encode(bytes)});
    final path = await ClipboardImageService.readClipboardImage();
    expect(path, isNotNull);
    expect(await File(path!).readAsBytes(), bytes);
  });

  test('剪贴板中是图片数据（Windows Uint8List）时写入临时文件', () async {
    final bytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 4, 5, 6]);
    mockNative((_) => {'base64': bytes});
    final path = await ClipboardImageService.readClipboardImage();
    expect(path, isNotNull);
    expect(await File(path!).readAsBytes(), bytes);
  });

  test('平台未注册 channel 时返回 null', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    expect(await ClipboardImageService.readClipboardImage(), isNull);
  });

  test('非法 base64 返回 null', () async {
    mockNative((_) => {'base64': 'not a base64!!'});
    expect(await ClipboardImageService.readClipboardImage(), isNull);
  });

  test('原生返回空 map 视为无图片', () async {
    mockNative((_) => <Object, Object>{});
    expect(await ClipboardImageService.readClipboardImage(), isNull);
  });
}
