import 'dart:convert';

import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_gui/util/message_display_util.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MessageEntity message({
    required int id,
    required String role,
    String content = '',
  }) {
    return MessageEntity(id: id, chatId: 1, role: role, content: content);
  }

  test('连续 assistant 消息共用卡片但保留原始记录', () {
    final first = message(id: 1, role: 'assistant', content: 'first');
    final second = message(id: 2, role: 'assistant', content: 'second');

    final result = buildMessageDisplayCards([first, second]);

    expect(result, hasLength(1));
    expect(result.single, hasLength(2));
    expect(identical(result.single[0], first), isTrue);
    expect(identical(result.single[1], second), isTrue);
  });

  test('用户消息会截断 assistant 卡片', () {
    final result = buildMessageDisplayCards([
      message(id: 1, role: 'user', content: 'question 1'),
      message(id: 2, role: 'assistant', content: 'answer 1a'),
      message(id: 3, role: 'assistant', content: 'answer 1b'),
      message(id: 4, role: 'user', content: 'question 2'),
      message(id: 5, role: 'assistant', content: 'answer 2'),
    ]);

    expect(result, hasLength(4));
    expect(result.map((card) => card.first.id), [1, 2, 4, 5]);
    expect(result[1].map((message) => message.id), [2, 3]);
    expect(result[3].map((message) => message.id), [5]);
  });

  test('压缩步骤属于 assistant 卡片，保留顺序并由用户消息分隔', () {
    final result = buildMessageDisplayCards([
      message(id: 1, role: 'user'),
      message(id: 2, role: 'compaction'),
      message(id: 3, role: 'assistant'),
      message(id: 4, role: 'compaction'),
      message(id: 5, role: 'assistant'),
      message(id: 6, role: 'user'),
      message(id: 7, role: 'compaction'),
    ]);

    expect(result.map((card) => card.map((message) => message.id).toList()), [
      [1],
      [2, 3, 4, 5],
      [6],
      [7],
    ]);
  });

  test('非 assistant 消息不会被吸收到 assistant 卡片', () {
    final result = buildMessageDisplayCards([
      message(id: 1, role: 'assistant'),
      message(id: 2, role: 'tool'),
      message(id: 3, role: 'assistant'),
    ]);

    expect(result, hasLength(3));
    expect(result.map((card) => card.single.id), [1, 2, 3]);
  });

  group('buildAssistantMessageLayouts', () {
    MessageEntity assistant({
      required int id,
      String reasoning = '',
      String content = '',
      List<String> calls = const [],
      List<String> results = const [],
      String reference = '',
      String role = 'assistant',
    }) {
      return MessageEntity(
        id: id,
        chatId: 1,
        role: role,
        content: content,
        reasoningContent: reasoning,
        reference: reference,
        toolCalls: calls.isEmpty
            ? ''
            : jsonEncode([
                for (final call in calls)
                  {'id': call, 'name': 'bash', 'arguments': '{}'},
              ]),
        toolResults: results.isEmpty
            ? ''
            : jsonEncode([
                for (final call in results) {'id': call, 'result': 'ok'},
              ]),
      );
    }

    /// 把片段压成可读的形状：S(步骤标识…) / C / R。
    String shape(AssistantMessageLayout layout) {
      return layout.parts
          .map(
            (part) => switch (part) {
              StepsPart(:final steps, :final live) =>
                'S${live ? '*' : ''}(${steps.map((step) => switch (step) {
                  ReasoningStep(:final message) => 'r${message.id}',
                  ToolCallStep(:final id, :final hasResult) =>
                    hasResult ? id : '$id?',
                }).join(' ')})',
              ContentPart() => 'C',
              ReferencePart() => 'R',
            },
          )
          .join(' ');
    }

    test('推理与工具跨消息按时间序合并，尾部推理吸入，正文单独成片段', () {
      final layouts = buildAssistantMessageLayouts([
        assistant(id: 1, reasoning: 'r', calls: ['a'], results: ['a']),
        assistant(id: 2, reasoning: 'r', calls: ['b'], results: ['b']),
        assistant(id: 3, reasoning: 'r', content: 'answer'),
      ], loading: false);

      expect(layouts.map((layout) => layout.message.id), [1, 3]);
      expect(shape(layouts[0]), 'S(r1 a r2 b r3)');
      expect(shape(layouts[1]), 'C');
      expect(layouts[1].addBoundarySpacing, isFalse);
    });

    test('单工具加推理是两步，同样进入同一序列', () {
      final layouts = buildAssistantMessageLayouts([
        assistant(id: 1, reasoning: 'r', calls: ['a'], results: ['a']),
      ], loading: false);

      expect(shape(layouts.single), 'S(r1 a)');
    });

    test('正文切断序列：正文后的工具另起序列并可跨消息延续', () {
      final layouts = buildAssistantMessageLayouts([
        assistant(
          id: 1,
          reasoning: 'r',
          content: 'text',
          calls: ['a'],
          results: ['a'],
        ),
        assistant(id: 2, calls: ['b'], results: ['b']),
        assistant(id: 3, reasoning: 'r', content: 'answer'),
      ], loading: false);

      expect(layouts.map((layout) => layout.message.id), [1, 3]);
      expect(shape(layouts[0]), 'S(r1) C S(a b r3)');
      expect(shape(layouts[1]), 'C');
    });

    test('引用切断序列', () {
      final layouts = buildAssistantMessageLayouts([
        assistant(
          id: 1,
          calls: ['a'],
          results: ['a'],
          reference: '[{"title":"t","url":"u"}]',
        ),
        assistant(id: 2, calls: ['b'], results: ['b']),
      ], loading: false);

      expect(shape(layouts[0]), 'S(a) R');
      expect(shape(layouts[1]), 'S(b)');
    });

    test('压缩步骤切断序列并保留为空片段的可见项', () {
      final layouts = buildAssistantMessageLayouts([
        assistant(id: 1, calls: ['a'], results: ['a']),
        assistant(id: 2, role: 'compaction'),
        assistant(id: 3, calls: ['b'], results: ['b']),
      ], loading: true);

      expect(layouts.map((layout) => layout.message.id), [1, 2, 3]);
      expect(shape(layouts[0]), 'S(a)');
      expect(layouts[1].parts, isEmpty);
      expect(layouts[1].isLive, isFalse);
      expect(shape(layouts[2]), 'S*(b)');
    });

    test('完全空的占位消息不切断序列', () {
      final layouts = buildAssistantMessageLayouts([
        assistant(id: 1, calls: ['a'], results: ['a']),
        assistant(id: 2),
        assistant(id: 3, calls: ['b'], results: ['b']),
      ], loading: false);

      expect(layouts.map((layout) => layout.message.id), [1]);
      expect(shape(layouts.single), 'S(a b)');
    });

    test('流式中且未收口的序列标记为 live，被正文收口后不再 live', () {
      final open = buildAssistantMessageLayouts([
        assistant(id: 1, reasoning: 'r', calls: ['a']),
      ], loading: true);
      expect(shape(open.single), 'S*(r1 a?)');

      final closed = buildAssistantMessageLayouts([
        assistant(id: 1, reasoning: 'r', calls: ['a'], results: ['a']),
        assistant(id: 2, reasoning: 'r', content: 'answer'),
      ], loading: true);
      expect(shape(closed[0]), 'S(r1 a r2)');

      final notLoading = buildAssistantMessageLayouts([
        assistant(id: 1, reasoning: 'r', calls: ['a']),
      ], loading: false);
      expect(shape(notLoading.single), 'S(r1 a?)');
    });

    test('普通问答只有平铺推理与正文，非首条时补边界间距', () {
      final layouts = buildAssistantMessageLayouts([
        assistant(id: 1, content: 'first'),
        assistant(id: 2, reasoning: 'r', content: 'second'),
        assistant(id: 3, calls: ['a'], results: ['a']),
      ], loading: false);

      expect(shape(layouts[0]), 'C');
      expect(layouts[0].addBoundarySpacing, isFalse);
      expect(shape(layouts[1]), 'S(r2) C');
      expect(layouts[1].addBoundarySpacing, isTrue);
      expect(shape(layouts[2]), 'S(a)');
      expect(layouts[2].addBoundarySpacing, isFalse);
    });

    test('首个 delta 前只保留一次性等待态占位', () {
      final layouts = buildAssistantMessageLayouts([
        assistant(id: 1),
      ], loading: true);

      expect(layouts.single.waitingForFirstDelta, isTrue);
      expect(layouts.single.parts, isEmpty);

      expect(buildAssistantMessageLayouts([assistant(id: 1)], loading: false),
          isEmpty);
    });
  });

  group('parseToolCallSteps', () {
    test('按 id 关联结果，缺失结果的调用视为未返回', () {
      final steps = parseToolCallSteps(
        MessageEntity(
          chatId: 1,
          role: 'assistant',
          toolCalls: jsonEncode([
            {'id': 'a', 'name': 'bash', 'arguments': '{"command":"ls"}'},
            {'id': 'b', 'name': 'file_read', 'arguments': '{}'},
          ]),
          toolResults: jsonEncode([
            {'id': 'b', 'result': 'contents'},
          ]),
        ),
      );

      expect(steps.map((step) => step.id), ['a', 'b']);
      expect(steps[0].toolName, 'bash');
      expect(steps[0].arguments, '{"command":"ls"}');
      expect(steps[0].hasResult, isFalse);
      expect(steps[1].result, 'contents');
    });

    test('非法 JSON 不抛异常：调用不合法视为无步骤，结果不合法视为未返回', () {
      expect(
        parseToolCallSteps(
          MessageEntity(chatId: 1, role: 'assistant', toolCalls: 'not json'),
        ),
        isEmpty,
      );
      final steps = parseToolCallSteps(
        MessageEntity(
          chatId: 1,
          role: 'assistant',
          toolCalls: '[{"id":"a","name":"bash","arguments":"{}"}]',
          toolResults: 'not json',
        ),
      );
      expect(steps.single.hasResult, isFalse);
    });
  });
}
