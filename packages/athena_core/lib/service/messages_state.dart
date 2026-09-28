import 'dart:convert';

import 'package:anthropic_sdk_dart/anthropic_sdk_dart.dart' as anthropic;
import 'package:athena_core/entity/api_format.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:crypto/crypto.dart';
import 'package:openai_dart/openai_dart.dart';

/// thinking 的签名与原始 content 顺序一起保存，不能从展示文字重建。
class MessagesState {
  final String? providerId;
  final String baseUrl;
  final String model;
  final List<Map<String, dynamic>> content;
  final int reasoningTokens;
  final String prefixHash;
  final Map<String, dynamic>? thinking;
  final Map<String, dynamic>? outputConfig;
  final String _messageHash;

  MessagesState({
    required ProviderEntity provider,
    required this.model,
    required this.content,
    required this.reasoningTokens,
    required this.prefixHash,
    this.thinking,
    this.outputConfig,
    required AssistantMessage message,
  }) : providerId = provider.id,
       baseUrl = _normalizeUrl(provider.baseUrl),
       _messageHash = _hashMessage(message);

  MessagesState._(Map<String, dynamic> json)
    : providerId = json['provider_id'] as String?,
      baseUrl = json['base_url'] as String,
      model = json['model'] as String,
      content = (json['content'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(),
      reasoningTokens = json['reasoning_tokens'] as int,
      prefixHash = json['prefix_hash'] as String,
      thinking = (json['thinking'] as Map?)?.cast<String, dynamic>(),
      outputConfig = (json['output_config'] as Map?)?.cast<String, dynamic>(),
      _messageHash = json['message_hash'] as String;

  static MessagesState? decode(String value) {
    if (value.isEmpty) return null;
    try {
      final json = jsonDecode(value) as Map<String, dynamic>;
      if (json['version'] != 1) return null;
      final state = MessagesState._(json);
      if (state.reasoningTokens < 0 || !hasCompleteThinking(state.content)) {
        return null;
      }
      for (final block in state.content) {
        anthropic.InputContentBlock.fromJson(block);
      }
      if (state.thinking != null) {
        anthropic.ThinkingConfig.fromJson(state.thinking!);
      }
      if (state.outputConfig != null) {
        anthropic.OutputConfig.fromJson(state.outputConfig!);
      }
      return state;
    } catch (_) {
      // 旧记录和损坏的可选状态仍可使用正文与工具历史。
      return null;
    }
  }

  String encode() => jsonEncode({
    'version': 1,
    'provider_id': providerId,
    'base_url': baseUrl,
    'model': model,
    'content': content,
    'reasoning_tokens': reasoningTokens,
    'prefix_hash': prefixHash,
    'thinking': thinking,
    'output_config': outputConfig,
    'message_hash': _messageHash,
  });

  bool matches(
    ProviderEntity provider,
    String model,
    AssistantMessage message,
    String prefixHash,
  ) =>
      provider.apiFormat == ApiFormat.messages &&
      provider.id == providerId &&
      _normalizeUrl(provider.baseUrl) == baseUrl &&
      model == this.model &&
      prefixHash == this.prefixHash &&
      matchesMessage(message);

  bool matchesMessage(AssistantMessage message) =>
      _hashMessage(message) == _messageHash;

  /// 新版 Claude 校验 system/tools/先前消息；压缩或编辑后不回传旧签名。
  static String hashPrefix(anthropic.MessageCreateRequest request) => hashJson({
    'system': request.system?.toJson(),
    'tools': request.tools?.map((tool) => tool.toJson()).toList(),
    'messages': request.messages.map((message) => message.toJson()).toList(),
  });

  static bool hasCompleteThinking(List<Map<String, dynamic>> content) {
    var found = false;
    for (final block in content) {
      if (block['type'] == 'thinking') {
        found = true;
        if (block['thinking'] is! String ||
            block['signature'] is! String ||
            (block['signature'] as String).isEmpty) {
          return false;
        }
      } else if (block['type'] == 'redacted_thinking') {
        found = true;
        if (block['data'] is! String || (block['data'] as String).isEmpty) {
          return false;
        }
      }
    }
    return found;
  }

  static String _normalizeUrl(String url) => url
      .trim()
      .replaceFirst(RegExp(r'/+$'), '')
      .replaceFirst(RegExp(r'/v1$'), '');

  static String _hashMessage(AssistantMessage message) => hashJson({
    'content': message.content ?? '',
    'tool_calls': [
      for (final call in message.toolCalls ?? <ToolCall>[])
        {
          'id': call.id,
          'name': call.function.name,
          // 流式参数保留空白，非流式参数来自对象；两者应有同一个指纹。
          'arguments': _arguments(call.function.arguments),
        },
    ],
  });

  static Object? _arguments(String value) {
    if (value.trim().isEmpty) return const <String, dynamic>{};
    try {
      return jsonDecode(value);
    } catch (_) {
      return value;
    }
  }

  static String hashJson(Object? value) =>
      sha256.convert(utf8.encode(jsonEncode(_canonical(value)))).toString();

  static Object? _canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: _canonical(value[key])};
    }
    if (value is List) return value.map(_canonical).toList();
    return value;
  }
}

/// 公共 toJson 不包含签名，避免送进其他协议、摘要或普通日志。
class MessagesAssistantMessage extends AssistantMessage {
  final MessagesState? messagesState;
  const MessagesAssistantMessage({
    super.content,
    super.toolCalls,
    super.reasoningContent,
    super.refusal,
    this.messagesState,
  });
}

/// 只在完整 message_stop 后发布可回传状态。
class MessagesStateChunk extends ChatStreamEvent {
  final MessagesState state;
  const MessagesStateChunk(this.state);
}
