import 'dart:async';

import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/service/llm_client.dart';
import 'package:openai_dart/openai_dart.dart';

/// 自动重命名对话标题的提示词。
const _namingPrompt = '''
你的任务是为一段非结构化的对话生成一个极简、精准的标题。

# 核心约束
1.  **长度控制**:
    - 中文标题:限制在 **4-10 个汉字** 以内。
    - 英文标题:限制在 **2-6 个单词** 以内。
    - 严禁过短(如仅一个词)或过长(如完整句子)。
2.  **格式清洗**:
    - **严禁**包含标点符号(如 `。` `?` `!`)。
    - **严禁**包含特殊字符(如 `#` `*` `Emoji`)。
    - **严禁**输出如 "标题:"、"Summary:" 等前缀。
3.  **语言一致性**:标题必须与用户首要使用的语言保持一致。

# 摘要逻辑
- 分析用户的核心意图(Intent)或主要话题(Topic)。
- 去除客套话(如"你好"、"请问"),直接提炼关键词。
- 优先保留专有名词(如 "Flutter状态管理" > "关于状态管理的问题")。

# 输出规范
仅输出且只输出生成的标题文本。不要包裹在引号或代码块中。

# 示例

Input: "我想问一下关于那个最新的iPhone 15 Pro Max的散热问题"
Output: iPhone15散热分析

Input: "写一个Python脚本来自动备份MySQL数据库"
Output: Python数据库备份脚本

Input: "How do I implement a binary search tree in Golang?"
Output: Golang Binary Search Tree

Input: "今天天气不错,适合去哪玩?"
Output: 游玩地点推荐
''';

/// 聊天相关的 AI 网络请求。
///
/// 在 [LlmClient] 之上提供 chat 特有的默认值（如 StreamOptions、temperature）。
/// 不涉及消息格式转换（→ [ChatMessageConverter]）、
/// 会话/消息持久化（→ [ChatStoreService]）、
/// 或 UI 辅助操作（→ [ChatUpdateService]）。
class ChatCompletionsService {
  final LlmClient _llmClient;

  ChatCompletionsService({
    required LlmClient llmClient,
  }) : _llmClient = llmClient;

  /// 测试连接
  Future<String> connect({
    required ProviderEntity provider,
    required ModelEntity model,
  }) async {
    var request = ChatCompletionCreateRequest(
      model: model.modelId,
      messages: [ChatMessage.user('Hi')],
    );
    var response = await _llmClient.fetch(
      provider: provider,
      request: request,
    );
    return response.text ?? '';
  }

  /// 获取聊天完成流
  Stream<ChatStreamEvent> getCompletion({
    required ChatEntity chat,
    required List<ChatMessage> messages,
    required ProviderEntity provider,
    required ModelEntity model,
    List<Tool>? tools,
    ResponseFormat? responseFormat,
    Future<void>? cancelSignal,
  }) async* {
    var request = ChatCompletionCreateRequest(
      model: model.modelId,
      messages: messages,
      temperature: chat.temperature,
      reasoningEffort: _parseReasoningEffort(chat.reasoningEffort),
      tools: tools,
      responseFormat: responseFormat,
      streamOptions: const StreamOptions(includeUsage: true),
    );
    yield* _llmClient.stream(
      provider: provider,
      request: request,
      cancelSignal: cancelSignal,
    );
  }

  /// 非流式完成，用于辅助模型摘要等场景
  Future<String> complete({
    required List<ChatMessage> messages,
    required ProviderEntity provider,
    required ModelEntity model,
    Future<void>? cancelSignal,
  }) async {
    var request = ChatCompletionCreateRequest(
      model: model.modelId,
      messages: messages,
    );
    var response = await _llmClient.fetch(
      provider: provider,
      request: request,
      cancelSignal: cancelSignal,
    );
    return response.text ?? '';
  }

  /// 获取聊天标题流
  Stream<String> getTitle(
    String value, {
    required ProviderEntity provider,
    required ModelEntity model,
  }) async* {
    var request = ChatCompletionCreateRequest(
      model: model.modelId,
      messages: [
        ChatMessage.system(_namingPrompt),
        ChatMessage.user(value),
      ],
    );
    var stream = _llmClient.stream(provider: provider, request: request);
    await for (final chunk in stream) {
      if (chunk.choices == null || chunk.choices!.isEmpty) continue;
      yield chunk.choices!.first.delta.content ?? '';
    }
  }
}

/// 解析会话存储的推理强度字符串为官方枚举；非法/未识别值返回 null
/// （不传参，交由模型决定），避免把 unknown 发送到 API。
ReasoningEffort? _parseReasoningEffort(String? value) {
  if (value == null) return null;
  final parsed = ReasoningEffort.fromJson(value);
  return parsed == ReasoningEffort.unknown ? null : parsed;
}
