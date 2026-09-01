import 'dart:convert';

import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_gui/component/message_list_tile.dart';
import 'package:athena_gui/component/tool_card.dart';
import 'package:athena_gui/component/tool_group_card.dart';
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
    expect(find.byType(ToolGroupCard), findsNothing);
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

  testWidgets('多条 assistant 消息共用背景但各自渲染推理和工具卡片', (tester) async {
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
    expect(find.byType(ToolGroupCard), findsNothing);
    expect(find.text('References:'), findsNWidgets(2));
    expect(
      tester.getTopLeft(find.text('first response')).dy,
      lessThan(tester.getTopLeft(find.text('second response')).dy),
    );

    expect(find.byType(DecoratedSliver), findsNothing);
    final firstBackground = tester.widget<Container>(
      find.byKey(const ValueKey('assistant-card-segment-1')),
    );
    final secondBackground = tester.widget<Container>(
      find.byKey(const ValueKey('assistant-card-segment-2')),
    );
    final firstDecoration = firstBackground.decoration as BoxDecoration;
    final secondDecoration = secondBackground.decoration as BoxDecoration;
    const radius = Radius.circular(24);
    expect(
      firstDecoration.borderRadius,
      const BorderRadius.only(topLeft: radius, topRight: radius),
    );
    expect(
      secondDecoration.borderRadius,
      const BorderRadius.only(bottomLeft: radius, bottomRight: radius),
    );
    expect(
      firstDecoration.color,
      AthenaColors.dark.surfaceRaised.withValues(alpha: 0.95),
    );
    expect(
      secondDecoration.color,
      AthenaColors.dark.surfaceRaised.withValues(alpha: 0.95),
    );
    expect(
      tester
          .getBottomLeft(find.byKey(const ValueKey('assistant-card-segment-1')))
          .dy,
      closeTo(
        tester
            .getTopLeft(find.byKey(const ValueKey('assistant-card-segment-2')))
            .dy,
        0.01,
      ),
    );
  });

  testWidgets('跨原始消息的工具调用仅在无推理间隔时合并', (tester) async {
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

    expect(find.byType(ToolGroupCard), findsOneWidget);
    expect(find.byType(ToolCard), findsNothing);
    expect(find.text('2 tool calls'), findsOneWidget);

    await pumpMessages([
      first,
      second.copyWith(reasoningContent: 'reasoning between tools'),
    ]);

    expect(find.byType(ToolGroupCard), findsNothing);
    expect(find.byType(ToolCard), findsNWidgets(2));
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

  testWidgets('长 Assistant 卡片由外层视口懒构建且没有内部滚动', (tester) async {
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

    expect(find.byType(DecoratedSliver), findsNothing);
    expect(find.byType(SliverList), findsOneWidget);
    expect(find.byType(Scrollable), findsOneWidget);
    expect(find.byType(AthenaMarkdown), findsWidgets);
    expect(find.byType(AthenaMarkdown).evaluate().length, lessThan(20));
  });

  testWidgets('多个工具调用默认折叠在同一张 ToolGroupCard 中', (tester) async {
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

    expect(find.byType(ToolGroupCard), findsOneWidget);
    expect(find.byType(ToolCard), findsNothing);
    expect(find.text('2 tool calls'), findsOneWidget);
    expect(find.text('done'), findsNothing);
    expect(find.text('running'), findsNothing);
    expect(find.byType(ShaderMask), findsNothing);
    expect(find.text('file_read'), findsNothing);
    expect(find.text('/tmp/a.dart'), findsNothing);

    final groupMaterials = tester.widgetList<Material>(
      find.descendant(
        of: find.byType(ToolGroupCard),
        matching: find.byType(Material),
      ),
    );
    expect(
      groupMaterials.every((material) => material.color == Colors.transparent),
      isTrue,
    );

    final title = tester.widget<Text>(find.text('2 tool calls'));
    expect(title.style?.color, AthenaColors.dark.textSecondaryOnRaised);

    final header = tester.widget<InkWell>(
      find.descendant(
        of: find.byType(ToolGroupCard),
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

    expect(find.byType(ToolGroupCard), findsOneWidget);
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
}
