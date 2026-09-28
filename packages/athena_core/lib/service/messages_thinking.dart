import 'dart:math';

import 'package:anthropic_sdk_dart/anthropic_sdk_dart.dart' as anthropic;
import 'package:openai_dart/openai_dart.dart';

/// 不同代 Claude 的推理参数不兼容，不能直接透传 OpenAI 的 effort。
/// 未识别的 Messages 兼容模型沿用手动 budget 协议。
class MessagesThinking {
  final anthropic.ThinkingConfig? thinking;
  final anthropic.OutputConfig? outputConfig;
  final bool omitTemperature;

  const MessagesThinking(
    this.thinking,
    this.outputConfig,
    this.omitTemperature,
  );

  factory MessagesThinking.resolve(
    String model,
    ReasoningEffort? effort,
    int maxTokens,
  ) {
    final id = model.toLowerCase().replaceAll('.', '-');
    final match = RegExp(
      r'claude-(opus|sonnet|haiku|fable|mythos)-(\d+)(?:-(\d)(?=-|$))?',
    ).firstMatch(id);
    final family = match?.group(1);
    final major = int.tryParse(match?.group(2) ?? '') ?? 0;
    final minor = int.tryParse(match?.group(3) ?? '') ?? 0;
    final mythosPreview = id.contains('claude-mythos-preview');
    final adaptive =
        mythosPreview ||
        family == 'fable' ||
        family == 'mythos' ||
        ((family == 'opus' || family == 'sonnet') &&
            (major >= 5 || (major == 4 && minor >= 6)));
    final fixedSampling =
        mythosPreview ||
        family == 'fable' ||
        family == 'mythos' ||
        major >= 5 ||
        (major == 4 && minor >= 7);
    final alwaysThinking =
        mythosPreview ||
        family == 'fable' ||
        family == 'mythos' ||
        (family == 'opus' && (major > 5 || (major == 5 && minor >= 5)));

    if (effort == null) return MessagesThinking(null, null, fixedSampling);
    if (effort == ReasoningEffort.unknown) {
      throw UnsupportedError('Unknown reasoning effort for Messages');
    }
    if (effort == ReasoningEffort.none) {
      if (alwaysThinking) {
        throw UnsupportedError('$model does not support disabling thinking');
      }
      return MessagesThinking(
        anthropic.ThinkingConfig.disabled(),
        null,
        fixedSampling,
      );
    }

    if (adaptive) {
      final level = switch (effort) {
        ReasoningEffort.minimal ||
        ReasoningEffort.low => anthropic.EffortLevel.low,
        ReasoningEffort.medium => anthropic.EffortLevel.medium,
        ReasoningEffort.high => anthropic.EffortLevel.high,
        // 4.6 与 Mythos Preview 没有 xhigh，提升到支持的 max。
        ReasoningEffort.xhigh =>
          fixedSampling && !mythosPreview
              ? anthropic.EffortLevel.xhigh
              : anthropic.EffortLevel.max,
        _ => anthropic.EffortLevel.max,
      };
      return MessagesThinking(
        anthropic.ThinkingConfig.adaptive(
          display: anthropic.ThinkingDisplayMode.summarized,
        ),
        anthropic.OutputConfig(effort: level),
        true,
      );
    }

    // 手动预算至少 1024，且必须小于 max_tokens；窗口不足时明确失败，
    // 不扩大输出上限，也不静默关闭用户选择的推理。
    if (maxTokens <= 1024) {
      throw StateError(
        'Messages thinking requires max_tokens greater than 1024',
      );
    }
    final budget = switch (effort) {
      ReasoningEffort.minimal => 1024,
      ReasoningEffort.low => 2048,
      ReasoningEffort.medium => 4096,
      ReasoningEffort.high => 8192,
      _ => 16384,
    };
    return MessagesThinking(
      anthropic.ThinkingConfig.enabled(
        budgetTokens: min(budget, max(1024, maxTokens - 1024)),
      ),
      null,
      true,
    );
  }
}
