import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:athena_core/entity/approval_mode.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/repository/chat_repository.dart';
import 'package:athena_gui/di.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:athena_gui/view_model/pending_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 桌面与移动的发送流程此前各写一遍，移动端漏了 trim、模型校验与竞态重查。
/// 两边现在都走 [ChatViewModel.prepareUserInput]，这些断言锁住「能不能发、
/// 发什么、发给哪条对话」——呈现（输入框、滚动、弹窗）留在各自页面。
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
    tempRoot = Directory.systemTemp.createTempSync('athena_prepare_input');
    DI.ensureInitialized(homeDirOverride: tempRoot.path);
    viewModel = GetIt.instance<ChatViewModel>();
  });

  tearDown(() async {
    await GetIt.instance.reset();
    if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
  });

  Future<bool> modelsReady() async => true;
  Future<bool> modelsMissing() async => false;

  ChatEntity chat() => ChatEntity(
    id: 'c1',
    title: 't',
    modelId: 'm1',
    sentinelId: null,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  void selectUsableModel() {
    viewModel.currentModel.value = ModelEntity(
      id: 'm1',
      name: 'M',
      modelId: 'm1',
      providerId: 'p1',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
  }

  testWidgets('纯空白输入不发送', (tester) async {
    // 移动端此前用未 trim 的文本判空，「   」会被当成一条消息发出去。
    final result = await viewModel.prepareUserInput(
      text: '  \n ',
      images: const [],
      ensureModelsReady: modelsReady,
      // stillValid 恒 false 是刻意的闸：万一 trim 被去掉，这条会在
      // ensureModelsReady 之后被判为 superseded 而**干净地失败**；不设这道闸
      // 它会一路走到 createChat() 的真实文件 IO，在 FakeAsync 里永远不返回
      // ——挂起的测试比失败的测试难查得多。
      stillValid: (target, draftJustCreated) => false,
    );

    expect(result.outcome, SendUserInputOutcome.emptyInput);
    expect(result.message, isNull);
  });

  testWidgets('没有启用的模型时不发送，也不落草稿', (tester) async {
    // 移动端此前完全不检查模型；这里必须在建草稿之前就拦住——否则会留下
    // 一条永远发不出去的空白对话。
    final result = await viewModel.prepareUserInput(
      text: 'hello',
      images: const [],
      ensureModelsReady: modelsMissing,
    );

    expect(result.outcome, SendUserInputOutcome.noEnabledModels);
    expect(result.message, isNull);
    expect(result.chat, isNull);
  });

  testWidgets('附件还没解码完就不发送', (tester) async {
    final result = await viewModel.prepareUserInput(
      text: 'hello',
      images: [PendingImage(stage: PendingImageStage.decoding)],
      ensureModelsReady: modelsReady,
    );

    expect(result.outcome, SendUserInputOutcome.imagesNotReady);
  });

  testWidgets('等待模型列表期间被判定为过期就不再继续', (tester) async {
    final result = await viewModel.prepareUserInput(
      text: 'hello',
      images: const [],
      ensureModelsReady: modelsReady,
      // 模拟 await 期间页面被拆掉/切了对话
      stillValid: (target, draftJustCreated) => false,
    );

    expect(result.outcome, SendUserInputOutcome.superseded);
    expect(result.message, isNull);
  });

  testWidgets('两处重查拿到的口径不同：落草稿前 target 还是来源对话', (tester) async {
    final seen = <(ChatEntity?, bool)>[];

    await viewModel.prepareUserInput(
      text: 'hello',
      images: const [],
      ensureModelsReady: modelsReady,
      stillValid: (target, draftJustCreated) {
        seen.add((target, draftJustCreated));
        return false;
      },
    );

    expect(seen, hasLength(1));
    expect(seen.single.$1, isNull, reason: '草稿还没落盘，target 仍是传入的 null');
    expect(seen.single.$2, isFalse);
  });

  testWidgets('传入现成对话时，第二处重查拿到的 draftJustCreated 仍是 false', (tester) async {
    // 传成恒 true 会把「页面开着 X、当前对话是 Y」这种本来发得出去的情况
    // 静默判成过期——移动端的 _resolveChat 就会产生这种组合。
    final seen = <(ChatEntity?, bool)>[];

    final result = await viewModel.prepareUserInput(
      text: 'hello',
      images: const [],
      chat: chat(),
      ensureModelsReady: modelsReady,
      stillValid: (target, draftJustCreated) {
        seen.add((target, draftJustCreated));
        return true;
      },
    );

    expect(seen, hasLength(2), reason: '两处重查都会走');
    expect(seen.map((s) => s.$2), [false, false]);
    expect(seen.last.$1?.id, 'c1');
    // 没有可用模型，所以停在 noModel
    expect(result.outcome, SendUserInputOutcome.noModel);
  });

  testWidgets('对话没有可用模型时不发送，但带回目标对话', (tester) async {
    final result = await viewModel.prepareUserInput(
      text: 'hello',
      images: const [],
      chat: chat(),
      ensureModelsReady: modelsReady,
    );

    expect(result.outcome, SendUserInputOutcome.noModel);
    expect(result.message, isNull);
    expect(result.chat?.id, 'c1');
  });

  testWidgets('文本 trim 后作为正文，附件编码进 imageUrls', (tester) async {
    selectUsableModel();
    final bytes = Uint8List.fromList([1, 2, 3]);

    final result = await viewModel.prepareUserInput(
      text: '  hello  ',
      images: [PendingImage(stage: PendingImageStage.ready, bytes: bytes)],
      chat: chat(),
      ensureModelsReady: modelsReady,
    );

    expect(result.outcome, SendUserInputOutcome.sent);
    expect(result.message?.content, 'hello');
    expect(result.message?.chatId, 'c1');
    expect(result.message?.role, 'user');
    expect(result.message?.imageUrls, base64Encode(bytes));
  });

  testWidgets('没有附件时 imageUrls 为空串', (tester) async {
    selectUsableModel();

    final result = await viewModel.prepareUserInput(
      text: 'hello',
      images: const [],
      chat: chat(),
      ensureModelsReady: modelsReady,
    );

    expect(result.message?.imageUrls, '');
  });

  /// 会话参数更新的表征测试。
  ///
  /// 这一段在 ViewModel 里是同一个模式抄了七遍（清错误 → 落库 → 就地更新列表 →
  /// 同步草稿态信号），每遍自带一份 try/catch。合并之前先把可观测行为钉住：三条
  /// 覆盖三种形状——值取自落库结果（retention）、值取自调用方（approvalMode）、
  /// 可空值（workspacePath）。
  group('会话参数更新', () {
    Future<ChatEntity> seedChat() async {
      final repo = GetIt.instance<ChatRepository>();
      final id = await repo.createChat(
        ChatEntity(
          title: '参数',
          modelId: 'm1',
          sentinelId: null,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
      await viewModel.getChats();
      return (await repo.getChatById(id))!;
    }

    testWidgets('retention：落库、两条列表与草稿态信号都跟上', (tester) async {
      await tester.runAsync(() async {
        final chat = await seedChat();
        viewModel.currentChat.value = chat;

        await viewModel.updateRetention(7, chat: chat);

        expect(viewModel.error.value, isNull);
        expect(viewModel.chats.value.single.retention, 7);
        expect(viewModel.chatHistories.value.single.chat.retention, 7);
        expect(viewModel.currentChat.value?.retention, 7, reason: '当前对话要跟着更新');
        expect(viewModel.currentRetention.value, 7);
      });
    });

    testWidgets('approvalMode：落库并同步', (tester) async {
      await tester.runAsync(() async {
        final chat = await seedChat();
        viewModel.currentChat.value = chat;
        const mode = ApprovalMode.bypass;

        await viewModel.updateApprovalMode(mode, chat: chat);

        expect(viewModel.error.value, isNull);
        expect(viewModel.chats.value.single.approvalMode, mode);
        expect(viewModel.currentApprovalMode.value, mode);
      });
    });

    testWidgets('workspacePath：可以清空成 null', (tester) async {
      await tester.runAsync(() async {
        final chat = await seedChat();
        viewModel.currentChat.value = chat;
        await viewModel.updateWorkspacePath('/tmp/x', chat: chat);
        expect(viewModel.chats.value.single.workspacePath, '/tmp/x');

        await viewModel.updateWorkspacePath(null, chat: chat);

        expect(viewModel.chats.value.single.workspacePath, isNull);
        expect(viewModel.currentWorkspacePath.value, isNull);
      });
    });
  });

  /// 失败以事件形式发出去，由页面呈现（`ChatErrorDialogListener`）。
  ///
  /// ViewModel 不再自己弹对话框：此前那是仓库里唯一一处 VM 直接调 AthenaDialog，
  /// 于是任何会报错的路径都要求 Router 已挂载，测试也没法在无 UI 的情况下跑。
  testWidgets('失败会作为事件发到 errors 流', (tester) async {
    final seen = <String>[];
    final subscription = viewModel.errors.listen(seen.add);
    addTearDown(subscription.cancel);

    // 隔离的空数据目录里没有可用模型，createChat 走失败分支
    final created = await tester.runAsync(() => viewModel.createChat());
    // 广播流是异步投递的，让微任务跑完
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));

    expect(created, isNull);
    expect(seen, ['Failed to create chat']);
    expect(viewModel.error.value, 'Failed to create chat', reason: '状态也要留痕');
  });

  /// 置顶的表征测试。
  ///
  /// 它同时在改写前后成立——这是一次性能重构，行为必须不变：原先无论成败都
  /// `await getChats()`（重读整个 sessions/ 目录两趟），改成按同一条排序口径
  /// 就地更新两条平行列表。下面钉住的正是「就地更新容易改错的地方」：标志位、
  /// 两条列表的顺序一致、以及不重复不丢。
  group('置顶', () {
    Future<void> seedTwoChats() async {
      final repo = GetIt.instance<ChatRepository>();
      for (final (title, day) in [('旧', 1), ('新', 2)]) {
        await repo.createChat(
          ChatEntity(
            title: title,
            modelId: 'm1',
            sentinelId: null,
            createdAt: DateTime(2026, 1, day),
            updatedAt: DateTime(2026, 1, day),
          ),
        );
      }
      await viewModel.getChats();
    }

    List<String> ids(List<ChatEntity> chats) => [
      for (final chat in chats) chat.title,
    ];

    testWidgets('置顶较旧的一条：两条列表都翻到最前，顺序一致', (tester) async {
      await tester.runAsync(() async {
        await seedTwoChats();
        expect(ids(viewModel.chats.value), ['新', '旧'], reason: '前置条件：按更新时间倒序');

        await viewModel.togglePin(viewModel.chats.value[1]);

        expect(ids(viewModel.chats.value), ['旧', '新']);
        expect(viewModel.chats.value.first.pinned, isTrue);
        expect(ids([for (final h in viewModel.chatHistories.value) h.chat]), [
          '旧',
          '新',
        ], reason: '两条平行列表必须同序，侧栏按它们配对渲染');
        expect(
          viewModel.chatHistories.value.first.chat.pinned,
          isTrue,
          reason: 'history 里那份 chat 也要跟着翻',
        );
      });
    });

    testWidgets('取消置顶：标志位回到 false，不重复不丢', (tester) async {
      await tester.runAsync(() async {
        await seedTwoChats();
        final target = viewModel.chats.value[1];
        await viewModel.togglePin(target);
        expect(viewModel.chats.value.first.pinned, isTrue);

        await viewModel.togglePin(viewModel.chats.value.first);

        expect(viewModel.chats.value, hasLength(2));
        expect(viewModel.chatHistories.value, hasLength(2));
        expect(ids(viewModel.chats.value).toSet(), {
          '新',
          '旧',
        }, reason: '就地更新不能漏掉或多出条目');
        expect(viewModel.chats.value.every((chat) => !chat.pinned), isTrue);
      });
    });
  });
}
