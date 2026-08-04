import 'dart:io';

import 'package:athena_tui/di/tui_di.dart';
import 'package:athena_tui/ui/app.dart';
import 'package:athena_tui/ui/widgets/permission_bar.dart';
// nocterm / nocterm_test 都导出 matchers,与 package:test 冲突(isEmpty 等),
// 统一用别名访问
import 'package:nocterm/nocterm.dart' as nocterm;
import 'package:nocterm/nocterm_test.dart' as nocterm_test;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('athena_tui_ui_');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  Future<TuiDi> createDi() async {
    final di = TuiDi(dataDirectory: tempDir.path);
    await di.initialize(syncModels: false);
    // 预加载聊天列表(AthenaApp.initState 会再次调用,幂等)
    await di.chatController.initialize();
    return di;
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

  test('/models 选择弹层:方向键移动 + Enter 确认切换模型', () {
    return nocterm_test.testNocterm('模型选择', (tester) async {
      final di = await createDi();
      final before = di.chatController.currentModel.value;
      await tester.pumpComponent(AthenaApp(di: di));
      await tester.pump();

      await tester.enterText('/models');
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

  test('/models 弹层 Esc 取消不切换', () {
    return nocterm_test.testNocterm('模型选择取消', (tester) async {
      final di = await createDi();
      final before = di.chatController.currentModel.value;
      await tester.pumpComponent(AthenaApp(di: di));
      await tester.pump();

      await tester.enterText('/models');
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

  test('输入普通文本不触发 slash 命令', () {
    return nocterm_test.testNocterm('普通文本发送', (tester) async {
      final di = await createDi();
      await tester.pumpComponent(AthenaApp(di: di));
      await tester.pump();

      // 普通文本发送会走 Agent 流(无 API key → 最终显示错误),验证不崩溃。
      // RunMessageStored 在网络调用前就产出,等消息落库 + 50ms 渲染节流
      await tester.enterText('hello');
      await tester.sendEnter();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await tester.pump();

      // 用户消息应已进入列表(role 断言不依赖渲染时序)
      expect(
        di.chatController.messages.value.map((m) => m.role),
        contains('user'),
      );
      final state = tester.terminalState;
      expect(state.containsText('hello'), isTrue);
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
}
