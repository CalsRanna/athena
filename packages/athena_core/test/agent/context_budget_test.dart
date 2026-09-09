import 'package:athena_core/agent/context_budget.dart';
import 'package:athena_core/agent/tool/tool_output_store.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:test/test.dart';

AssistantMessage _call(String id) => AssistantMessage(
  toolCalls: [
    ToolCall(
      id: id,
      type: 'function',
      function: const FunctionCall(name: 'read', arguments: '{}'),
    ),
  ],
);

void main() {
  test(
    'old results become readable references while latest batch stays intact',
    () async {
      final old = 'old output ' * 1000;
      final latest = 'latest page ' * 100;
      final messages = <ChatMessage>[
        ChatMessage.system('sentinel'),
        ChatMessage.user('task'),
        _call('old'),
        ChatMessage.tool(toolCallId: 'old', content: old),
        _call('new'),
        ChatMessage.tool(toolCallId: 'new', content: latest),
      ];
      final outputs = ToolOutputStore();
      final budget = ContextBudget(5000);
      final prepared = await budget.prepare(
        messages: messages,
        tools: null,
        outputs: outputs,
      );
      expect(prepared, hasLength(messages.length));
      expect((prepared[2] as AssistantMessage).toolCalls!.single.id, 'old');
      expect((prepared[3] as ToolMessage).toolCallId, 'old');
      expect(
        (prepared[3] as ToolMessage).content,
        contains(await outputs.save(old)),
      );
      expect((prepared.last as ToolMessage).content, latest);
      expect(
        (messages[3] as ToolMessage).content,
        old,
        reason: 'stored history stays intact',
      );
      expect(
        budget.estimate(prepared, null),
        lessThanOrEqualTo(budget.inputLimit),
      );
      final replay = await budget.prepare(
        messages: messages,
        tools: null,
        outputs: outputs,
      );
      expect(replay.map((m) => m.toJson()), prepared.map((m) => m.toJson()));
    },
  );

  test('unshrinkable input is rejected with output space reserved', () async {
    final budget = ContextBudget(4000);
    expect(budget.inputLimit, 3200);
    await expectLater(
      budget.prepare(
        messages: [ChatMessage.user('x' * 10000)],
        tools: null,
        outputs: ToolOutputStore(),
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('output space reserved'),
        ),
      ),
    );
  });

  test('actual usage corrects underestimated token counts', () async {
    final budget = ContextBudget(10000);
    final messages = [ChatMessage.user('x' * 500)];
    final before = budget.estimate(messages, null);
    budget.observe(promptTokens: before * 4, messages: messages, tools: null);
    expect(budget.estimate(messages, null), before * 4);
  });

  test('image data is not counted as base64 text and schemas use budget', () {
    final budget = ContextBudget(100000);
    final messages = [
      ChatMessage.user([
        ContentPart.imageBase64(data: 'a' * 1000000, mediaType: 'image/jpeg'),
      ]),
    ];
    expect(budget.estimate(messages, null), inInclusiveRange(4096, 5000));
    final tools = [
      Tool.function(name: 'large_schema', description: 'x' * 10000),
    ];
    expect(
      budget.estimate(messages, tools),
      greaterThan(budget.estimate(messages, null) + 4000),
    );
  });
}
