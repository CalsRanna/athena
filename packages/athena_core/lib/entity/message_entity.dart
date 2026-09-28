import 'package:athena_core/extension/json_map_extension.dart';

class MessageEntity {
  final String? id;
  final String chatId;
  /// 会话内写入顺序，由仓储在追加时分配，更新消息时保持不变。
  final int seq;
  final String role;
  final String content;
  final String reasoningContent;
  final bool reasoning;
  final String imageUrls;
  final String reference;
  final String toolCalls;
  final String toolResults;
  /// Responses 原生输出（含推理密文），独立于用于显示的 reasoningContent。
  final String responsesState;
  /// Messages 原生 content（含 thinking 签名），与展示内容分开。
  final String messagesState;
  /// Chat Completions 的原始推理扩展与拒答，仅向原始来源回传。
  final String chatCompletionsState;
  /// 原生停止原因、拒答说明和用量明细，不作为对话正文发送。
  final String completionDetails;
  /// 是否已被 compact 压缩。被压缩的消息不参与上下文组装，但保留在 DB 中供回溯。
  final bool compacted;
  final DateTime reasoningStartedAt;
  final DateTime reasoningUpdatedAt;

  MessageEntity({
    this.id,
    this.seq = 0,
    required this.chatId,
    required this.role,
    this.content = '',
    this.reasoningContent = '',
    this.reasoning = false,
    this.imageUrls = '',
    this.reference = '',
    this.toolCalls = '',
    this.toolResults = '',
    this.responsesState = '',
    this.messagesState = '',
    this.chatCompletionsState = '',
    this.completionDetails = '',
    this.compacted = false,
    DateTime? reasoningStartedAt,
    DateTime? reasoningUpdatedAt,
  }) : reasoningStartedAt = reasoningStartedAt ?? DateTime.now(),
       reasoningUpdatedAt = reasoningUpdatedAt ?? DateTime.now();

  factory MessageEntity.fromJson(Map<String, dynamic> json) {
    return MessageEntity(
      id: json.getStringOrNull('id'),
      seq: json.getInt('seq'),
      chatId: json.getString('chat_id'),
      role: json.getString('role', defaultValue: 'user'),
      content: json.getString('content'),
      reasoningContent: json.getString('reasoning_content'),
      reasoning: json.getBool('reasoning'),
      imageUrls: json.getString('image_urls'),
      reference: json.getString('reference'),
      toolCalls: json.getString('tool_calls'),
      toolResults: json.getString('tool_results'),
      responsesState: json.getString('responses_state'),
      messagesState: json.getString('messages_state'),
      chatCompletionsState: json.getString('chat_completions_state'),
      completionDetails: json.getString('completion_details'),
      compacted: json.getBool('compacted'),
      reasoningStartedAt: json.getDateTimeOrNull('reasoning_started_at'),
      reasoningUpdatedAt: json.getDateTimeOrNull('reasoning_updated_at'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'chat_id': chatId,
      'seq': seq,
      'role': role,
      'content': content,
      'reasoning_content': reasoningContent,
      'reasoning': reasoning ? 1 : 0,
      'image_urls': imageUrls,
      'reference': reference,
      'tool_calls': toolCalls,
      'tool_results': toolResults,
      'responses_state': responsesState,
      'messages_state': messagesState,
      'chat_completions_state': chatCompletionsState,
      'completion_details': completionDetails,
      'compacted': compacted ? 1 : 0,
      'reasoning_started_at': reasoningStartedAt.millisecondsSinceEpoch,
      'reasoning_updated_at': reasoningUpdatedAt.millisecondsSinceEpoch,
    };
  }

  MessageEntity copyWith({
    String? id,
    int? seq,
    String? chatId,
    String? role,
    String? content,
    String? reasoningContent,
    bool? reasoning,
    String? imageUrls,
    String? reference,
    String? toolCalls,
    String? toolResults,
    String? responsesState,
    String? messagesState,
    String? chatCompletionsState,
    String? completionDetails,
    bool? compacted,
    DateTime? reasoningStartedAt,
    DateTime? reasoningUpdatedAt,
  }) {
    return MessageEntity(
      id: id ?? this.id,
      seq: seq ?? this.seq,
      chatId: chatId ?? this.chatId,
      role: role ?? this.role,
      content: content ?? this.content,
      reasoningContent: reasoningContent ?? this.reasoningContent,
      reasoning: reasoning ?? this.reasoning,
      imageUrls: imageUrls ?? this.imageUrls,
      reference: reference ?? this.reference,
      toolCalls: toolCalls ?? this.toolCalls,
      toolResults: toolResults ?? this.toolResults,
      responsesState: responsesState ?? this.responsesState,
      messagesState: messagesState ?? this.messagesState,
      chatCompletionsState: chatCompletionsState ?? this.chatCompletionsState,
      completionDetails: completionDetails ?? this.completionDetails,
      compacted: compacted ?? this.compacted,
      reasoningStartedAt: reasoningStartedAt ?? this.reasoningStartedAt,
      reasoningUpdatedAt: reasoningUpdatedAt ?? this.reasoningUpdatedAt,
    );
  }
}
