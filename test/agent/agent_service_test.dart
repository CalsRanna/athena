import 'package:athena/agent/agent_service.dart';
import 'package:athena/agent/tool/tool_interface.dart' as athena;
import 'package:athena/agent/tool/tool_registry.dart';
import 'package:athena/service/chat_service.dart';
import 'package:athena/service/llm_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openai_dart/openai_dart.dart' show FunctionCall, ToolCall;

/// 返回固定字符串的伪工具。
class _EchoTool extends athena.Tool {
  @override
  String get name => 'echo';

  @override
  String get description => 'Echo back';

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'required': ['message'],
    'properties': {
      'message': {'type': 'string'},
    },
  };

  @override
  Future<String> execute(Map<String, dynamic> args, {void Function(String)? onUpdate}) async {
    return 'echo: ${args['message']}';
  }
}

void main() {
  late AgentService agentService;

  setUp(() {
    final registry = ToolRegistry();
    registry.register(_EchoTool());
    agentService = AgentService(
      chatService: ChatService(llmClient: LlmClient()),
      toolRegistry: registry,
    );
  });

  ToolCall _toolCall([String args = '{"message": "hello"}']) => ToolCall(
    id: 'c1',
    type: 'function',
    function: FunctionCall(name: 'echo', arguments: args),
  );

  test('beforeToolCall block: true 拒绝执行', () async {
    final result = await agentService.executeToolCallInternal(
      toolCall: _toolCall(),
      cancelToken: null,
      beforeToolCall: (ctx) async => (block: true, reason: 'blocked'),
    );

    expect(result.processedResult, contains('blocked'));
  });

  test('beforeToolCall block: false 允许执行', () async {
    final result = await agentService.executeToolCallInternal(
      toolCall: _toolCall(),
      cancelToken: null,
      beforeToolCall: (ctx) async => (block: false, reason: ''),
    );

    expect(result.processedResult, contains('echo: hello'));
  });

  test('不提供 beforeToolCall 时正常执行', () async {
    final result = await agentService.executeToolCallInternal(
      toolCall: _toolCall(),
      cancelToken: null,
    );

    expect(result.processedResult, contains('echo: hello'));
  });

  test('afterToolCall 可覆写结果', () async {
    final result = await agentService.executeToolCallInternal(
      toolCall: _toolCall(),
      cancelToken: null,
      afterToolCall: (ctx) async => (
        content: 'overridden',
        isError: false,
      ),
    );

    expect(result.processedResult, 'overridden');
  });

  test('不提供 afterToolCall 时使用原始结果', () async {
    final result = await agentService.executeToolCallInternal(
      toolCall: _toolCall(),
      cancelToken: null,
    );

    expect(result.processedResult, contains('echo: hello'));
  });

  test('beforeToolCall + afterToolCall 串联', () async {
    final result = await agentService.executeToolCallInternal(
      toolCall: _toolCall(),
      cancelToken: null,
      beforeToolCall: (ctx) async {
        expect(ctx.args['message'], 'hello');
        return (block: false, reason: '');
      },
      afterToolCall: (ctx) async {
        expect(ctx.rawResult, contains('echo: hello'));
        return (content: 'final: ${ctx.rawResult}', isError: false);
      },
    );

    expect(result.processedResult, 'final: echo: hello');
  });
}
