import 'dart:convert';

import 'package:athena_core/entity/api_format.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:crypto/crypto.dart';
import 'package:openai_dart/openai_dart.dart';

/// 保留完整输出顺序，reasoning item 与它关联的消息/工具调用不能拆开回传。
class ResponsesState {
  final int? providerId;
  final String baseUrl;
  final String model;
  final List<Map<String, dynamic>> output;
  final int reasoningTokens;
  final String _messageHash;

  ResponsesState({
    required ProviderEntity provider,
    required this.model,
    required this.output,
    required AssistantMessage message,
    required this.reasoningTokens,
  }) : providerId = provider.id,
       baseUrl = _normalizeUrl(provider.baseUrl),
       _messageHash = _hash(message);

  ResponsesState._(Map<String, dynamic> json)
    : providerId = json['provider_id'] as int?,
      baseUrl = json['base_url'] as String,
      model = json['model'] as String,
      output = (json['output'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(),
      reasoningTokens = json['reasoning_tokens'] as int,
      _messageHash = json['message_hash'] as String;

  static ResponsesState? decode(String value) {
    if (value.isEmpty) return null;
    try {
      final json = jsonDecode(value) as Map<String, dynamic>;
      if (json['version'] != 1) return null;
      final state = ResponsesState._(json);
      if (state.reasoningTokens < 0) return null;
      return state;
    } catch (_) {
      // 旧记录和损坏的可选状态仍可按正文/工具历史读取。
      return null;
    }
  }

  String encode() => jsonEncode({
    'version': 1,
    'provider_id': providerId,
    'base_url': baseUrl,
    'model': model,
    'output': output,
    'reasoning_tokens': reasoningTokens,
    'message_hash': _messageHash,
  });

  bool matches(
    ProviderEntity provider,
    String model,
    AssistantMessage message,
  ) =>
      provider.apiFormat == ApiFormat.responses &&
      provider.id == providerId &&
      _normalizeUrl(provider.baseUrl) == baseUrl &&
      model == this.model &&
      matchesMessage(message);

  /// 编辑正文或过滤孤立调用后，不得用旧输出恢复被删掉的内容/工具调用。
  bool matchesMessage(AssistantMessage message) =>
      _hash(message) == _messageHash;

  static String _normalizeUrl(String url) =>
      url.trim().replaceFirst(RegExp(r'/+$'), '');

  static String _hash(AssistantMessage message) => sha256
      .convert(
        utf8.encode(
          jsonEncode({
            'content': message.content ?? '',
            'tool_calls':
                message.toolCalls?.map((call) => call.toJson()).toList() ?? [],
          }),
        ),
      )
      .toString();
}

/// toJson 沿用公共消息形状，避免密文泄漏进其他协议、摘要或上下文日志。
class ResponsesAssistantMessage extends AssistantMessage {
  final ResponsesState? responsesState;

  const ResponsesAssistantMessage({
    super.content,
    super.toolCalls,
    super.reasoningContent,
    super.refusal,
    this.responsesState,
  });
}

/// 只有完整响应才附带可复用状态；取消/截断时不保存半截输出。
class ResponsesStateChunk extends ChatStreamEvent {
  final ResponsesState state;
  const ResponsesStateChunk(this.state);
}
