import 'dart:convert';
import 'dart:math';

import 'package:athena_core/agent/tool/tool_output_store.dart';
import 'package:athena_core/service/responses_state.dart';
import 'package:athena_core/service/chat_completions_state.dart';
import 'package:athena_core/service/messages_state.dart';
import 'package:openai_dart/openai_dart.dart';

/// Checks every request, including iterations within a single run.
///
/// 估算是本地的字节级启发式（见 [_estimate]），与 provider 的 tokenizer 有
/// 系统性偏差：JSON 与英文内容约高估 2 倍（实测工具 schema 2.48 倍、本仓库
/// AGENTS.md 1.4~1.7 倍）。所以每次真实响应都用 provider 回报的
/// `prompt_tokens` 双向校准 [estimate]：偏大拉回、偏小抬高，让它尽量等于
/// provider 的口径——否则「上下文占用 80%」在两侧含义不同：指示器显示真实
/// 用量、压缩触发用高估的估算，于是指示器还不到 80% 就先压缩了。
/// 安全余量不靠高估，而是 [inputLimit] 给输出留的那部分。
class ContextBudget {
  ContextBudget(this.contextWindow, {String? calibrationKey})
    : _calibrationKey = calibrationKey,
      _usageScale = _calibrations[calibrationKey] ?? 1;

  final int contextWindow;

  /// 校准是模型（tokenizer）的属性，不是某一次 run 的属性：GUI / TUI 都是
  /// 长驻进程，同一个模型的第二个 run 不该从「保守高估」重新学起，否则每轮
  /// run 的第一个请求（压缩触发就在这一步）都会按高估值判断。
  /// key 为 null 时（测试与未知模型）不跨实例共享。
  static final Map<String, double> _calibrations = {};

  /// 单次观察到的 真实/估算 比值超出这个范围就不采纳：低于下限说明这次观察
  /// 本身可疑（provider 漏报缓存、消息被替换过），高于上限说明估算漏了内容，
  /// 两种情况都不该把校准甩到任意值上。
  static const double _minScale = 0.25;
  static const double _maxScale = 4;

  final String? _calibrationKey;
  double _usageScale;

  int get inputLimit => contextWindow - min(8192, max(256, contextWindow ~/ 5));

  bool shouldCompact(List<ChatMessage> messages, List<Tool>? tools) =>
      contextWindow > 0 &&
      estimate(messages, tools) >=
          min((contextWindow * 0.8).floor(), inputLimit);

  int estimate(List<ChatMessage> messages, List<Tool>? tools) =>
      (_estimate(messages, tools) * _usageScale).ceil();

  /// 这次请求还能留给输出的 token 数；窗口未知时为 null。
  ///
  /// 按校准后的估算算余量：估算已被 provider 回报的真实用量拉齐（见
  /// [observe]），所以这个余量是「窗口减去真实输入的近似值」，不再自带
  /// 高估带来的额外余量。
  int? outputRoom(List<ChatMessage> messages, List<Tool>? tools) =>
      contextWindow > 0 ? contextWindow - estimate(messages, tools) : null;

  void observe({
    required int promptTokens,
    required List<ChatMessage> messages,
    required List<Tool>? tools,
  }) {
    final estimated = _estimate(messages, tools);
    if (estimated <= 0 || promptTokens <= 0) return;
    _usageScale = (promptTokens / estimated)
        .clamp(_minScale, _maxScale)
        .toDouble();
    final key = _calibrationKey;
    if (key != null) _calibrations[key] = _usageScale;
  }

  Future<List<ChatMessage>> prepare({
    required List<ChatMessage> messages,
    required List<Tool>? tools,
    required ToolOutputStore outputs,
  }) async {
    final requestMessages = List<ChatMessage>.of(messages);
    if (contextWindow <= 0 || estimate(requestMessages, tools) <= inputLimit) {
      return requestMessages;
    }

    // Keep the newest tool batch intact, especially a page just read on demand.
    // Older results remain recoverable; assistant/tool pairing is never changed.
    final latestBatch = messages.lastIndexWhere(
      (m) => m is AssistantMessage && (m.toolCalls?.isNotEmpty ?? false),
    );
    final end = latestBatch < 0 ? messages.length : latestBatch;
    for (var i = 0; i < end; i++) {
      final message = requestMessages[i];
      if (message is! ToolMessage || message.content.length <= 512) continue;
      requestMessages[i] = ChatMessage.tool(
        toolCallId: message.toolCallId,
        content: await outputs.reference(message.content),
      );
      if (estimate(requestMessages, tools) <= inputLimit) {
        return requestMessages;
      }
    }

    throw StateError(
      'Context budget exceeded: approximately '
      '${estimate(requestMessages, tools)} input tokens, '
      '$inputLimit available in a $contextWindow-token window '
      '(output space reserved). Reduce the conversation context or use '
      'a model with a larger context window. Saved tool outputs are retained.',
    );
  }

  int _estimate(List<ChatMessage> messages, List<Tool>? tools) {
    var imageTokens = 0;
    Object? withoutImageData(Object? value) {
      if (value is Map) {
        return <String, Object?>{
          for (final entry in value.entries)
            entry.key as String: entry.key == 'image_url'
                ? (() {
                    imageTokens += 4096;
                    return '[image]';
                  })()
                : withoutImageData(entry.value),
        };
      }
      if (value is List) return value.map(withoutImageData).toList();
      return value;
    }

    final payload = withoutImageData({
      'messages': messages.map((m) => m.toJson()).toList(),
      if (tools != null) 'tools': tools.map((t) => t.toJson()).toList(),
    });
    // 每 token 按两个 UTF-8 字节估：对代码与非拉丁文本留了余量，代价是英文
    // 与 JSON 会高估约 2 倍——落回 provider 的口径靠 [observe] 的双向校准，
    // 不要在这里为了"更准"改常数（拿不到 provider 的 tokenizer）。
    return (utf8.encode(jsonEncode(payload)).length / 2).ceil() +
        messages.length * 16 +
        // 密文长度不等于 token 数；回传的隐藏推理按已报告用量预留空间。
        messages.whereType<ResponsesAssistantMessage>().fold<int>(0, (
          sum,
          message,
        ) {
          final state = message.responsesState;
          return sum +
              (state != null && state.matchesMessage(message)
                  ? state.reasoningTokens
                  : 0);
        }) +
        messages.whereType<MessagesAssistantMessage>().fold<int>(0, (
          sum,
          message,
        ) {
          final state = message.messagesState;
          return sum +
              (state != null && state.matchesMessage(message)
                  ? state.reasoningTokens
                  : 0);
        }) +
        messages.whereType<ChatCompletionsAssistantMessage>().fold<int>(0, (
          sum,
          message,
        ) {
          final state = message.chatCompletionsState;
          return sum +
              (state != null && state.matchesMessage(message)
                  ? state.reasoningTokens
                  : 0);
        }) +
        imageTokens;
  }
}

/// [error] 是否是"输入超出模型上下文窗口"这一类失败。
///
/// 三家的错误都不走结构化字段，只能在客户端按文案认：OpenAI 兼容端
/// `context_length_exceeded` / "maximum context length"、Anthropic
/// "prompt is too long" / "exceed context limit"、Google 兼容端
/// "exceeds the maximum number of tokens"，以及 [ContextBudget.prepare]
/// 自己抛的 "Context budget exceeded"。
///
/// 只认这些明确的说法：认不出就返回 false，让错误照常冒泡——宁可少恢复一次，
/// 也不要把无关失败（鉴权、路由、配额）当成超限去重试。
bool isContextOverflowError(Object error) {
  final text = error.toString().toLowerCase();
  return _contextOverflowMarkers.any(text.contains);
}

const _contextOverflowMarkers = [
  'context budget exceeded',
  'context_length_exceeded',
  'maximum context length',
  'exceeds the maximum number of tokens',
  'exceed context limit',
  'prompt is too long',
  'input is too long',
  'too many input tokens',
];
