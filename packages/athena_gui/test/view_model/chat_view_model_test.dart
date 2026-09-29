import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_gui/di.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:athena_gui/view_model/pending_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 桌面与移动的发送流程此前各写一遍，移动端漏了 trim、模型校验与竞态重查。
/// 两边现在都走 [ChatViewModel.prepareUserInput]，这些断言锁住「能不能发、
/// 发什么、发给哪条对话」——呈现（输入框、滚动、弹窗）留在各自页面。
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
}
