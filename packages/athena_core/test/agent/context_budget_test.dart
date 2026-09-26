import 'package:athena_core/agent/context_budget.dart';
import 'package:athena_core/agent/tool/tool_output_store.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:test/test.dart';

void main() {
  group('输入上限', () {
    test('给输出留出 min(8192, max(256, 窗口/5)) 的空间', () {
      expect(ContextBudget(100000).inputLimit, 100000 - 8192);
      expect(ContextBudget(20000).inputLimit, 20000 - 4000);
      expect(ContextBudget(1000).inputLimit, 1000 - 256);
    });

    test('窗口未知（0）时从不触发压缩', () {
      final messages = [ChatMessage.user('x' * 100000)];
      expect(ContextBudget(0).shouldCompact(messages, null), isFalse);
    });
  });

  group('估算校准', () {
    final messages = [ChatMessage.user('hello world ' * 50)];

    test('按真实 prompt_tokens 向上校准，只增不减', () {
      final budget = ContextBudget(100000);
      final base = budget.estimate(messages, null);

      budget.observe(promptTokens: base * 2, messages: messages, tools: null);
      final doubled = budget.estimate(messages, null);
      expect(doubled, closeTo(base * 2, 1));

      budget.observe(promptTokens: base ~/ 4, messages: messages, tools: null);
      expect(
        budget.estimate(messages, null),
        doubled,
        reason: '低估才危险：一次偏低的用量不能把校准拉回去',
      );
    });

    test('每张图片按 4096 计，不按 base64 长度计', () {
      ChatMessage withImage(String data) => ChatMessage.user([
        ContentPart.imageBase64(data: data, mediaType: 'image/png'),
      ]);
      final budget = ContextBudget(100000);
      final small = budget.estimate([withImage('AAAA')], null);
      final large = budget.estimate([withImage('A' * 400000)], null);

      expect(small, greaterThanOrEqualTo(4096));
      expect(large, small, reason: '图片数据不按字节计入');
    });
  });

  group('prepare', () {
    const longOutput = 60000;

    List<ChatMessage> conversation() => [
      ChatMessage.user('跑两次构建'),
      ChatMessage.assistant(
        toolCalls: [
          ToolCall(
            id: 'a',
            type: 'function',
            function: const FunctionCall(name: 'bash', arguments: '{}'),
          ),
        ],
      ),
      ChatMessage.tool(toolCallId: 'a', content: 'A' * longOutput),
      ChatMessage.assistant(
        toolCalls: [
          ToolCall(
            id: 'b',
            type: 'function',
            function: const FunctionCall(name: 'bash', arguments: '{}'),
          ),
        ],
      ),
      ChatMessage.tool(toolCallId: 'b', content: 'B' * longOutput),
    ];

    String contentOf(List<ChatMessage> messages, String id) => messages
        .whereType<ToolMessage>()
        .singleWhere((m) => m.toolCallId == id)
        .content;

    test('未超限时原样返回', () async {
      final messages = conversation();
      final prepared = await ContextBudget(
        1000000,
      ).prepare(messages: messages, tools: null, outputs: ToolOutputStore());
      expect(prepared.map((m) => m.toJson()), messages.map((m) => m.toJson()));
    });

    test('超限时把较旧的长工具结果换成引用，最新一批原样保留', () async {
      // 两份输出各约 3 万 token：只放得下一份
      final prepared = await ContextBudget(50000).prepare(
        messages: conversation(),
        tools: null,
        outputs: ToolOutputStore(),
      );

      expect(contentOf(prepared, 'a'), isNot(contains('A' * 1000)));
      expect(contentOf(prepared, 'a'), contains('tool_output_read'));
      expect(
        contentOf(prepared, 'b'),
        'B' * longOutput,
        reason: '最新一批可能正是刚分页读出来的内容',
      );
      expect(
        prepared.map((m) => m.runtimeType),
        conversation().map((m) => m.runtimeType),
        reason: 'assistant 与 tool 的配对不能被打乱',
      );
    });

    test('只剩最新一批也放不下时报错，而不是静默截断', () async {
      expect(
        () => ContextBudget(20000).prepare(
          messages: conversation(),
          tools: null,
          outputs: ToolOutputStore(),
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
