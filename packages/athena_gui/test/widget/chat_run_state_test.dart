import 'dart:async';
import 'dart:io';

import 'package:athena_core/agent/run_outcome.dart';
import 'package:athena_core/coordinator/run_event.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/repository/chat_repository.dart';
import 'package:athena_core/storage/file_storage.dart';
import 'package:athena_gui/di.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:athena_gui/view_model/delegate/agent_stream_delegate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 运行状态（运行指示、排队、重置）在 ChatViewModel 里的记账。
///
/// 协调层换成 [_FakeStreamDelegate]：汇报 run 的事件、run 的收尾时机都由用例
/// 手动推进，断言的是用户看得到的状态——侧栏 / 发送键的运行指示、composer
/// 上方的排队消息、真正发给协调层的参数。
void main() {
  late Directory tempRoot;
  late _FakeStreamDelegate stream;
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
    tempRoot = Directory.systemTemp.createTempSync('athena_run_state_test');
    DI.ensureInitialized(homeDirOverride: tempRoot.path);
    stream = _FakeStreamDelegate();
    GetIt.instance.unregister<AgentStreamDelegate>();
    GetIt.instance.registerSingleton<AgentStreamDelegate>(stream);
    viewModel = GetIt.instance<ChatViewModel>();
  });

  tearDown(() async {
    await GetIt.instance.reset();
    if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
  });

  Future<ChatEntity> seedChat(WidgetTester tester, String title) async {
    late ChatEntity chat;
    await tester.runAsync(() async {
      final repo = GetIt.instance<ChatRepository>();
      final id = await repo.createChat(
        ChatEntity(
          title: title,
          modelId: 1,
          sentinelId: ChatEntity.noSentinelId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      chat = (await repo.getChatById(id))!;
    });
    await tester.runAsync(() => viewModel.getChats());
    return chat;
  }

  /// 协调层起了一个汇报 run：发出占位消息，run 在 [settled] 完成前一直在跑。
  ///
  /// 用同步 Completer：用例体跑在 FakeAsync 里，普通 Completer 的完成通知会
  /// 排进创建它的假时钟微任务队列，在 runAsync 里等它就永远等不到。
  Completer<void> startReport(int chatId) {
    final settled = Completer<void>.sync();
    stream.settled[chatId] = settled;
    stream.emitInternal(
      chatId,
      RunAssistantAppended(
        MessageEntity(id: 900, chatId: chatId, role: 'assistant'),
      ),
    );
    return settled;
  }

  /// 汇报 run 的收尾：真实协调层先发 outcome，再完成 settled。
  Future<void> finishReport(
    WidgetTester tester,
    int chatId,
    Completer<void> settled,
  ) async {
    stream.emitInternal(
      chatId,
      const RunOutcomeChanged(
        AgentRunOutcome(
          termination: AgentRunTermination.completed,
          iterations: 1,
        ),
      ),
    );
    stream.settled.remove(chatId);
    settled.complete();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }

  /// 在真实异步区里启动 [action] 并让它跑到第一个等待点。
  ///
  /// testWidgets 的用例体跑在 FakeAsync 里：在那里启动的 Future，其后续都排在
  /// 假时钟的微任务队列上，之后再用 runAsync 去等它会永远等不到。
  ///
  /// 返回值包在 record 里：async 函数直接返回 Future 会被展平成等它完成。
  Future<({Future<void> done})> launch(
    WidgetTester tester,
    Future<void> Function() action,
  ) async {
    late Future<void> future;
    await tester.runAsync(() async {
      future = action();
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    return (done: future);
  }

  MessageEntity userMessage(int chatId, String content) =>
      MessageEntity(id: 0, chatId: chatId, role: 'user', content: content);

  testWidgets('汇报中途切到别的对话，汇报结束后原对话的运行指示照样熄灭', (tester) async {
    final a = await seedChat(tester, 'A');
    final b = await seedChat(tester, 'B');
    await tester.runAsync(() => viewModel.selectChat(a));

    final settled = startReport(a.id!);
    await tester.pump();
    expect(viewModel.isStreamingChat(a.id!), isTrue, reason: '前置条件：汇报点亮指示');

    await tester.runAsync(() => viewModel.selectChat(b));
    await finishReport(tester, a.id!, settled);

    expect(
      viewModel.isStreamingChat(a.id!),
      isFalse,
      reason: '否则 A 一直显示运行中，发送键变成停止键',
    );
  });

  testWidgets('在后台对话上开始的汇报同样点亮并熄灭指示', (tester) async {
    final a = await seedChat(tester, 'A');
    final b = await seedChat(tester, 'B');
    await tester.runAsync(() => viewModel.selectChat(b));

    final settled = startReport(a.id!);
    await tester.pump();
    expect(viewModel.isStreamingChat(a.id!), isTrue);

    await finishReport(tester, a.id!, settled);
    expect(viewModel.isStreamingChat(a.id!), isFalse);
  });

  testWidgets('汇报期间发送：消息先出现在排队区，汇报结束后发出', (tester) async {
    final a = await seedChat(tester, 'A');
    await tester.runAsync(() => viewModel.selectChat(a));
    final settled = startReport(a.id!);
    await tester.pump();

    final message = userMessage(a.id!, '汇报时打的字');
    final sending = await launch(
      tester,
      () => viewModel.sendMessage(message, chat: a),
    );

    expect(viewModel.queuedMessages.value, [
      message,
    ], reason: '输入框已清空，这条消息不能凭空消失');
    expect(stream.sent, isEmpty, reason: '汇报结束前不能发出');

    await finishReport(tester, a.id!, settled);
    await tester.runAsync(() => sending.done);

    expect(stream.sent.map((s) => s.message.content), ['汇报时打的字']);
  });

  testWidgets('汇报期间删除对话：排队中的消息随之丢弃，不再发出', (tester) async {
    final a = await seedChat(tester, 'A');
    await tester.runAsync(() => viewModel.selectChat(a));
    startReport(a.id!);
    await tester.pump();

    final sending = await launch(
      tester,
      () => viewModel.sendMessage(userMessage(a.id!, 'x'), chat: a),
    );
    stream.onStop = (chatId) {
      final settled = stream.settled.remove(chatId);
      scheduleMicrotask(() => settled?.complete());
    };
    await tester.runAsync(() => viewModel.deleteChat(a));
    await tester.runAsync(() => sending.done);

    expect(stream.sent, isEmpty);
  });

  testWidgets('排队消息出队时按会话的最新参数发送', (tester) async {
    final a = await seedChat(tester, 'A');
    await tester.runAsync(() => viewModel.selectChat(a));
    final first = stream.holdNextSend();

    final running = await launch(
      tester,
      () => viewModel.sendMessage(userMessage(a.id!, '第一条'), chat: a),
    );
    final queued = await launch(
      tester,
      () => viewModel.sendMessage(userMessage(a.id!, '第二条'), chat: a),
    );
    expect(viewModel.queuedMessages.value.map((m) => m.content), ['第二条']);

    // 排队期间在 composer 上改了会话参数
    await tester.runAsync(() => viewModel.updateRetention(0, chat: a));
    await tester.runAsync(() async {
      await first.close();
      await Future.wait([running.done, queued.done]);
    });

    expect(stream.sent.map((s) => s.chat.retention), [-1, 0]);
  });

  testWidgets('重置：先停掉运行中的对话并等它收尾，再清空数据、回草稿态', (tester) async {
    final a = await seedChat(tester, 'A');
    await tester.runAsync(() => viewModel.selectChat(a));
    startReport(a.id!);
    await tester.pump();

    final order = <String>[];
    stream.onStop = (chatId) {
      order.add('stop $chatId');
      final settled = stream.settled.remove(chatId);
      scheduleMicrotask(() => settled?.complete());
    };
    await tester.runAsync(
      () => viewModel.runDataReset(() async {
        order.add('reset');
        await GetIt.instance<FileStorage>().reset();
        return true;
      }),
    );

    expect(order, ['stop ${a.id}', 'reset']);
    expect(viewModel.currentChat.value, isNull);
    expect(viewModel.chats.value, isEmpty, reason: '侧栏不能再列出已删除的对话');
    expect(viewModel.isStreamingChat(a.id!), isFalse);
  });
}

class _SentRun {
  _SentRun(this.message, this.chat);
  final MessageEntity message;
  final ChatEntity chat;
}

/// 只实现 ChatViewModel 用到的那部分协调层接口；run 的进度由用例推进。
class _FakeStreamDelegate implements AgentStreamDelegate {
  final Map<int, Completer<void>> settled = {};
  final List<_SentRun> sent = [];
  void Function(int chatId)? onStop;

  final _internal = StreamController<InternalRunEvent>.broadcast(sync: true);
  StreamController<RunEvent>? _held;

  void emitInternal(int chatId, RunEvent event) =>
      _internal.add(InternalRunEvent(chatId, event));

  /// 下一次 send 的事件流保持打开，直到返回的控制器被关闭。
  StreamController<RunEvent> holdNextSend() =>
      _held = StreamController<RunEvent>();

  @override
  Stream<InternalRunEvent> get internalEvents => _internal.stream;

  @override
  Stream<ApprovalRequest> get approvalRequests => const Stream.empty();

  @override
  Stream<ElicitRequest> get elicitRequests => const Stream.empty();

  @override
  Set<int> get streamingChatIds => settled.keys.toSet();

  @override
  bool isStreamingChat(int chatId) => settled.containsKey(chatId);

  @override
  Future<void>? settledOf(int chatId) => settled[chatId]?.future;

  @override
  MessageEntity? liveMessage(int chatId) => null;

  int _nextMessageId = 1000;

  /// 与真实协调层一样先报「用户消息已落库」：ChatViewModel 据此把它移出排队区。
  @override
  Stream<RunEvent> send({
    required MessageEntity message,
    required ChatEntity chat,
    bool jsonMode = false,
  }) async* {
    sent.add(_SentRun(message, chat));
    final held = _held;
    _held = null;
    yield RunMessageStored(message.copyWith(id: _nextMessageId++));
    if (held != null) yield* held.stream;
  }

  @override
  void stop(int chatId) => onStop?.call(chatId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
