import 'dart:io';

import 'package:athena_core/agent/agent_service.dart';
import 'package:athena_core/agent/cancel_token.dart';
import 'package:athena_core/agent/permission/permission_service.dart';
import 'package:athena_core/agent/tool/tool_registry.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/service/chat_service.dart';
import 'package:athena_core/service/llm_client.dart';
import 'package:athena_tui/di/tui_di.dart';
import 'package:athena_tui/ui/app.dart';
import 'package:athena_tui/ui/widgets/permission_bar.dart';
// nocterm / nocterm_test 都导出 matchers,与 package:test 冲突(isEmpty 等),
// 统一用别名访问
import 'package:nocterm/nocterm.dart' as nocterm;
import 'package:nocterm/nocterm_test.dart' as nocterm_test;
import 'package:openai_dart/openai_dart.dart';
import 'package:test/test.dart';

/// 假 Agent 服务:run 返回受控事件流,不发起任何网络请求。
///
/// ui_test 的"发送"类测试用真实 AgentService 会打到真实 LLM API
/// (无 key 时收到 401,网络时序不定导致测试抖动/收尾竞态)。
class _FakeAgentService extends AgentService {
  _FakeAgentService()
      : super(
          chatService: ChatService(llmClient: LlmClient()),
          toolRegistry: ToolRegistry(),
        );

  @override
  Stream<AgentEvent> run({
    required int runId,
    required ChatEntity chat,
    required ProviderEntity provider,
    required ModelEntity model,
    required List<ChatMessage> baseMessages,
    String? skillPrompt,
    String? evolutionPrompt,
    String? runtimePrompt,
    String? sentinelId,
    PermissionCallback? onPermission,
    PermissionService? permissionService,
    int maxIterations = 100,
    CancelToken? cancelToken,
    BeforeToolCallHook? beforeToolCall,
    AfterToolCallHook? afterToolCall,
    bool jsonMode = false,
  }) async* {
    yield AgentEvent.turnStart(iteration: 0);
    yield AgentEvent.text('模拟回复');
    yield AgentEvent.done(content: '模拟回复');
  }
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('athena_tui_ui_');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  /// 种入测试 provider + 模型(替代已删除的 PresetSeed;
  /// 预设 provider/模型现由 models.dev 同步,测试不联网自行造数据)。
  ///
  /// 模型名与原 PresetSeed 一致:弹层按名字排序,/model 滚动测试
  /// 依赖"首项 DeepSeek-R1-0528、末项 xAI: Grok 4、共 13 个"。
  Future<void> seedTestData(TuiDi di) async {
    final now = DateTime.now();
    final dsId = await di.providerRepo.storeProvider(ProviderEntity(
      name: 'Deep Seek',
      baseUrl: 'https://api.deepseek.com/v1',
      apiKey: '',
      enabled: false,
      isPreset: true,
      createdAt: now,
    ));
    final orId = await di.providerRepo.storeProvider(ProviderEntity(
      name: 'Open Router',
      baseUrl: 'https://openrouter.ai/api/v1',
      apiKey: '',
      enabled: false,
      isPreset: true,
      createdAt: now,
    ));
    ModelEntity model(String name, String modelId, int providerId) =>
        ModelEntity(
          name: name,
          modelId: modelId,
          providerId: providerId,
          isPreset: true,
          createdAt: now,
          updatedAt: now,
        );
    await di.modelRepo.createModel(model('DeepSeek-V3-0324', 'deepseek-chat', dsId));
    await di.modelRepo.createModel(
      model('DeepSeek-R1-0528', 'deepseek-reasoner', dsId),
    );
    await di.modelRepo
        .createModel(model('Anthropic: Claude Opus 4', 'anthropic/claude-opus-4', orId));
    await di.modelRepo
        .createModel(model('Anthropic: Claude Sonnet 4', 'anthropic/claude-sonnet-4', orId));
    await di.modelRepo.createModel(
      model('DeepSeek: DeepSeek V3 0324', 'deepseek/deepseek-chat-v3-0324', orId),
    );
    await di.modelRepo
        .createModel(model('DeepSeek: R1 0528', 'deepseek/deepseek-r1-0528', orId));
    await di.modelRepo
        .createModel(model('Google: Gemini 2.5 Flash', 'google/gemini-2.5-flash', orId));
    await di.modelRepo
        .createModel(model('Google: Gemini 2.5 Pro', 'google/gemini-2.5-pro', orId));
    await di.modelRepo.createModel(model('OpenAI: GPT-4.1', 'openai/gpt-4.1', orId));
    await di.modelRepo.createModel(model('OpenAI: GPT-5 Chat', 'openai/gpt-5', orId));
    await di.modelRepo.createModel(model('OpenAI: o3', 'openai/o3', orId));
    await di.modelRepo
        .createModel(model('Qwen: Qwen3 235B A22B', 'qwen/qwen3-235b-a22b', orId));
    await di.modelRepo.createModel(model('xAI: Grok 4', 'x-ai/grok-4', orId));
  }

  Future<TuiDi> createDi() async {
    // homeDir 注入 tempDir:避免读到用户真实 ~/.athena/setting.yaml
    final di = TuiDi(
      dataDirectory: tempDir.path,
      homeDir: tempDir.path,
      // 假 Agent:发送类测试不发起真实网络请求
      agentServiceOverride: _FakeAgentService(),
    );
    await di.initialize(syncModels: false);
    await seedTestData(di);
    // 预加载聊天列表(AthenaApp.initState 会再次调用,幂等)
    await di.chatController.initialize();
    return di;
  }

  /// 等待条件满足(最多 [timeout])。替代固定延迟:发送类测试等待
  /// 流式 run 结束,避免收尾工作越过测试/teardown 边界。
  Future<void> waitUntil(
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!condition()) {
      if (DateTime.now().isAfter(deadline)) {
        fail('waitUntil 超时:条件 5s 内未满足');
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  // testNocterm 是普通异步函数(非 package:test 注册),必须用 test() 包装
  // 才能串行执行 —— 否则多个 binding 单例并发创建冲突。
  test('基本布局渲染:状态栏 + 输入区', () {
    return nocterm_test.testNocterm('基本布局渲染', (tester) async {
      final di = await createDi();
      await tester.pumpComponent(AthenaApp(di: di));
      await tester.pump();

      final state = tester.terminalState;
      expect(state.containsText('Athena'), isTrue);
      expect(state.containsText('输入消息'), isTrue);
      // 空列表提示
      expect(state.containsText('输入 /help 查看命令'), isTrue);
    });
  });

  test('/help 命令渲染帮助文本', () {
    return nocterm_test.testNocterm('/help 命令', (tester) async {
      final di = await createDi();
      // 清除 Provider 引导错误:ErrorBar 占行会挤压消息列表视口,
      // 帮助文本首行被滚出(与 /help 渲染本身无关)
      di.chatController.error.value = null;
      await tester.pumpComponent(AthenaApp(di: di));
      await tester.pump();

      await tester.enterText('/help');
      await tester.sendEnter();
      await tester.pump();

      final state = tester.terminalState;
      expect(state.containsText('Athena TUI 命令'), isTrue);
      expect(state.containsText('/quit'), isTrue);
    });
  });

  test('初始化自动创建首个聊天', () async {
    final di = await createDi();
    expect(di.chatController.chatList.value.length, 1);
    expect(di.chatController.currentChat.value, isNotNull);
  });

  /// 给指定名称的 provider 配置 API key(seed 全部无 key,过滤后模型为空)。
  Future<void> configureKey(TuiDi di, String providerName) async {
    final providers = await di.chatController.availableProviders;
    final target = providers.firstWhere((p) => p.name == providerName);
    await di.chatController.updateProviderApiKey(target, 'sk-test-123');
  }

  test('/model 选择弹层:方向键移动 + Enter 确认切换模型', () {
    return nocterm_test.testNocterm('模型选择', (tester) async {
      final di = await createDi();
      await configureKey(di, 'Deep Seek');
      final before = di.chatController.currentModel.value;
      await tester.pumpComponent(AthenaApp(di: di));
      await tester.pump();

      await tester.enterText('/model');
      await tester.sendEnter();
      // 命令处理是异步链(读取模型列表 IO 后打开弹层)
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();

      final state = tester.terminalState;
      expect(state.containsText('选择模型'), isTrue);
      expect(state.containsText('DeepSeek'), isTrue);

      // 下移一项 + Enter 确认
      await tester.sendArrowDown();
      await tester.pump();
      await tester.sendEnter();
      // 切换模型是异步 IO(updateChat 落库)
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();

      final after = di.chatController.currentModel.value;
      expect(after?.id, isNot(before?.id));
      // 弹层已关闭
      expect(tester.terminalState.containsText('选择模型'), isFalse);
    });
  });

  test('/model 弹层 Esc 取消不切换', () {
    return nocterm_test.testNocterm('模型选择取消', (tester) async {
      final di = await createDi();
      await configureKey(di, 'Deep Seek');
      final before = di.chatController.currentModel.value;
      await tester.pumpComponent(AthenaApp(di: di));
      await tester.pump();

      await tester.enterText('/model');
      await tester.sendEnter();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
      expect(tester.terminalState.containsText('选择模型'), isTrue);

      await tester.sendEscape();
      await tester.pump();

      expect(di.chatController.currentModel.value?.id, before?.id);
      expect(tester.terminalState.containsText('选择模型'), isFalse);
    });
  });

  test('/model 弹层模型多时方向键滚动,选中项始终可见', () {
    return nocterm_test.testNocterm('模型弹层滚动', (tester) async {
      final di = await createDi();
      // 配置两个 provider 的 key:13 个模型,超过弹层 12 行视口
      await configureKey(di, 'Deep Seek');
      await configureKey(di, 'Open Router');
      // 清掉配置前 newChat 写入的引导错误:ErrorBar 文本含模型名
      // (如"当前模型 DeepSeek-R1-0528 的 Provider…"),会污染可见性断言
      di.chatController.error.value = null;
      await tester.pumpComponent(AthenaApp(di: di));
      await tester.pump();

      await tester.enterText('/model');
      await tester.sendEnter();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();

      // 初始:首项(DeepSeek-R1-0528,带提供商名括号以区别于状态栏
      // 的模型名——状态栏始终显示当前模型名)可见
      expect(
        tester.terminalState.containsText('DeepSeek-R1-0528 (Deep Seek)'),
        isTrue,
      );

      // 一直下移到最后一项(xAI: Grok 4,index 12)
      for (var i = 0; i < 12; i++) {
        await tester.sendArrowDown();
        await tester.pump();
        await tester.pump(); // postFrame 里的 ensureVisible 应用
      }

      final state = tester.terminalState;
      // 最后一项被滚动进视口(修复前不可见)
      expect(state.containsText('xAI: Grok 4'), isTrue);
      // 首项(弹层标签,含提供商名)已被滚出视口,证明弹层真的滚动了
      expect(
        state.containsText('DeepSeek-R1-0528 (Deep Seek)'),
        isFalse,
      );
    });
  });

  test('/model 只展示已配置 API key 的模型', () {
    return nocterm_test.testNocterm('模型过滤', (tester) async {
      final di = await createDi();
      // 只给 Deep Seek 配 key;Open Router 的模型不应出现
      await configureKey(di, 'Deep Seek');
      await tester.pumpComponent(AthenaApp(di: di));
      await tester.pump();

      await tester.enterText('/model');
      await tester.sendEnter();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();

      final state = tester.terminalState;
      expect(state.containsText('选择模型'), isTrue);
      // Deep Seek 已配 key → 模型可见
      expect(state.containsText('DeepSeek'), isTrue);
      // Open Router 未配 key → 其模型(Claude/Gemini)不可见
      expect(state.containsText('Claude'), isFalse);
      expect(state.containsText('Gemini'), isFalse);
    });
  });

  test('/model 无已配置 key 时提示配置', () {
    return nocterm_test.testNocterm('模型空列表', (tester) async {
      final di = await createDi();
      await tester.pumpComponent(AthenaApp(di: di));
      await tester.pump();

      await tester.enterText('/model');
      await tester.sendEnter();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();

      final state = tester.terminalState;
      expect(state.containsText('选择模型'), isFalse, reason: '无可选模型,不打开弹层');
      expect(state.containsText('暂无模型'), isTrue);
    });
  });

  test('输入普通文本不触发 slash 命令', () {
    return nocterm_test.testNocterm('普通文本发送', (tester) async {
      final di = await createDi();
      await tester.pumpComponent(AthenaApp(di: di));
      await tester.pump();

      // 普通文本发送走 Agent 流(FakeAgentService,无网络)。
      // 等待 run 完全结束(含 finally/flush),收尾不越过测试边界
      await tester.enterText('hello');
      await tester.sendEnter();
      await waitUntil(() => !di.chatController.isStreaming.value);
      await tester.pump();

      // 用户消息应已进入列表(role 断言不依赖渲染时序)
      expect(
        di.chatController.messages.value.map((m) => m.role),
        contains('user'),
      );
      final state = tester.terminalState;
      expect(state.containsText('hello'), isTrue);
      // 假 Agent 的回复也已渲染
      expect(state.containsText('模拟回复'), isTrue);
    });
  });

  test('权限审批条渲染与按键提示', () {
    return nocterm_test.testNocterm('权限条', (tester) async {
      await tester.pumpComponent(const PermissionBar(
        title: '权限请求',
        detail: 'bash: git push -f',
        hint: '[y] 允许  [n] 拒绝  [a] 总是允许',
      ));
      await tester.pump();
      final state = tester.terminalState;
      expect(state.containsText('权限请求'), isTrue);
      expect(state.containsText('git push -f'), isTrue);
      expect(state.containsText('[y] 允许'), isTrue);
    });
  });

  test('bridge 未注册审批处理器时拒绝权限请求', () async {
    final di = await createDi();
    final decision = await di.agentBridge
        .requestPermissionForTest('bash', '{"command": "rm -rf /"}');
    expect(decision.approved, isFalse);
  });

  test('/providers 配置 API key 流程', () {
    return nocterm_test.testNocterm('providers 配置', (tester) async {
      final di = await createDi();
      await tester.pumpComponent(AthenaApp(di: di));
      await tester.pump();

      // 打开 provider 选择弹层
      await tester.enterText('/providers');
      await tester.sendEnter();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
      expect(tester.terminalState.containsText('选择 Provider'), isTrue);

      // 选中第一个(Deep Seek)+ Enter
      await tester.sendEnter();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
      expect(tester.terminalState.containsText('输入 API key'), isTrue);

      // 输入 key 并提交
      await tester.enterText('sk-test-123');
      await tester.sendEnter();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();

      final providers = await di.chatController.availableProviders;
      expect(providers.first.apiKey, 'sk-test-123');
      expect(tester.terminalState.containsText('已保存'), isTrue);
    });
  });

  test('权限审批条:按 y 允许,字符不插入输入框', () {
    return nocterm_test.testNocterm('审批 y', (tester) async {
      final di = await createDi();
      await tester.pumpComponent(AthenaApp(di: di));
      await tester.pump();

      // 触发一次权限请求(走 UI 注册的 handler → 弹出审批条)
      final future = di.agentBridge
          .requestPermissionForTest('bash', '{"command": "git push"}');
      await tester.pump();
      expect(tester.terminalState.containsText('权限请求'), isTrue);
      expect(tester.terminalState.containsText('git push'), isTrue);

      // 按 y 允许
      await tester.sendKey(nocterm.LogicalKey.keyY);
      await tester.pump();

      final decision = await future;
      expect(decision.approved, isTrue);
      // 审批条已关闭
      expect(tester.terminalState.containsText('权限请求'), isFalse);
    });
  });

  test('权限审批条:按 n 拒绝', () {
    return nocterm_test.testNocterm('审批 n', (tester) async {
      final di = await createDi();
      await tester.pumpComponent(AthenaApp(di: di));
      await tester.pump();

      final future = di.agentBridge
          .requestPermissionForTest('bash', '{"command": "rm -rf /"}');
      await tester.pump();
      expect(tester.terminalState.containsText('权限请求'), isTrue);

      await tester.sendKey(nocterm.LogicalKey.keyN);
      await tester.pump();

      final decision = await future;
      expect(decision.approved, isFalse);
      expect(tester.terminalState.containsText('权限请求'), isFalse);
    });
  });

  test('权限审批条:按 Esc 取消生成并拒绝', () {
    return nocterm_test.testNocterm('审批 Esc', (tester) async {
      final di = await createDi();
      await tester.pumpComponent(AthenaApp(di: di));
      await tester.pump();

      final future = di.agentBridge
          .requestPermissionForTest('bash', '{"command": "git push"}');
      await tester.pump();
      expect(tester.terminalState.containsText('权限请求'), isTrue);

      // Esc:取消生成(cancelToken 触发后审批自动拒绝)
      await tester.sendEscape();
      await tester.pump();

      final decision = await future;
      expect(decision.approved, isFalse);
    });
  });

  test('ErrorBar 渲染错误信息', () {
    return nocterm_test.testNocterm('错误条', (tester) async {
      final di = await createDi();
      await tester.pumpComponent(AthenaApp(di: di));
      await tester.pump();

      di.chatController.error.value = '测试错误:网络不可达';
      await tester.pump();

      expect(tester.terminalState.containsText('测试错误:网络不可达'), isTrue);
    });
  });

  test('新目录初始化显示 Provider 未配置引导', () async {
    final di = await createDi();
    // 种子 provider 无 API key → 自动建聊天时写入引导错误
    final error = di.chatController.error.value;
    expect(error, isNotNull);
    expect(error, contains('未配置 API key'));
  });

  test('/providers 留空回车取消 API key 输入', () {
    return nocterm_test.testNocterm('key 留空取消', (tester) async {
      final di = await createDi();
      await tester.pumpComponent(AthenaApp(di: di));
      await tester.pump();

      await tester.enterText('/providers');
      await tester.sendEnter();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();

      // 选中第一个 provider,进入 key 输入模式
      await tester.sendEnter();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
      expect(tester.terminalState.containsText('输入 API key'), isTrue);

      // 留空回车 = 取消
      await tester.sendEnter();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();

      expect(tester.terminalState.containsText('已取消配置'), isTrue);
      // 退出 key 模式:输入框 placeholder 恢复默认提示
      // (系统消息 "为 xx 输入 API key(回车保存…)" 会留在消息列表,
      // 不能断言 '输入 API key' 全局消失,只查输入框区域已恢复)
      expect(tester.terminalState.containsText('输入消息…'), isTrue);
    });
  });

  group('斜杠命令实时建议', () {
    test('输入 / 显示全部命令', () {
      return nocterm_test.testNocterm('建议-全部', (tester) async {
        final di = await createDi();
        await tester.pumpComponent(AthenaApp(di: di));
        await tester.pump();

        await tester.enterText('/');
        await tester.pump();

        final state = tester.terminalState;
        expect(state.containsText('命令提示'), isTrue);
        expect(state.containsText('/new'), isTrue);
        expect(state.containsText('/quit'), isTrue);
      });
    });

    test('输入 /m 只匹配 model 命令,实时过滤', () {
      return nocterm_test.testNocterm('建议-过滤', (tester) async {
        final di = await createDi();
        await tester.pumpComponent(AthenaApp(di: di));
        await tester.pump();

        // enterText 是逐字符插入,直接一次输入 /m
        // (不要连续 enterText('/') + enterText('/m'),会拼成 //m)
        await tester.enterText('/m');
        await tester.pump();
        final state = tester.terminalState;
        expect(state.containsText('/model'), isTrue);
        expect(state.containsText('/new'), isFalse);
        expect(state.containsText('/switch'), isFalse);
      });
    });

    test('命令带参数仍匹配(/json xxx)', () {
      return nocterm_test.testNocterm('建议-带参数', (tester) async {
        final di = await createDi();
        await tester.pumpComponent(AthenaApp(di: di));
        await tester.pump();

        await tester.enterText('/json 输出 JSON');
        await tester.pump();

        expect(tester.terminalState.containsText('/json'), isTrue);
      });
    });

    test('普通文本不显示建议', () {
      return nocterm_test.testNocterm('建议-普通文本', (tester) async {
        final di = await createDi();
        await tester.pumpComponent(AthenaApp(di: di));
        await tester.pump();

        await tester.enterText('hello');
        await tester.pump();

        expect(tester.terminalState.containsText('命令提示'), isFalse);
      });
    });

    test('Tab 补全第一个匹配命令', () {
      return nocterm_test.testNocterm('建议-Tab补全', (tester) async {
        final di = await createDi();
        await configureKey(di, 'Deep Seek');
        await tester.pumpComponent(AthenaApp(di: di));
        await tester.pump();

        await tester.enterText('/m');
        await tester.pump();
        expect(tester.terminalState.containsText('/model'), isTrue);

        // Tab 补全 → 输入框变为 /model;回车应执行命令打开弹层
        // (而非发送普通文本),证明补全写入的是命令
        await tester.sendKey(nocterm.LogicalKey.tab);
        await tester.pump();
        await tester.sendEnter();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();

        expect(tester.terminalState.containsText('选择模型'), isTrue);
      });
    });

    test('清空输入后建议消失', () {
      return nocterm_test.testNocterm('建议-清空', (tester) async {
        final di = await createDi();
        await tester.pumpComponent(AthenaApp(di: di));
        await tester.pump();

        await tester.enterText('/m');
        await tester.pump();
        expect(tester.terminalState.containsText('命令提示'), isTrue);

        // 逐字符删除(enterText('') 不发按键,需 backspace)
        await tester.sendKey(nocterm.LogicalKey.backspace);
        await tester.sendKey(nocterm.LogicalKey.backspace);
        await tester.pump();
        expect(tester.terminalState.containsText('命令提示'), isFalse);
      });
    });
  });

  group('唯一匹配回车执行', () {
    test('输入 /m 回车直接执行 /model 命令', () {
      return nocterm_test.testNocterm('唯一匹配-回车', (tester) async {
        final di = await createDi();
        await configureKey(di, 'Deep Seek');
        await tester.pumpComponent(AthenaApp(di: di));
        await tester.pump();

        await tester.enterText('/m');
        await tester.pump();
        expect(tester.terminalState.containsText('/model'), isTrue);

        // 唯一匹配(/model)时回车 = 执行命令,打开模型选择弹层
        await tester.sendEnter();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();

        expect(tester.terminalState.containsText('选择模型'), isTrue);
      });
    });

    test('输入 /j 回车执行 /json 命令(无参数提示用法)', () {
      return nocterm_test.testNocterm('唯一匹配-json', (tester) async {
        final di = await createDi();
        await tester.pumpComponent(AthenaApp(di: di));
        await tester.pump();

        await tester.enterText('/j');
        await tester.pump();
        expect(tester.terminalState.containsText('/json'), isTrue);

        // 唯一匹配 /json,回车执行 → 无参数时提示用法
        // (而非"未知命令:/j")
        await tester.sendEnter();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();

        expect(tester.terminalState.containsText('用法:/json'), isTrue);
      });
    });

    test('唯一匹配带参数回车:执行命令并保留参数', () {
      return nocterm_test.testNocterm('唯一匹配-带参数', (tester) async {
        final di = await createDi();
        await tester.pumpComponent(AthenaApp(di: di));
        await tester.pump();

        await tester.enterText('/j 测试');
        await tester.pump();
        expect(tester.terminalState.containsText('/json'), isTrue);

        await tester.sendEnter();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();

        // 执行的是 /json 测试(JSON 模式发送),而非"未知命令:/j 测试"。
        // 命令执行同步生效,不依赖 Agent 流结果(不作为断言)。
        expect(tester.terminalState.containsText('未知命令'), isFalse);
        // 等待 run 完全结束(FakeAgentService,无网络),收尾不越过测试边界
        await waitUntil(() => !di.chatController.isStreaming.value);
      });
    });

    test('多匹配时回车不执行(仍走未知命令提示)', () {
      return nocterm_test.testNocterm('多匹配-回车', (tester) async {
        final di = await createDi();
        await tester.pumpComponent(AthenaApp(di: di));
        await tester.pump();

        await tester.enterText('/');
        await tester.pump();
        expect(tester.terminalState.containsText('命令提示'), isTrue);

        await tester.sendEnter();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();

        // 未执行任何命令:弹层不出现,提示未知命令
        expect(tester.terminalState.containsText('选择模型'), isFalse);
        expect(tester.terminalState.containsText('未知命令:/'), isTrue);
      });
    });

    test('输入完整命令回车行为不变', () {
      return nocterm_test.testNocterm('完整命令-回车', (tester) async {
        final di = await createDi();
        await configureKey(di, 'Deep Seek');
        await tester.pumpComponent(AthenaApp(di: di));
        await tester.pump();

        await tester.enterText('/model');
        await tester.pump();
        await tester.sendEnter();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();

        expect(tester.terminalState.containsText('选择模型'), isTrue);
      });
    });
  });
}
