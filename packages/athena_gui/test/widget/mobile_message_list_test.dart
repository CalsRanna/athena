import 'dart:io';

import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/repository/chat_repository.dart';
import 'package:athena_core/repository/message_repository.dart';
import 'package:athena_gui/component/message_list_scroll_controller.dart';
import 'package:athena_gui/di.dart';
import 'package:athena_gui/page/mobile/chat/component/message_list_view.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:athena_gui/view_model/sentinel_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../support/athena_test_scope.dart';

import 'package:athena_gui/theme/athena_material_theme.dart';

/// 移动消息列表的滚动视图必须从第一帧就存在：历史加载期间也保留同一个
/// [CustomScrollView]，否则加载完成后 ScrollPosition 会从 0 重建，列表先闪
/// 一下顶部再被贴底校正拉回底部。
void main() {
  late Directory tempRoot;
  late ChatViewModel viewModel;

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Athena',
      packageName: 'com.athena',
      version: '0.0.0',
      buildNumber: '0',
      buildSignature: '',
    );
    tempRoot = Directory.systemTemp.createTempSync(
      'athena_mobile_message_list',
    );
    DI.ensureInitialized(homeDirOverride: tempRoot.path);
    viewModel = GetIt.instance<ChatViewModel>();
  });

  tearDown(() async {
    await GetIt.instance.reset();
    if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
  });

  testWidgets('保留滚动视图并渲染历史消息', (tester) async {
    late ChatEntity chat;
    await tester.runAsync(() async {
      final chatRepo = GetIt.instance<ChatRepository>();
      final id = await chatRepo.createChat(
        ChatEntity(
          title: 'History',
          modelId: '1',
          sentinelId: ChatEntity.noSentinelId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await GetIt.instance<MessageRepository>().storeMessage(
        MessageEntity(chatId: id, role: 'user', content: '历史消息'),
      );
      await viewModel.getChats();
      chat = (await chatRepo.getChatById(id))!;
      await viewModel.selectChat(chat);
    });

    final controller = MessageListScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAthenaThemeData(AthenaColorMode.light)
            .copyWith(platform: TargetPlatform.iOS),
        builder: (context, child) => AthenaTestScope(child: child!),
        home: Scaffold(
          body: MessageListView(
            chat: chat,
            viewModel: viewModel,
            sentinelViewModel: GetIt.instance<SentinelViewModel>(),
            controller: controller,
            onRewind: (_) async {},
            onChatTitleChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(find.text('历史消息'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
