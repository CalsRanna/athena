import 'dart:convert';

import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_gui/component/message_list_tile.dart';
import 'package:athena_gui/component/tool_card.dart';
import 'package:athena_gui/component/step_group_card.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/widget/markdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';

void main() {
  final sentinel = SentinelEntity(name: 'Test', avatar: 'T');

  Future<void> pumpAssistantMessages(
    WidgetTester tester,
    List<MessageEntity> messages, {
    double height = 700,
    bool loading = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          extensions: const [AthenaColors.dark],
        ),
        home: Scaffold(
          body: SizedBox(
            width: 700,
            height: height,
            child: CustomScrollView(
              slivers: [
                MessageCardListSliver(
                  messages: messages,
                  sentinel: sentinel,
                  loading: loading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> pumpMessage(
    WidgetTester tester, {
    required List<Map<String, String>> calls,
    required List<Map<String, String>> results,
  }) async {
    final message = MessageEntity(
      chatId: 1,
      role: 'assistant',
      toolCalls: jsonEncode(calls),
      toolResults: jsonEncode(results),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          extensions: const [AthenaColors.dark],
        ),
        home: Scaffold(
          body: SizedBox(
            width: 700,
            child: MessageListTile(message: message, sentinel: sentinel),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('短对话从视口顶部开始布局', (tester) async {
    await pumpAssistantMessages(tester, [
      MessageEntity(
        id: 1,
        chatId: 1,
        role: 'assistant',
        content: 'first response',
      ),
    ]);

    expect(tester.getTopLeft(find.text('first response')).dy, lessThan(100));
  });

  testWidgets('single and grouped tool cards display model call descriptions', (
    tester,
  ) async {
    final calls = [
      {
        'id': 'call-1',
        'name': 'file_read',
        'arguments': jsonEncode({
          'path': '/tmp/a.dart',
          'call_description': '读取应用入口代码',
        }),
      },
      {
        'id': 'call-2',
        'name': 'web_search',
        'arguments': jsonEncode({
          'query': 'dart test',
          'call_description': '查找 Dart 测试文档',
        }),
      },
    ];
    await pumpMessage(tester, calls: calls.take(1).toList(), results: []);
    expect(find.text('读取应用入口代码'), findsOneWidget);

    await pumpMessage(tester, calls: calls, results: []);
    await tester.tap(find.text('2 tool calls'));
    await tester.pump();
    expect(find.text('读取应用入口代码'), findsOneWidget);
    expect(find.text('查找 Dart 测试文档'), findsOneWidget);
  });

  testWidgets('同一 Assistant 卡片开始输出后不再重复显示 Working', (tester) async {
    await pumpAssistantMessages(tester, [
      MessageEntity(
        id: 1,
        chatId: 1,
        role: 'assistant',
        content: 'first response',
      ),
      MessageEntity(id: 2, chatId: 1, role: 'assistant'),
    ], loading: true);

    expect(find.text('first response'), findsOneWidget);
    expect(find.text('Working…'), findsNothing);
  });

  testWidgets('单个工具调用继续使用 ToolCard', (tester) async {
    await pumpMessage(
      tester,
      calls: [
        {
          'id': 'call-1',
          'name': 'file_read',
          'arguments': jsonEncode({'path': '/tmp/a.dart'}),
        },
      ],
      results: [
        {'id': 'call-1', 'name': 'file_read', 'result': 'file contents'},
      ],
    );

    expect(find.byType(ToolCard), findsOneWidget);
    expect(find.byType(StepGroupCard), findsNothing);
    expect(find.byIcon(HugeIcons.strokeRoundedArrowRight01), findsNothing);
    expect(find.byIcon(HugeIcons.strokeRoundedArrowDown01), findsNothing);

    final header = tester.widget<InkWell>(
      find.descendant(
        of: find.byType(ToolCard),
        matching: find.byType(InkWell),
      ),
    );
    expect(header.mouseCursor, SystemMouseCursors.click);
    expect(
      header.overlayColor?.resolve({WidgetState.hovered}),
      Colors.transparent,
    );
    expect(header.child, isNot(isA<Padding>()));

    await tester.tap(find.text('file_read'));
    await tester.pump();

    final resultContainer = tester
        .widgetList<Container>(
          find.ancestor(
            of: find.text('file contents'),
            matching: find.byType(Container),
          ),
        )
        .firstWhere(
          (container) =>
              container.margin == const EdgeInsets.fromLTRB(10, 2, 4, 4),
        );
    expect(resultContainer.decoration, isNull);
  });

  testWidgets('多条 assistant 消息共用一张卡背景但各自渲染推理和工具卡片', (tester) async {
    final first = MessageEntity(
      id: 1,
      chatId: 1,
      role: 'assistant',
      content: 'first response',
      reasoningContent: 'first reasoning',
      reasoningStartedAt: DateTime(2026),
      reasoningUpdatedAt: DateTime(2026).add(const Duration(seconds: 1)),
      reference: jsonEncode([
        {'title': 'First source', 'url': 'https://first.example'},
      ]),
      toolCalls: jsonEncode([
        {
          'id': 'call-1',
          'name': 'file_read',
          'arguments': jsonEncode({'path': '/tmp/a.dart'}),
        },
      ]),
      toolResults: jsonEncode([
        {'id': 'call-1', 'name': 'file_read', 'result': 'first result'},
      ]),
    );
    final second = MessageEntity(
      id: 2,
      chatId: 1,
      role: 'assistant',
      content: 'second response',
      reasoningContent: 'second reasoning',
      reasoningStartedAt: DateTime(2026),
      reasoningUpdatedAt: DateTime(2026).add(const Duration(seconds: 2)),
      reference: jsonEncode([
        {'title': 'Second source', 'url': 'https://second.example'},
      ]),
      toolCalls: jsonEncode([
        {
          'id': 'call-2',
          'name': 'web_search',
          'arguments': jsonEncode({'query': 'Athena'}),
        },
      ]),
      toolResults: jsonEncode([
        {'id': 'call-2', 'name': 'web_search', 'result': 'second result'},
      ]),
    );

    await pumpAssistantMessages(tester, [first, second]);

    expect(find.text('first response'), findsOneWidget);
    expect(find.text('second response'), findsOneWidget);
    expect(find.text('Thought for 1.0 seconds'), findsOneWidget);
    expect(find.text('Thought for 2.0 seconds'), findsOneWidget);
    expect(find.byType(ToolCard), findsNWidgets(2));
    expect(find.byType(StepGroupCard), findsNothing);
    expect(find.text('References:'), findsNWidgets(2));
    expect(
      tester.getTopLeft(find.text('first response')).dy,
      lessThan(tester.getTopLeft(find.text('second response')).dy),
    );

    // 整卡不再画底板（不画就没有亚像素接缝），但段仍连续排布（段间无空隙）
    final firstSegment = find.byKey(
      const ValueKey('assistant-card-segment-1'),
    );
    final secondSegment = find.byKey(
      const ValueKey('assistant-card-segment-2'),
    );
    expect(
      find.byKey(const ValueKey('assistant-card-surface-1')),
      findsNothing,
    );
    expect(tester.widget(firstSegment), isNot(isA<Container>()));
    expect(tester.widget(secondSegment), isNot(isA<Container>()));
    expect(
      tester.getBottomLeft(firstSegment).dy,
      closeTo(tester.getTopLeft(secondSegment).dy, 0.01),
    );
  });

  testWidgets('跨原始消息的工具调用与中间推理合并为同一步骤组', (tester) async {
    MessageEntity toolMessage({
      required int id,
      required String callId,
      required String name,
      required Map<String, String> arguments,
    }) {
      return MessageEntity(
        id: id,
        chatId: 1,
        role: 'assistant',
        toolCalls: jsonEncode([
          {'id': callId, 'name': name, 'arguments': jsonEncode(arguments)},
        ]),
        toolResults: jsonEncode([
          {'id': callId, 'name': name, 'result': '$name result'},
        ]),
      );
    }

    final first = toolMessage(
      id: 1,
      callId: 'call-1',
      name: 'file_read',
      arguments: {'path': '/tmp/a.dart'},
    );
    final second = toolMessage(
      id: 2,
      callId: 'call-2',
      name: 'web_search',
      arguments: {'query': 'Athena'},
    );

    Future<void> pumpMessages(List<MessageEntity> messages) async {
      await pumpAssistantMessages(tester, messages);
    }

    await pumpMessages([first, second]);

    expect(find.byType(StepGroupCard), findsOneWidget);
    expect(find.byType(ToolCard), findsNothing);
    expect(find.text('2 tool calls'), findsOneWidget);

    // 中间夹推理不再切断：推理作为步骤按时间序并入同一组
    await pumpMessages([
      first,
      second.copyWith(
        reasoningContent: 'reasoning between tools',
        reasoningStartedAt: DateTime(2026),
        reasoningUpdatedAt: DateTime(2026).add(const Duration(seconds: 1)),
      ),
    ]);

    expect(find.byType(StepGroupCard), findsOneWidget);
    expect(find.byType(ToolCard), findsNothing);
    expect(find.text('Thought for 1.0 seconds · 2 tool calls'), findsOneWidget);
    expect(find.text('reasoning between tools'), findsNothing);

    await tester.tap(find.text('Thought for 1.0 seconds · 2 tool calls'));
    await tester.pump();
    // 展开后按时间序：file_read → 推理 → web_search
    double topOf(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(topOf('file_read'), lessThan(topOf('Thought for 1.0 seconds')));
    expect(topOf('Thought for 1.0 seconds'), lessThan(topOf('web_search')));

    await tester.tap(find.text('Thought for 1.0 seconds'));
    await tester.pump();
    expect(find.text('reasoning between tools'), findsOneWidget);
  });

  testWidgets('跨原始消息的文字到工具不叠加消息边界间距', (tester) async {
    final textMessage = MessageEntity(
      id: 1,
      chatId: 1,
      role: 'assistant',
      content: 'response before tool',
    );
    final toolMessage = MessageEntity(
      id: 2,
      chatId: 1,
      role: 'assistant',
      toolCalls: jsonEncode([
        {
          'id': 'call-1',
          'name': 'file_read',
          'arguments': jsonEncode({'path': '/tmp/a.dart'}),
        },
      ]),
      toolResults: jsonEncode([
        {'id': 'call-1', 'name': 'file_read', 'result': 'file contents'},
      ]),
    );

    await pumpAssistantMessages(tester, [textMessage, toolMessage]);

    expect(find.byType(ToolCard), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SizedBox && widget.height == 12 && widget.width == null,
      ),
      findsNothing,
    );
  });

  testWidgets('跨原始消息的工具到文字不叠加消息边界间距', (tester) async {
    final toolMessage = MessageEntity(
      id: 1,
      chatId: 1,
      role: 'assistant',
      toolCalls: jsonEncode([
        {
          'id': 'call-1',
          'name': 'file_read',
          'arguments': jsonEncode({'path': '/tmp/a.dart'}),
        },
      ]),
      toolResults: jsonEncode([
        {'id': 'call-1', 'name': 'file_read', 'result': 'file contents'},
      ]),
    );
    final textMessage = MessageEntity(
      id: 2,
      chatId: 1,
      role: 'assistant',
      content: 'response after tool',
    );

    await pumpAssistantMessages(tester, [toolMessage, textMessage]);

    expect(find.byType(ToolCard), findsOneWidget);
    expect(find.text('response after tool'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SizedBox && widget.height == 12 && widget.width == null,
      ),
      findsNothing,
    );
  });

  testWidgets('追加新轮次后保留历史工具卡的展开状态', (tester) async {
    final toolMessage = MessageEntity(
      id: 1,
      chatId: 1,
      role: 'assistant',
      toolCalls: jsonEncode([
        {
          'id': 'call-1',
          'name': 'file_read',
          'arguments': jsonEncode({'path': '/tmp/a.dart'}),
        },
      ]),
      toolResults: jsonEncode([
        {'id': 'call-1', 'name': 'file_read', 'result': 'file contents'},
      ]),
    );
    final nextMessage = MessageEntity(
      id: 2,
      chatId: 1,
      role: 'assistant',
      content: 'next response',
    );

    await pumpAssistantMessages(tester, [toolMessage]);
    await tester.tap(find.text('file_read'));
    await tester.pump();
    expect(find.text('file contents'), findsOneWidget);

    await pumpAssistantMessages(tester, [toolMessage, nextMessage]);

    expect(find.text('file contents'), findsOneWidget);
    expect(find.text('next response'), findsOneWidget);
  });

  testWidgets('长 Assistant 卡片按消息懒构建：视口外的消息不构建也不布局', (
    tester,
  ) async {
    final messages = List.generate(
      100,
      (index) => MessageEntity(
        id: index,
        chatId: 1,
        role: 'assistant',
        content: 'response $index',
        reasoningContent: 'reasoning $index',
        reasoningStartedAt: DateTime(2026),
        reasoningUpdatedAt: DateTime(2026).add(const Duration(seconds: 1)),
        toolCalls: jsonEncode([
          {
            'id': 'call-$index',
            'name': 'bash',
            'arguments': jsonEncode({'command': 'echo $index'}),
          },
        ]),
        toolResults: jsonEncode([
          {'id': 'call-$index', 'name': 'bash', 'result': 'result $index'},
        ]),
      ),
    );

    await pumpAssistantMessages(tester, messages, height: 300);

    expect(find.byType(SliverList), findsOneWidget);
    // 没有内部滚动：全部消息由外层视口承载
    expect(find.byType(Scrollable), findsOneWidget);
    // 每条消息一个列表项，视口外的消息不构建、也不参与布局。
    // 旧版"整卡一个 item"会在这里构建全部 100 条，并让每帧成本随卡内消息数增长。
    final built = find.byType(AthenaMarkdown).evaluate().length;
    expect(built, greaterThan(0));
    expect(built, lessThan(messages.length ~/ 4));
  });

  testWidgets('多个工具调用默认折叠在同一张 StepGroupCard 中', (tester) async {
    await pumpMessage(
      tester,
      calls: [
        {
          'id': 'call-1',
          'name': 'file_read',
          'arguments': jsonEncode({'path': '/tmp/a.dart'}),
        },
        {
          'id': 'call-2',
          'name': 'bash',
          'arguments': jsonEncode({'command': 'dart test'}),
        },
      ],
      results: [
        {'id': 'call-1', 'name': 'file_read', 'result': 'file contents'},
        {'id': 'call-2', 'name': 'bash', 'result': 'all tests passed'},
      ],
    );

    expect(find.byType(StepGroupCard), findsOneWidget);
    expect(find.byType(ToolCard), findsNothing);
    expect(find.text('2 tool calls'), findsOneWidget);
    expect(find.text('done'), findsNothing);
    expect(find.text('running'), findsNothing);
    expect(find.byType(ShaderMask), findsNothing);
    expect(find.text('file_read'), findsNothing);
    expect(find.text('/tmp/a.dart'), findsNothing);

    final groupMaterials = tester.widgetList<Material>(
      find.descendant(
        of: find.byType(StepGroupCard),
        matching: find.byType(Material),
      ),
    );
    expect(
      groupMaterials.every((material) => material.color == Colors.transparent),
      isTrue,
    );

    final title = tester.widget<Text>(find.text('2 tool calls'));
    expect(title.style?.color, AthenaColors.dark.textSecondary);

    final header = tester.widget<InkWell>(
      find.descendant(
        of: find.byType(StepGroupCard),
        matching: find.byType(InkWell),
      ),
    );
    expect(header.mouseCursor, SystemMouseCursors.click);
    expect(
      header.overlayColor?.resolve({WidgetState.hovered}),
      Colors.transparent,
    );
    expect(header.child, isNot(isA<Padding>()));

    await tester.tap(find.text('2 tool calls'));
    await tester.pump();

    expect(find.text('file_read'), findsOneWidget);
    expect(find.text('/tmp/a.dart'), findsOneWidget);
    expect(find.text('bash'), findsOneWidget);
    expect(find.text('dart test'), findsOneWidget);
    expect(find.byIcon(HugeIcons.strokeRoundedArrowRight01), findsNothing);
    expect(find.byIcon(HugeIcons.strokeRoundedArrowDown01), findsNothing);

    // 展开后的子行跟随全局 8px 节奏：header→首行 与 行→行 的间距一致
    double topOf(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(
      topOf('bash') - topOf('file_read'),
      closeTo(topOf('file_read') - topOf('2 tool calls'), 0.5),
    );
  });

  testWidgets('工具失败不会展示状态或展开组卡与失败结果', (tester) async {
    await pumpMessage(
      tester,
      calls: [
        {
          'id': 'call-1',
          'name': 'file_read',
          'arguments': jsonEncode({'path': '/tmp/a.dart'}),
        },
        {
          'id': 'call-2',
          'name': 'bash',
          'arguments': jsonEncode({'command': 'dart test'}),
        },
      ],
      results: [
        {'id': 'call-1', 'name': 'file_read', 'result': 'file contents'},
        {'id': 'call-2', 'name': 'bash', 'result': 'Error: test failed'},
      ],
    );

    expect(find.text('done'), findsNothing);
    expect(find.text('running'), findsNothing);
    expect(find.text('error'), findsNothing);
    expect(find.text('Error: test failed'), findsNothing);
    expect(find.byType(ShaderMask), findsNothing);

    await tester.tap(find.text('2 tool calls'));
    await tester.pump();

    expect(find.text('error'), findsNothing);
    expect(find.text('Error: test failed'), findsNothing);

    await tester.tap(find.text('bash'));
    await tester.pump();

    expect(find.text('Error: test failed'), findsOneWidget);
    final resultContainer = tester
        .widgetList<Container>(
          find.ancestor(
            of: find.text('Error: test failed'),
            matching: find.byType(Container),
          ),
        )
        .firstWhere(
          (container) =>
              container.margin == const EdgeInsets.fromLTRB(10, 2, 4, 4),
        );
    expect(resultContainer.decoration, isNull);
  });

  testWidgets('运行中的工具组仅在 Header 前景显示 shimmer', (tester) async {
    await pumpMessage(
      tester,
      calls: [
        {
          'id': 'call-1',
          'name': 'file_read',
          'arguments': jsonEncode({'path': '/tmp/a.dart'}),
        },
        {
          'id': 'call-2',
          'name': 'bash',
          'arguments': jsonEncode({'command': 'dart test'}),
        },
      ],
      results: [
        {'id': 'call-1', 'name': 'file_read', 'result': 'file contents'},
      ],
    );

    expect(find.byType(StepGroupCard), findsOneWidget);
    expect(find.byType(ShaderMask), findsOneWidget);
    expect(find.text('done'), findsNothing);
    expect(find.text('running'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('运行中的单个工具也只在 Header 前景显示 shimmer', (tester) async {
    await pumpMessage(
      tester,
      calls: [
        {
          'id': 'call-1',
          'name': 'file_read',
          'arguments': jsonEncode({'path': '/tmp/a.dart'}),
        },
      ],
      results: const [],
    );

    expect(find.byType(ToolCard), findsOneWidget);
    expect(find.byType(ShaderMask), findsOneWidget);
    expect(find.text('done'), findsNothing);
    expect(find.text('running'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    final header = tester.widget<InkWell>(
      find.descendant(
        of: find.byType(ToolCard),
        matching: find.byType(InkWell),
      ),
    );
    expect(header.mouseCursor, SystemMouseCursors.basic);
  });

  testWidgets('单工具加推理也收纳为步骤组，头部汇总耗时与调用数', (tester) async {
    final message = MessageEntity(
      id: 1,
      chatId: 1,
      role: 'assistant',
      reasoningContent: 'why read',
      reasoningStartedAt: DateTime(2026),
      reasoningUpdatedAt: DateTime(2026).add(const Duration(seconds: 3)),
      toolCalls: jsonEncode([
        {
          'id': 'call-1',
          'name': 'file_read',
          'arguments': jsonEncode({'path': '/tmp/a.dart'}),
        },
      ]),
      toolResults: jsonEncode([
        {'id': 'call-1', 'name': 'file_read', 'result': 'file contents'},
      ]),
    );

    await pumpAssistantMessages(tester, [message]);

    expect(find.byType(StepGroupCard), findsOneWidget);
    expect(find.byType(ToolCard), findsNothing);
    expect(find.text('Thought for 3.0 seconds · 1 tool call'), findsOneWidget);
    expect(find.byType(ShaderMask), findsNothing);
    expect(find.text('file_read'), findsNothing);
    expect(find.text('why read'), findsNothing);

    await tester.tap(find.text('Thought for 3.0 seconds · 1 tool call'));
    await tester.pump();
    expect(find.text('Thought for 3.0 seconds'), findsOneWidget);
    expect(find.text('file_read'), findsOneWidget);
    expect(find.text('why read'), findsNothing);

    await tester.tap(find.text('Thought for 3.0 seconds'));
    await tester.pump();
    expect(find.text('why read'), findsOneWidget);
  });

  testWidgets('多轮推理与工具合并为一个步骤组，尾部推理吸入组内，正文单独渲染', (
    tester,
  ) async {
    MessageEntity round({
      required int id,
      required String reasoning,
      String content = '',
      String? callId,
    }) {
      return MessageEntity(
        id: id,
        chatId: 1,
        role: 'assistant',
        content: content,
        reasoningContent: reasoning,
        reasoningStartedAt: DateTime(2026),
        reasoningUpdatedAt: DateTime(2026).add(const Duration(seconds: 1)),
        toolCalls: callId == null
            ? ''
            : jsonEncode([
                {
                  'id': callId,
                  'name': 'bash',
                  'arguments': jsonEncode({'command': 'echo $callId'}),
                },
              ]),
        toolResults: callId == null
            ? ''
            : jsonEncode([
                {'id': callId, 'name': 'bash', 'result': 'ok'},
              ]),
      );
    }

    await pumpAssistantMessages(tester, [
      round(id: 1, reasoning: 'r1', callId: 'call-1'),
      round(id: 2, reasoning: 'r2', callId: 'call-2'),
      round(id: 3, reasoning: 'r3', content: 'final answer'),
    ]);

    expect(find.byType(StepGroupCard), findsOneWidget);
    expect(find.byType(ToolCard), findsNothing);
    expect(find.text('Thought for 3.0 seconds · 2 tool calls'), findsOneWidget);
    expect(find.text('final answer'), findsOneWidget);
    // 组外不再单独出现推理头
    expect(find.text('Thought for 1.0 seconds'), findsNothing);
    // 第二条消息的全部内容都并入首条宿主，不再有自己的片段
    expect(find.byKey(const ValueKey('assistant-card-segment-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('assistant-card-segment-2')), findsNothing);
    expect(find.byKey(const ValueKey('assistant-card-segment-3')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(StepGroupCard)).dy,
      lessThan(tester.getTopLeft(find.text('final answer')).dy),
    );

    await tester.tap(find.text('Thought for 3.0 seconds · 2 tool calls'));
    await tester.pump();
    expect(find.text('Thought for 1.0 seconds'), findsNWidgets(3));
    expect(find.text('echo call-1'), findsOneWidget);
    expect(find.text('echo call-2'), findsOneWidget);
  });

  testWidgets('进行中的步骤组头部显示当前步骤并带 shimmer', (tester) async {
    final thinkingFirst = MessageEntity(
      id: 1,
      chatId: 1,
      role: 'assistant',
      reasoningContent: 'r1',
      toolCalls: jsonEncode([
        {
          'id': 'call-1',
          'name': 'bash',
          'arguments': jsonEncode({'command': 'ls -la'}),
        },
      ]),
    );

    // 最后一步是未返回的工具：头部显示工具名 + 参数预览
    await pumpAssistantMessages(tester, [thinkingFirst], loading: true);
    expect(find.byType(StepGroupCard), findsOneWidget);
    expect(find.text('bash'), findsOneWidget);
    expect(find.text('ls -la'), findsOneWidget);
    expect(find.text('Thinking'), findsNothing);
    expect(find.byType(ShaderMask), findsOneWidget);

    // 工具返回、下一轮推理开始：头部切换为 Thinking
    final withResult = thinkingFirst.copyWith(
      toolResults: jsonEncode([
        {'id': 'call-1', 'name': 'bash', 'result': 'ok'},
      ]),
    );
    final nextThinking = MessageEntity(
      id: 2,
      chatId: 1,
      role: 'assistant',
      reasoningContent: 'r2',
      reasoning: true,
    );
    await pumpAssistantMessages(tester, [withResult, nextThinking], loading: true);
    expect(find.byType(StepGroupCard), findsOneWidget);
    expect(find.text('Thinking'), findsOneWidget);
    expect(find.text('bash'), findsNothing);
    expect(find.byType(ShaderMask), findsOneWidget);

    // 正文开始流式输出：序列收口，头部变为汇总、不再 shimmer
    await pumpAssistantMessages(tester, [
      withResult,
      nextThinking.copyWith(content: 'answer…'),
    ], loading: true);
    expect(find.textContaining('· 1 tool call'), findsOneWidget);
    expect(find.text('Thinking'), findsNothing);
    expect(find.byType(ShaderMask), findsNothing);
    expect(find.text('answer…'), findsOneWidget);
  });

  testWidgets('正文与引用切断步骤组，其后的工具另起序列', (tester) async {
    final first = MessageEntity(
      id: 1,
      chatId: 1,
      role: 'assistant',
      reasoningContent: 'r1',
      reasoningStartedAt: DateTime(2026),
      reasoningUpdatedAt: DateTime(2026).add(const Duration(seconds: 1)),
      content: 'let me check',
      toolCalls: jsonEncode([
        {
          'id': 'call-1',
          'name': 'file_read',
          'arguments': jsonEncode({'path': '/tmp/a.dart'}),
        },
      ]),
      toolResults: jsonEncode([
        {'id': 'call-1', 'name': 'file_read', 'result': 'a'},
      ]),
    );
    final second = MessageEntity(
      id: 2,
      chatId: 1,
      role: 'assistant',
      toolCalls: jsonEncode([
        {
          'id': 'call-2',
          'name': 'file_read',
          'arguments': jsonEncode({'path': '/tmp/b.dart'}),
        },
      ]),
      toolResults: jsonEncode([
        {'id': 'call-2', 'name': 'file_read', 'result': 'b'},
      ]),
    );

    await pumpAssistantMessages(tester, [first, second]);

    // 正文前的单段推理平铺；正文后的两次工具调用跨消息合并为一组
    expect(find.text('Thought for 1.0 seconds'), findsOneWidget);
    expect(find.text('let me check'), findsOneWidget);
    expect(find.byType(StepGroupCard), findsOneWidget);
    expect(find.text('2 tool calls'), findsOneWidget);
    expect(find.byType(ToolCard), findsNothing);
    double topOf(Finder finder) => tester.getTopLeft(finder).dy;
    expect(
      topOf(find.text('Thought for 1.0 seconds')),
      lessThan(topOf(find.text('let me check'))),
    );
    expect(
      topOf(find.text('let me check')),
      lessThan(topOf(find.byType(StepGroupCard))),
    );
  });
}
