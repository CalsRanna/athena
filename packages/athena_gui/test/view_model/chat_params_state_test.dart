import 'dart:io';

import 'package:athena_core/entity/approval_mode.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/service/chat_update_service.dart';
import 'package:athena_gui/di.dart';
import 'package:athena_gui/view_model/chat_params_state.dart';
import 'package:athena_gui/view_model/model_view_model.dart';
import 'package:athena_gui/view_model/sentinel_view_model.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 当前会话参数的契约。
///
/// 这块的难点全在写入口径上，所以断言也集中在写入口径：切对话时八个值一起换、
/// 角色的两种「没有」要分开、草稿起点哪些继承哪些不继承。这些原先散在 ViewModel
/// 的多个方法里，只能靠 widget 测试间接覆盖。
void main() {
  late Directory tempRoot;
  late ChatParamsState params;
  late SentinelViewModel sentinels;

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Athena',
      packageName: 'com.athena',
      version: '0.0.0',
      buildNumber: '0',
      buildSignature: '',
    );
    tempRoot = Directory.systemTemp.createTempSync('athena_params_test');
    DI.ensureInitialized(homeDirOverride: tempRoot.path);
    sentinels = GetIt.instance<SentinelViewModel>();
    params = ChatParamsState(
      settingViewModel: GetIt.instance<SettingViewModel>(),
      modelViewModel: GetIt.instance<ModelViewModel>(),
      sentinelViewModel: sentinels,
      supportService: GetIt.instance<ChatUpdateService>(),
    );
  });

  tearDown(() async {
    await GetIt.instance.reset();
    if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
  });

  ChatEntity chatWith({
    String? sentinelId,
    int retention = 7,
    double temperature = 0.3,
    String reasoningEffort = 'low',
    String? workspacePath = '/tmp/ws',
    ApprovalMode approvalMode = ApprovalMode.bypass,
  }) => ChatEntity(
    id: 'c1',
    title: 't',
    modelId: 'm1',
    sentinelId: sentinelId,
    retention: retention,
    temperature: temperature,
    reasoningEffort: reasoningEffort,
    workspacePath: workspacePath,
    approvalMode: approvalMode,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  SentinelEntity sentinel(String id) => SentinelEntity(
    id: id,
    name: 'S$id',
    description: '',
    tags: '',
    prompt: '',
  );

  ModelEntity model(String id) => ModelEntity(
    id: id,
    name: id,
    modelId: id,
    providerId: 'p1',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  group('切到已落盘的对话', () {
    testWidgets('八个值一次换齐（漏一个就会串上一条的设置）', (tester) async {
      params.setRetention(-1);
      params.setTemperature(1.0);

      params.setFromChat(
        chatWith(sentinelId: 's1'),
        model: model('m9'),
        provider: ProviderEntity(
          name: 'p',
          baseUrl: 'https://x',
          apiKey: 'k',
          createdAt: DateTime(2026),
        ),
        sentinel: sentinel('s1'),
      );

      expect(params.currentModel.value?.id, 'm9');
      expect(params.currentProvider.value, isNotNull);
      expect(params.currentSentinel.value?.id, 's1');
      expect(params.currentRetention.value, 7);
      expect(params.currentTemperature.value, 0.3);
      expect(params.currentReasoningEffort.value, 'low');
      expect(params.currentWorkspacePath.value, '/tmp/ws');
      expect(params.currentApprovalMode.value, ApprovalMode.bypass);
    });
  });

  group('角色的两种「没有」要分开', () {
    testWidgets('显式「不用角色」显示成 directChatSentinel', (tester) async {
      // sentinelId == null 是用户选的「不用角色」，不是「没选」。
      expect(
        ChatParamsState.displaySentinel(chatWith(sentinelId: null), null),
        same(SentinelViewModel.directChatSentinel),
      );
    });

    testWidgets('有角色时用传进来的那个', (tester) async {
      final s = sentinel('s1');
      expect(
        ChatParamsState.displaySentinel(chatWith(sentinelId: 's1'), s),
        same(s),
      );
    });
  });

  group('草稿起点：哪些继承、哪些不继承', () {
    testWidgets('工作文件夹与角色继承来源对话', (tester) async {
      await tester.runAsync(() async {
        final source = chatWith(sentinelId: 's1', workspacePath: '/tmp/from');

        await params.resetToDraftDefaults(source);

        expect(params.currentWorkspacePath.value, '/tmp/from');
      });
    });

    testWidgets('移动端关掉继承时工作文件夹为空', (tester) async {
      await tester.runAsync(() async {
        await params.resetToDraftDefaults(
          chatWith(workspacePath: '/tmp/from'),
          inheritWorkspace: false,
        );

        expect(params.currentWorkspacePath.value, isNull);
      });
    });

    testWidgets('保留策略、温度、推理强度回默认，不继承来源', (tester) async {
      await tester.runAsync(() async {
        await params.resetToDraftDefaults(
          chatWith(retention: 3, temperature: 0.1, reasoningEffort: 'low'),
        );

        expect(
          params.currentRetention.value,
          ChatParamsState.defaultDraftRetention,
        );
        expect(
          params.currentTemperature.value,
          ChatParamsState.defaultDraftTemperature,
        );
        expect(
          params.currentReasoningEffort.value,
          ChatEntity.defaultReasoningEffort,
        );
      });
    });

    testWidgets('审批档位取设置里播种的那一档，不继承来源会话', (tester) async {
      // 决策：档位是「这条会话里我打算放行到什么程度」。从一条 bypass 的会话点
      // 新建对话时，用户多半正要开始改动别的项目，不该顺带把上一条的放行程度带过去。
      //
      // 这里与设置里的那一档精确比对，而不是断言「不是 bypass」——后者挡不住
      // 「继承了别的档位」这种写法。
      final seeded =
          GetIt.instance<SettingViewModel>().newChatApprovalMode.value;
      await tester.runAsync(() async {
        await params.resetToDraftDefaults(
          chatWith(approvalMode: ApprovalMode.bypass),
        );

        expect(params.currentApprovalMode.value, seeded);
        expect(params.currentApprovalMode.value, isNot(ApprovalMode.bypass));
      });
    });
  });

  group('单项写入', () {
    testWidgets('setModel 连带把 provider 换掉', (tester) async {
      await tester.runAsync(() async {
        await params.setModel(model('m2'));

        expect(params.currentModel.value?.id, 'm2');
        // 隔离目录里没有这个 provider 的行，解析结果是 null——重点是它被重新解析过，
        // 而不是留着上一个模型对应的 provider
        expect(params.currentProvider.value, isNull);
      });
    });

    testWidgets('逐个 setter 生效', (tester) async {
      params.setRetention(2);
      params.setTemperature(0.9);
      params.setReasoningEffort('max');
      params.setWorkspacePath('/tmp/x');
      params.setApprovalMode(ApprovalMode.manual);

      expect(params.currentRetention.value, 2);
      expect(params.currentTemperature.value, 0.9);
      expect(params.currentReasoningEffort.value, 'max');
      expect(params.currentWorkspacePath.value, '/tmp/x');
      expect(params.currentApprovalMode.value, ApprovalMode.manual);
    });
  });
}
