import 'dart:convert';
import 'dart:io';

import 'package:athena_core/agent/agent_service.dart';
import 'package:athena_core/agent/tool/file_read_tool.dart';
import 'package:athena_core/agent/tool/tool_registry.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/service/chat_completions_service.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:test/test.dart';

/// 第一轮发起 file_read，第二轮正常结束；保留每轮实际发送的消息。
class _ScriptedChatService implements ChatCompletionsService {
  _ScriptedChatService(this.path);

  final String path;
  final requests = <List<ChatMessage>>[];
  var calls = 0;

  @override
  Stream<ChatStreamEvent> getCompletion({
    required ChatEntity chat,
    required List<ChatMessage> messages,
    required ProviderEntity provider,
    required ModelEntity model,
    List<Tool>? tools,
    ResponseFormat? responseFormat,
    Future<void>? cancelSignal,
    int? outputRoom,
  }) async* {
    calls++;
    requests.add(List.of(messages));
    if (calls == 1) {
      yield ChatStreamEvent(
        choices: [
          ChatStreamChoice(
            index: 0,
            delta: ChatDelta(
              toolCalls: [
                ToolCallDelta(
                  index: 0,
                  id: 'call_1',
                  function: FunctionCallDelta(
                    name: 'file_read',
                    arguments: jsonEncode({
                      'path': path,
                      'call_description': 'read a screenshot',
                    }),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
      yield const ChatStreamEvent(
        choices: [
          ChatStreamChoice(
            index: 0,
            delta: ChatDelta(),
            finishReason: FinishReason.toolCalls,
          ),
        ],
      );
      return;
    }
    yield const ChatStreamEvent(
      choices: [ChatStreamChoice(index: 0, delta: ChatDelta(content: 'ok'))],
    );
    yield const ChatStreamEvent(
      choices: [
        ChatStreamChoice(
          index: 0,
          delta: ChatDelta(),
          finishReason: FinishReason.stop,
        ),
      ],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final now = DateTime(2026);

  Future<List<ChatMessage>> runOnce({required bool vision}) async {
    final root = Directory.systemTemp.createTempSync('athena_live_images_');
    addTearDown(() => root.deleteSync(recursive: true));
    final png = File('${root.path}/shot.png')
      ..writeAsBytesSync(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8'
          'z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
        ),
      );

    final registry = ToolRegistry()..register(FileReadTool());
    addTearDown(() => registry.backgroundTasks.dispose());
    final chatService = _ScriptedChatService(png.path);
    final service = AgentService(
      chatService: chatService,
      toolRegistry: registry,
    );

    await service
        .run(
          runId: 1,
          chat: ChatEntity(
            title: 't',
            modelId: 'm',
            sentinelId: null,
            createdAt: now,
            updatedAt: now,
          ),
          provider: ProviderEntity(
            name: 'p',
            baseUrl: 'http://localhost',
            apiKey: 'k',
            createdAt: now,
          ),
          model: ModelEntity(
            name: 'm',
            modelId: 'm',
            providerId: 'p',
            contextWindow: 200000,
            vision: vision,
            createdAt: now,
            updatedAt: now,
          ),
          baseMessages: [
            ChatMessage.system('system'),
            ChatMessage.user('看下截图'),
          ],
          hasSentinelPrompt: false,
          allowReflection: false,
          // 测试里没有审批服务；所有调用直接放行。
          onPermission: (_, _) async => true,
        )
        .drain<void>();

    expect(chatService.calls, 2, reason: '第一轮工具调用，第二轮收尾');
    return chatService.requests.last;
  }

  test('视觉模型：图片作为 user 消息排在整批工具消息之后', () async {
    final messages = await runOnce(vision: true);

    final toolIndex = messages.indexWhere((m) => m is ToolMessage);
    final imageIndex = messages.indexWhere(
      (m) =>
          m is UserMessage &&
          m.content is UserPartsContent &&
          (m.content as UserPartsContent).parts.any(
            (part) => part is ImageContentPart,
          ),
    );

    expect(toolIndex, greaterThanOrEqualTo(0));
    expect(
      imageIndex,
      greaterThan(toolIndex),
      reason: 'Chat Completions 要求 tool 消息紧跟 assistant，图片必须排在整批之后',
    );
    final parts =
        ((messages[imageIndex] as UserMessage).content as UserPartsContent)
            .parts;
    expect(
      parts.whereType<ImageContentPart>().single.url,
      startsWith('data:image/png;base64,'),
    );
  });

  test('非视觉模型：不发送图片，工具结果说明原因', () async {
    final messages = await runOnce(vision: false);

    expect(
      messages.where(
        (m) =>
            m is UserMessage &&
            m.content is UserPartsContent &&
            (m.content as UserPartsContent).parts.any(
              (part) => part is ImageContentPart,
            ),
      ),
      isEmpty,
    );
    expect(
      messages.whereType<ToolMessage>().single.content,
      contains('does not support image input'),
    );
  });
}
