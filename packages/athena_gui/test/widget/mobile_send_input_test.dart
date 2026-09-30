import 'dart:io';

import 'package:athena_core/repository/chat_repository.dart';
import 'package:athena_gui/di.dart';
import 'package:athena_gui/page/mobile/chat/chat.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 移动端发送入口的接线：页面必须走 [ChatViewModel.prepareUserInput]。
///
/// 页面此前自己写了一遍发送流程，判空用的是**未 trim** 的文本——纯空白的输入
/// 会被当成一条消息发出去，而且会先建出一条永远发不出去的空白对话。把页面改回
/// 旧写法，这条会红。
///
/// 「没有启用模型时不发送」由 `test/view_model/chat_view_model_test.dart` 覆盖
/// （走 VM 更直接，不必在 FakeAsync 里驱动真实 IO）。
void main() {
  late Directory tempRoot;

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Athena',
      packageName: 'com.athena',
      version: '0.0.0',
      buildNumber: '0',
      buildSignature: '',
    );
    tempRoot = Directory.systemTemp.createTempSync('athena_mobile_send');
    DI.ensureInitialized(homeDirOverride: tempRoot.path);
  });

  tearDown(() async {
    await GetIt.instance.reset();
    if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
  });

  testWidgets('纯空白输入不发送，也不新建对话', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAthenaThemeData(AthenaColorMode.light),
        home: const MobileChatPage(),
      ),
    );

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.byIcon(LucideIcons.arrowUp));
    // 纯空白在 prepareUserInput 里第一段就返回，不触发任何 IO，pump 一次即可
    await tester.pump();

    final controller = tester
        .widget<TextField>(find.byType(TextField))
        .controller!;
    expect(controller.text, '   ', reason: '没发出去，输入框不该被清空');

    // 真实文件 IO 必须在 runAsync 里跑：FakeAsync 下它永远不会完成
    final chats = await tester.runAsync(
      () => GetIt.instance<ChatRepository>().getAllChats(),
    );
    expect(chats, isEmpty, reason: '也不该落出一条空白草稿对话');
  });
}
