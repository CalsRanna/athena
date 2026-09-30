import 'package:athena_core/agent/permission/permission_rule.dart';
import 'package:athena_core/entity/compaction_step.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/util/compaction_step_formatter.dart';
import 'package:athena_core/util/tool_args_formatter.dart';
import 'package:athena_gui/component/step_primitives.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/util/message_display_util.dart';
import 'package:athena_gui/widget/workspace_text_size.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// 一段步骤序列的卡片：单步平铺，≥ 2 步收纳为默认折叠的组。
///
/// 同一个 widget 按 [steps] 的长度决定形态（Composite）：
/// - **单步**：头部是该步骤自己的图标 / 文案 / 运行态，展开后显示它的正文
///   （推理文本 / 工具结果 / 压缩详情）。
/// - **多步**：头部进行中显示当前（最后一个）步骤文案，后面再接**已结算**步骤的
///   汇总；结束后只显示汇总（`Used 2 tools · Thought 3.2 seconds · Compacted once`）；
///   展开后按时间序逐行嵌套单步 [StepCard]，各自可再展开。
///
/// 每种步骤类型（推理 / 工具 / 压缩）只在 [_faceOf] 里有一份"表现描述"，新增
/// 类型时先加 `AssistantStep` 子类，再补这一处 switch 与汇总计数。
///
/// 展开状态只保留在 Widget 内存态，不落库；流式增量只替换消息实体、卡片位置
/// 与 key 不变，State 得以保留。序列从单步长成多步时展开态重置为折叠，避免
/// "点开过单步结果"在第 2 步到来时变成"组已展开"。
class StepCard extends StatefulWidget {
  final List<AssistantStep> steps;

  /// 序列仍在进行且本卡是它的尾部：单步推理显示 `Thinking`，组头显示当前步骤。
  final bool live;

  /// 作为组的子项：不自带 shimmer，运行态由组头统一表达。
  final bool nested;

  const StepCard({
    super.key,
    required this.steps,
    this.live = false,
    this.nested = false,
  }) : assert(steps.length > 0);

  // ─── 共享的静态工具函数 ────────────────────────────────

  /// 工具图标映射（Lucide 图标库）。审批卡沿用同一映射。
  ///
  /// shell 这一组不在这里逐个列名：清单是引擎的事实（`kShellToolNames`），
  /// 新增一个 shell 工具时它自动拿到终端图标，不必回来改这里。
  ///
  /// 文件那一组**不能**照搬 `kFileToolNames`：那个集合是权限口径上的「路径
  /// 工具」（file_read / file_write / file_update），而图标上 `tool_output_read`
  /// 也归文件一档——两个分组依据不同，硬套会漏掉它。
  static IconData toolIcon(String toolName) {
    if (kShellToolNames.contains(toolName)) return LucideIcons.terminal;
    return switch (toolName) {
      'background_task' => LucideIcons.listTodo,
      'ask_user_question' => LucideIcons.messageCircleQuestion,
      'file_read' || 'tool_output_read' => LucideIcons.file,
      'file_write' || 'file_update' => LucideIcons.pencilLine,
      'web_fetch' => LucideIcons.globe,
      'web_search' => LucideIcons.search,
      'skill' || 'skill_evolve' => LucideIcons.bookOpen,
      'sentinel_list' ||
      'sentinel_get' ||
      'sentinel_evolve' ||
      'sentinel_revert' => LucideIcons.userRound,
      'experience_learn' || 'experience_recall' => LucideIcons.brain,
      _ => LucideIcons.wrench,
    };
  }

  /// 解析不出模型自述时的通用文案：头部与「结果返回前」的正文共用这一句。
  static const usingToolLabel = 'Using a tool';

  /// 单步、组头、嵌套工具项与审批卡共用的标题，不展示参数预览。
  ///
  /// 参数 JSON 完整且包含有效的 call_description 后显示描述；否则显示
  /// [usingToolLabel]。
  static String toolLabel(String arguments) =>
      toolCallDescription(arguments) ?? usingToolLabel;

  /// 推理结束态标题：`Thought 2.0 seconds`。
  static String thoughtLabel(MessageEntity message) {
    final duration =
        message.reasoningUpdatedAt
            .difference(message.reasoningStartedAt)
            .inMilliseconds /
        1000;
    return 'Thought ${duration.toStringAsFixed(1)} seconds';
  }

  /// 压缩头部文案：进行中 / 已中断 / 终态。
  static String compactionLabel(ContextCompactionStep step) =>
      compactionStatus(step.step, isLive: step.isLive);

  /// 组结束态折叠头文案：工具数、思考总耗时、压缩次数，按存在的部分拼接。
  static String summaryLabel(List<AssistantStep> steps) {
    var toolCount = 0;
    var reasoningCount = 0;
    var compactionCount = 0;
    var thinkingMs = 0;
    for (final step in steps) {
      switch (step) {
        case ReasoningStep(:final message):
          reasoningCount++;
          thinkingMs += message.reasoningUpdatedAt
              .difference(message.reasoningStartedAt)
              .inMilliseconds;
        case ToolCallStep():
          toolCount++;
        case ContextCompactionStep():
          compactionCount++;
      }
    }
    return <String>[
      if (toolCount > 0)
        toolCount == 1 ? 'Used 1 tool' : 'Used $toolCount tools',
      if (reasoningCount > 0)
        'Thought ${(thinkingMs / 1000).toStringAsFixed(1)} seconds',
      if (compactionCount > 0)
        compactionCount == 1
            ? 'Compacted once'
            : 'Compacted $compactionCount times',
    ].join(' · ');
  }

  /// 组进行中折叠头文案：当前（最后一个）步骤。
  static String currentLabel(AssistantStep last) => switch (last) {
    ReasoningStep() => 'Thinking',
    ToolCallStep step => toolLabel(step.arguments),
    ContextCompactionStep step => compactionLabel(step),
  };

  /// 组进行中折叠头文案 + 截至此刻的汇总：`运行测试 · Used 2 tools · Thought 3.2 seconds`。
  ///
  /// 汇总与结束态共用 [summaryLabel]，差别只在**正在跑的那一步算不算**——判据是
  /// 它的贡献是否已经定下来：
  ///
  /// - 工具是**计数**：开始即确定，而且一个工具返回时数字不能跳，所以照旧含它自己；
  /// - 推理的耗时、压缩的次数还在长：先不计，等它结束、下一步开始时才出现。
  ///
  /// 三种当前步都接后缀，`Thinking` / 压缩状态说的是"此刻在做什么"，后缀说的是
  /// "这个 run 已经用了多少"，两件事本就该同时可见；不接的话它们就成了唯一看不到
  /// 进度的两个状态。`Thinking` 后面**不会**再跟一个实时增长的 `Thought X seconds`
  /// ——正在跑的这段推理不计入自己的耗时，同一件事不说两遍。
  ///
  /// 只有**组头**经过这里（子项走 [_faceOf]），展开后每行不会把同一份用量重复
  /// 一遍——同一个工具的描述已经上下各出现一次，用量再重复一遍只会让列表变吵。
  static String runningLabel(List<AssistantStep> steps) {
    final current = currentLabel(steps.last);
    final settled = switch (steps.last) {
      ToolCallStep() => steps,
      ReasoningStep() => steps.sublist(0, steps.length - 1),
      ContextCompactionStep(:final running) =>
        running ? steps.sublist(0, steps.length - 1) : steps,
    };
    final summary = summaryLabel(settled);
    return summary.isEmpty ? current : '$current · $summary';
  }

  @override
  State<StepCard> createState() => _StepCardState();
}

/// 卡片头部与可展开正文的表现描述。
typedef _Face = ({IconData icon, String label, bool running, Widget body});

class _StepCardState extends State<StepCard> {
  bool _expanded = false;

  List<AssistantStep> get steps => widget.steps;

  bool get _single => steps.length == 1;

  @override
  void didUpdateWidget(StepCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 单步长成多步：形态从"展开看正文"变成"展开看列表"，重置为默认折叠。
    if (oldWidget.steps.length == 1 && widget.steps.length > 1) {
      _expanded = false;
    }
  }

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final face = _single ? _faceOf(steps.single) : _groupFace();
    final body = face.body;
    // 上边距是卡片对外的边距：顶层卡自带，嵌套子卡由组正文的 spacing 统一给，
    // 否则组头到首行会叠成 8 + 8。
    return Padding(
      padding: EdgeInsets.only(top: widget.nested ? 0 : 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          StepHeader(
            icon: face.icon,
            label: face.label,
            running: face.running && !widget.nested,
            expanded: _expanded,
            onTap: _toggle,
          ),
          if (_expanded) body,
        ],
      ),
    );
  }

  // ─── 单步 ────────────────────────────────────────────

  _Face _faceOf(AssistantStep step) => switch (step) {
    ReasoningStep(:final message) => (
      icon: LucideIcons.sparkles,
      label: widget.live ? 'Thinking' : StepCard.thoughtLabel(message),
      running: widget.live,
      body: _ReasoningBody(message: message, onTap: _toggle),
    ),
    ToolCallStep tool => (
      icon: StepCard.toolIcon(tool.toolName),
      label: StepCard.toolLabel(tool.arguments),
      running: !tool.hasResult,
      // 结果未返回时正文只有一句占位：参数不铺进消息列表（它可能又长又敏感），
      // 展开只是确认"它已经在跑了"。结果到了换成结果本身，展开态保持不变。
      body: _resultBody(tool.result ?? StepCard.usingToolLabel),
    ),
    ContextCompactionStep compaction => (
      icon: LucideIcons.fileArchive,
      label: StepCard.compactionLabel(compaction),
      running: compaction.running,
      // 压缩中也能展开：此刻的详情是"覆盖多少条消息、多少 tokens"
      body: _resultBody(_compactionDetails(compaction)),
    ),
  };

  Widget _resultBody(String text) => StepResultBody(text: text, onTap: _toggle);

  /// 压缩详情：失败时以 `Error:` 前缀标红。
  static String _compactionDetails(ContextCompactionStep compaction) {
    final details = compactionDetails(compaction.step);
    return compaction.step.phase == CompactionPhase.failed
        ? 'Error: $details'
        : details;
  }

  // ─── 多步 ────────────────────────────────────────────

  _Face _groupFace() {
    final last = steps.last;
    final hasTool = steps.any((step) => step is ToolCallStep);
    // 序列进行中，或仍有工具 / 压缩未返回时显示 shimmer。
    final running =
        widget.live ||
        steps.any(
          (step) => switch (step) {
            ToolCallStep tool => !tool.hasResult,
            ContextCompactionStep compaction => compaction.running,
            ReasoningStep() => false,
          },
        );
    // 结束态的汇总使用通用图标；进行中与当前单步使用同一图标。
    final genericIcon = hasTool ? LucideIcons.wrench : LucideIcons.sparkles;
    return (
      icon: widget.live ? _faceOf(last).icon : genericIcon,
      label: widget.live
          ? StepCard.runningLabel(steps)
          : StepCard.summaryLabel(steps),
      running: running,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          for (final (index, step) in steps.indexed)
            StepCard(
              key: _childKey(step),
              steps: [step],
              live: widget.live && index == steps.length - 1,
              nested: true,
            ),
        ],
      ),
    );
  }

  static Key _childKey(AssistantStep step) => ValueKey(switch (step) {
    ReasoningStep(:final message) =>
      'reasoning-${message.id ?? identityHashCode(message)}',
    ToolCallStep tool => 'tool-${tool.id}',
    ContextCompactionStep compaction =>
      'compaction-${compaction.step.compactionId}',
  });
}

/// 推理正文：与消息正文同档（跟随 Text size）、点击整块收起。
class _ReasoningBody extends StatelessWidget {
  final MessageEntity message;
  final VoidCallback onTap;

  const _ReasoningBody({required this.message, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: double.infinity,
        child: Text(
          message.reasoningContent,
          style: AthenaWorkspaceTextSize.of(
            context,
          ).prose.copyWith(color: colors.textSecondary),
        ),
      ),
    );
  }
}
