import 'dart:async';
import 'dart:io';

import 'package:athena_core/storage/file_lock.dart';
import 'package:athena_core/storage/user_settings_store.dart';
import 'package:athena_gui/util/window_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  final binding = _WindowTestBinding();
  const windowChannel = MethodChannel('window_manager');
  const screenChannel = MethodChannel(
    'dev.leanflutter.plugins/screen_retriever',
  );
  late Directory tmp;
  late UserSettingsStore settings;
  late List<MethodCall> calls;
  late Size size;
  late bool maximized;
  late bool fullScreen;
  Future<void> Function(MethodCall)? beforeCall;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('athena_window_');
    settings = UserSettingsStore(
      file: File(p.join(tmp.path, 'setting.yaml')),
      locks: LockRegistry(tmp),
    );
    calls = [];
    size = const Size(800, 600);
    maximized = false;
    fullScreen = false;
    beforeCall = null;
    binding.rasterized = Completer<void>();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(windowChannel, (
      call,
    ) async {
      calls.add(call);
      await beforeCall?.call(call);
      if (call.method == 'setBounds') {
        final args = call.arguments as Map<Object?, Object?>;
        if (args.containsKey('width')) {
          size = Size(args['width'] as double, args['height'] as double);
        }
      }
      return switch (call.method) {
        'isMaximized' => maximized,
        'isFullScreen' => fullScreen,
        'isMinimized' => false,
        'getBounds' => {
          'x': 0.0,
          'y': 0.0,
          'width': size.width,
          'height': size.height,
        },
        _ => null,
      };
    });
    const display = {
      'id': 'primary',
      'size': {'width': 1920.0, 'height': 1080.0},
      'visiblePosition': {'dx': 0.0, 'dy': 0.0},
      'visibleSize': {'width': 1920.0, 'height': 1080.0},
    };
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      screenChannel,
      (call) async => switch (call.method) {
        'getPrimaryDisplay' => display,
        'getAllDisplays' => {
          'displays': [display],
        },
        'getCursorScreenPoint' => {'dx': 10.0, 'dy': 10.0},
        _ => null,
      },
    );
  });

  tearDown(() async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      windowChannel,
      null,
    );
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      screenChannel,
      null,
    );
    await tmp.delete(recursive: true);
  });

  test(
    'initialization waits for native configuration without showing',
    () async {
      final configuring = Completer<void>();
      final configured = Completer<void>();
      beforeCall = (call) async {
        if (call.method == 'setTitle') {
          configuring.complete();
          await configured.future;
        }
      };
      bool initialized = false;
      final initialization = WindowUtil.instance
          .ensureInitialized(settings: settings, backgroundColor: Colors.white)
          .then((_) => initialized = true);

      await Future.any([configuring.future, initialization]);
      await Future<void>.delayed(Duration.zero);
      expect(initialized, isFalse);
      expect(calls.map((call) => call.method), isNot(contains('show')));
      configured.complete();
      await initialization;

      expect(initialized, isTrue);
      expect(calls.last.method, 'setPreventClose');
      expect(calls.map((call) => call.method), isNot(contains('show')));
    },
  );

  test('saved dimensions are applied and centered before showing', () async {
    await settings.setDouble('window_width', 1400);
    await settings.setDouble('window_height', 900);
    await WindowUtil.instance.ensureInitialized(settings: settings);

    expect(size, const Size(1400, 900));
    final position = calls.lastWhere((call) => call.method == 'setBounds');
    expect(position.arguments, containsPair('x', 260.0));
    expect(position.arguments, containsPair('y', 90.0));
    expect(calls.map((call) => call.method), isNot(contains('show')));
  });

  test('legacy undersized dimensions are clamped before centering', () async {
    await settings.setDouble('window_width', 800);
    await settings.setDouble('window_height', 600);
    await WindowUtil.instance.ensureInitialized(settings: settings);

    expect(size, const Size(1080, 720));
    final position = calls.lastWhere((call) => call.method == 'setBounds');
    expect(position.arguments, containsPair('x', 420.0));
    expect(position.arguments, containsPair('y', 180.0));
  });

  test('activation waits for rasterization, then supports reopening', () async {
    final showing = WindowUtil.instance.show();
    await Future<void>.delayed(Duration.zero);
    expect(calls, isEmpty);

    binding.rasterized.complete();
    await showing;
    expect(calls.map((call) => call.method), [
      'setSkipTaskbar',
      'isMinimized',
      'show',
      'focus',
    ]);

    await WindowUtil.instance.hide();
    calls.clear();
    await WindowUtil.instance.show();
    expect(calls.map((call) => call.method), [
      'setSkipTaskbar',
      'isMinimized',
      'show',
      'focus',
    ]);
  });

  test('debounced save persists the current window size', () async {
    WindowUtil.instance.saveWindowSize(settings);
    await Future<void>.delayed(const Duration(milliseconds: 800));

    expect(await settings.getDouble('window_width'), 800.0);
    expect(await settings.getDouble('window_height'), 600.0);
  });

  test('maximized or full screen window keeps the windowed size', () async {
    maximized = true;
    WindowUtil.instance.saveWindowSize(settings);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    expect(await settings.getDouble('window_width'), isNull);

    // 全屏时 isMaximized 为 false，只挡最大化会让下一次启动开出屏幕大小
    maximized = false;
    fullScreen = true;
    WindowUtil.instance.saveWindowSize(settings);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    expect(await settings.getDouble('window_width'), isNull);
  });
}

class _WindowTestBinding extends AutomatedTestWidgetsFlutterBinding {
  Completer<void> rasterized = Completer<void>();

  @override
  Future<void> get waitUntilFirstFrameRasterized => rasterized.future;
}
