import 'dart:io';

import 'package:athena_core/agent/agent_service.dart';
import 'package:athena_core/agent/project_instructions.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:test/test.dart';

/// 注入块的**顺序**是对外行为：runtime 必须紧接历史之前，project 紧挨 runtime，
/// 两者的下标供 run 循环就地刷新。顺序漂移不会被功能测试发现（模型照样能答），
/// 所以在这里把布局钉死。
void main() {
  const runtimeText = 'Current date: 2026-09-23.';

  /// 模拟 ChatMessageConverter.buildMessages 的产物：首个 system 是 sentinel，
  /// 其后的 system 是稳定的 Memory 目录，其余是对话历史。
  List<ChatMessage> baseMessages() => <ChatMessage>[
    ChatMessage.system('sentinel prompt'),
    ChatMessage.system('memory digest'),
    ChatMessage.user('把 hover 高亮修一下'),
    ChatMessage.assistant(content: '先看实现。'),
  ];

  String contentAt(List<ChatMessage> messages, int index) =>
      (messages[index] as SystemMessage).content;

  test(
    '顺序为 [sentinel, evolution, skill, memory, project, runtime, history]',
    () {
      final layout = layoutPromptMessages(
        base: baseMessages(),
        runtimeText: runtimeText,
        hasSentinelPrompt: true,
        evolutionPrompt: 'evolution hint',
        skillPrompt: 'skill catalog',
        projectPrompt: 'project conventions',
      );

      expect(layout.messages, hasLength(8));
      expect(contentAt(layout.messages, 0), 'sentinel prompt');
      expect(contentAt(layout.messages, 1), 'evolution hint');
      expect(contentAt(layout.messages, 2), 'skill catalog');
      expect(contentAt(layout.messages, 3), 'memory digest');
      expect(contentAt(layout.messages, 4), 'project conventions');
      expect(contentAt(layout.messages, 5), runtimeText);
      expect(layout.messages[6], isA<UserMessage>());
    },
  );

  test('两个下标指向各自的块，且 project 紧挨 runtime 之前', () {
    final layout = layoutPromptMessages(
      base: baseMessages(),
      runtimeText: runtimeText,
      hasSentinelPrompt: true,
      evolutionPrompt: 'evolution hint',
      skillPrompt: 'skill catalog',
      projectPrompt: 'project conventions',
    );

    expect(layout.projectMessageIndex, 4);
    expect(layout.runtimeMessageIndex, 5);
    expect(layout.projectMessageIndex, layout.runtimeMessageIndex - 1);
    expect(
      contentAt(layout.messages, layout.projectMessageIndex),
      'project conventions',
    );
    expect(contentAt(layout.messages, layout.runtimeMessageIndex), runtimeText);
  });

  test('无项目约定时不注入该块，下标为 -1', () {
    final layout = layoutPromptMessages(
      base: baseMessages(),
      runtimeText: runtimeText,
      hasSentinelPrompt: true,
      skillPrompt: 'skill catalog',
    );

    expect(layout.projectMessageIndex, -1);
    expect(layout.runtimeMessageIndex, 3);
    expect(layout.messages, hasLength(6));
    expect(contentAt(layout.messages, 3), runtimeText);
  });

  test('无 sentinel 时全部 system 都按附加上下文处理', () {
    final layout = layoutPromptMessages(
      base: <ChatMessage>[
        ChatMessage.system('extra context'),
        ChatMessage.user('hi'),
      ],
      runtimeText: runtimeText,
      hasSentinelPrompt: false,
      evolutionPrompt: 'evolution hint',
      projectPrompt: 'project conventions',
    );

    expect(contentAt(layout.messages, 0), 'evolution hint');
    expect(contentAt(layout.messages, 1), 'extra context');
    expect(contentAt(layout.messages, 2), 'project conventions');
    expect(layout.runtimeMessageIndex, 3);
    expect(contentAt(layout.messages, 3), runtimeText);
    expect(layout.messages[4], isA<UserMessage>());
  });

  test('注入块来自工作文件夹的 AGENTS.md，下标指向同一段内容', () {
    // run 的装配顺序是「先 load 再 layout，把两个下标交给循环就地刷新」，
    // 这里把这段组合钉住：下标必须落在真正装了约定的那条消息上。
    final workspace = Directory.systemTemp.createTempSync('athena_layout_');
    addTearDown(() {
      if (workspace.existsSync()) workspace.deleteSync(recursive: true);
    });
    File(
      '${workspace.path}${Platform.pathSeparator}AGENTS.md',
    ).writeAsStringSync('# 约定\n\n改完必须跑 dart analyze。\n');

    final instructions = ProjectInstructions.load(workspace.path);
    final layout = layoutPromptMessages(
      base: baseMessages(),
      runtimeText: runtimeText,
      hasSentinelPrompt: true,
      projectPrompt: instructions?.prompt,
    );

    final injected = contentAt(layout.messages, layout.projectMessageIndex);
    expect(injected, contains('改完必须跑 dart analyze'));
    expect(injected, contains(instructions!.path));
    expect(layout.projectMessageIndex, layout.runtimeMessageIndex - 1);
  });
}
