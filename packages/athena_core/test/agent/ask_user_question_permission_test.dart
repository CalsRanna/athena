import 'dart:convert';

import 'package:athena_core/agent/agent_service.dart';
import 'package:athena_core/agent/tool/ask_user_question_tool.dart';
import 'package:athena_core/agent/tool/bash_shell_tool.dart';
import 'package:athena_core/agent/tool/tool_registry.dart';
import 'package:athena_core/agent/permission/permission_rule.dart';
import 'package:athena_core/agent/permission/permission_service.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/service/chat_completions_service.dart';
import 'package:athena_core/service/llm_client.dart';
import 'package:test/test.dart';
import 'package:openai_dart/openai_dart.dart';

/// 按次序返回预设 chunk 序列的假 chat service。
class _ScriptedChat extends ChatCompletionsService {
  _ScriptedChat(this._script) : super(llmClient: LlmClient());

  final List<List<ChatStreamEvent> Function()> _script;
  int calls = 0;

  @override
  Stream<ChatStreamEvent> getCompletion({
    required ChatEntity chat,
    required List<ChatMessage> messages,
    required ProviderEntity provider,
    required ModelEntity model,
    List<Tool>? tools,
    ResponseFormat? responseFormat,
    Future<void>? cancelSignal,
  }) async* {
    final index = calls < _script.length ? calls : _script.length - 1;
    calls++;
    for (final event in _script[index]()) {
      yield event;
    }
  }
}

ChatStreamEvent _toolCallChunk(int index, String id, String name, String args) =>
    ChatStreamEvent(
      choices: [
        ChatStreamChoice(
          index: 0,
          delta: ChatDelta(
            toolCalls: [
              ToolCallDelta(
                index: index,
                id: id,
                type: 'function',
                function: FunctionCallDelta(name: name, arguments: args),
              ),
            ],
          ),
        ),
      ],
    );

ChatStreamEvent _finishChunk(FinishReason reason) => ChatStreamEvent(
  choices: [
    ChatStreamChoice(
      index: 0,
      delta: const ChatDelta(),
      finishReason: reason,
    ),
  ],
);

ChatStreamEvent _textChunk(String text) => ChatStreamEvent(
  choices: [ChatStreamChoice(index: 0, delta: ChatDelta(content: text))],
);

ChatEntity _chat() => ChatEntity(
  id: 1,
  title: 'Test',
  sentinelId: 1,
  modelId: 1,
  retention: -1,
  temperature: 1.0,
  createdAt: DateTime(2025),
  updatedAt: DateTime(2025),
);

ProviderEntity _provider() => ProviderEntity(
  name: 'Test',
  baseUrl: 'http://localhost',
  apiKey: '',
  enabled: true,
  isPreset: false,
  createdAt: DateTime(2025),
);

ModelEntity _model() => ModelEntity(
  name: 'Test',
  modelId: 'test-model',
  providerId: 1,
  createdAt: DateTime(2025),
  updatedAt: DateTime(2025),
);

const _questionArgs = {
  'call_description': '问你要哪种输出格式',
  'approval_recommendation': 'ask',
  'approval_reason': '需要用户决定输出格式',
  'questions': [
    {
      'question': '输出用哪种格式？',
      'header': '格式',
      'options': [
        {'label': '摘要', 'description': '简短概览'},
        {'label': '详细', 'description': '完整说明'},
      ],
    },
  ],
};

void main() {
  test('模型给提问调用标 approval_recommendation=ask 时不弹审批弹窗', () async {
    final registry = ToolRegistry()..register(AskUserQuestionTool());
    final chat = _ScriptedChat([
      () => [
        _toolCallChunk(
          0,
          'q1',
          'ask_user_question',
          jsonEncode(_questionArgs),
        ),
        _finishChunk(FinishReason.toolCalls),
      ],
      () => [_textChunk('ok'), _finishChunk(FinishReason.stop)],
    ]);
    final service = AgentService(
      chatService: chat,
      toolRegistry: registry,
    );
    var approvals = 0;
    var elicits = 0;

    final events = await service
        .run(
          runId: 1,
          chat: _chat(),
          provider: _provider(),
          model: _model(),
          baseMessages: [ChatMessage.user('hi')],
          permissionService: PermissionService(store: PermissionStore()),
          onPermission: (name, description) async {
            approvals++;
            return false;
          },
          onElicit: (chatId, questions, cancelToken) async {
            elicits++;
            return {questions.single.question: '摘要'};
          },
        )
        .toList();

    expect(approvals, 0, reason: '提问本身不是需要审批的动作');
    expect(elicits, 1, reason: '提问卡片应当照常弹出');
    expect(events.whereType<AgentDoneEvent>().length, 1);
  });

  test('危险工具仍照常弹审批（防止修复过宽）', () async {
    final registry = ToolRegistry()..register(BashShellTool());
    final chat = _ScriptedChat([
      () => [
        _toolCallChunk(
          0,
          'b1',
          'bash',
          jsonEncode({'command': 'git push origin main'}),
        ),
        _finishChunk(FinishReason.toolCalls),
      ],
      () => [_textChunk('ok'), _finishChunk(FinishReason.stop)],
    ]);
    final service = AgentService(chatService: chat, toolRegistry: registry);
    var approvals = 0;

    await service
        .run(
          runId: 2,
          chat: _chat(),
          provider: _provider(),
          model: _model(),
          baseMessages: [ChatMessage.user('hi')],
          permissionService: PermissionService(store: PermissionStore()),
          onPermission: (name, description) async {
            approvals++;
            return false;
          },
        )
        .toList();

    expect(approvals, 1);
  });
}
