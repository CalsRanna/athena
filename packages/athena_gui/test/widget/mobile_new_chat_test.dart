import 'dart:io';

import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/repository/chat_repository.dart';
import 'package:athena_core/repository/message_repository.dart';
import 'package:athena_gui/di.dart';
import 'package:athena_gui/page/mobile/chat/chat.dart';
import 'package:athena_gui/page/mobile/chat/component/message_list_view.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_theme.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 移动端从某条对话出来再点「新对话」：页面一打开就是空白草稿。进入草稿态
/// 要等模型与角色两段 IO，这段时间 ViewModel 的当前对话还是上一条——不能
/// 先把它的消息闪出来。
void main() {
  late Directory tempRoot;
  late ChatViewModel viewModel;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Athena',
      packageName: 'com.athena',
      version: '0.0.0',
      buildNumber: '0',
      buildSignature: '',
    );
    tempRoot = Directory.systemTemp.createTempSync('athena_mobile_new_chat');
    DI.ensureInitialized(homeDirOverride: tempRoot.path);
    viewModel = GetIt.instance<ChatViewModel>();
  });

  tearDown(() async {
    await GetIt.instance.reset();
    if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
  });

  testWidgets('新对话页第一帧就是草稿，不显示上一条对话', (tester) async {
    await tester.runAsync(() async {
      final chatRepo = GetIt.instance<ChatRepository>();
      final id = await chatRepo.createChat(
        ChatEntity(
          title: 'Previous',
          modelId: '1',
          sentinelId: ChatEntity.noSentinelId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await GetIt.instance<MessageRepository>().storeMessage(
        MessageEntity(chatId: id, role: 'user', content: '上一条对话的内容'),
      );
      await viewModel.getChats();
      await viewModel.selectChat((await chatRepo.getChatById(id))!);
    });
    expect(viewModel.currentChat.value?.title, 'Previous');

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAthenaThemeData(AthenaColorMode.light),
        home: const MobileChatPage(),
      ),
    );

    expect(find.byType(MessageListView), findsNothing);
    expect(find.text('上一条对话的内容'), findsNothing);
  });
}
