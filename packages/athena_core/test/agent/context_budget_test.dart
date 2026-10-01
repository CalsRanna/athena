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

    test('按真实 prompt_tokens 双向校准', () {
      final budget = ContextBudget(100000);
      final base = budget.estimate(messages, null);

      // 估算偏小（真实用量是估算的 2 倍）：抬高。
      budget.observe(promptTokens: base * 2, messages: messages, tools: null);
      expect(budget.estimate(messages, null), closeTo(base * 2, 1));

      // 估算偏大：字节/2 的启发式对英文与 JSON 约高估 2 倍（实测工具 schema
      // 2.48 倍），必须拉回来——只增不减会让压缩在指示器还不到 80% 时就触发。
      budget.observe(promptTokens: base ~/ 2, messages: messages, tools: null);
      expect(budget.estimate(messages, null), closeTo(base / 2, 1));
    });

    test('离谱的观察值被钳制，不会把校准甩成任意倍数', () {
      final budget = ContextBudget(100000);
      final base = budget.estimate(messages, null);

      budget.observe(promptTokens: 1, messages: messages, tools: null);
      expect(budget.estimate(messages, null), closeTo(base / 4, 1));

      budget.observe(
        promptTokens: base * 1000,
        messages: messages,
        tools: null,
      );
      expect(budget.estimate(messages, null), closeTo(base * 4, 1));
    });

    test('带 calibrationKey 时校准跨实例复用，不污染其他模型', () {
      final first = ContextBudget(100000, calibrationKey: 'calibration-a');
      final base = first.estimate(messages, null);
      first.observe(promptTokens: base ~/ 2, messages: messages, tools: null);

      expect(
        ContextBudget(
          100000,
          calibrationKey: 'calibration-a',
        ).estimate(messages, null),
        closeTo(base / 2, 1),
        reason: '同一个模型的下一轮 run 不该从保守高估重新学起',
      );
      expect(
        ContextBudget(
          100000,
          calibrationKey: 'calibration-b',
        ).estimate(messages, null),
        closeTo(base, 1),
        reason: '不同模型的口径不能互相污染',
      );
      expect(
        ContextBudget(100000).estimate(messages, null),
        closeTo(base, 1),
        reason: '没有 key 的实例各自独立',
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
          const ToolCall(
            id: 'a',
            type: 'function',
            function: FunctionCall(name: 'bash', arguments: '{}'),
          ),
        ],
      ),
      ChatMessage.tool(toolCallId: 'a', content: 'A' * longOutput),
      ChatMessage.assistant(
        toolCalls: [
          const ToolCall(
            id: 'b',
            type: 'function',
            function: FunctionCall(name: 'bash', arguments: '{}'),
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

  group('超限错误识别', () {
    test('认出三家协议各自的"prompt 太长"文案', () {
      const messages = [
        "Error code: 400 - {'error': {'code': 'context_length_exceeded'}}",
        "This model's maximum context length is 128000 tokens",
        'prompt is too long: 210000 tokens > 200000 maximum',
        'input length and `max_tokens` exceed context limit',
        'The input token count exceeds the maximum number of tokens allowed',
        'Context budget exceeded: approximately 90000 input tokens',
      ];
      for (final message in messages) {
        expect(
          isContextOverflowError(StateError(message)),
          isTrue,
          reason: message,
        );
      }
    });

    test('别的失败不当作超限，避免误触发重试', () {
      const messages = [
        'Error code: 401 - invalid api key',
        'Error code: 404 - model not found',
        'rate limit exceeded',
        'Connection closed before full header was received',
      ];
      for (final message in messages) {
        expect(
          isContextOverflowError(StateError(message)),
          isFalse,
          reason: message,
        );
      }
    });
  });
}
