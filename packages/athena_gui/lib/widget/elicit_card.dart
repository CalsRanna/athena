import 'package:athena_core/agent/elicit/elicit_prompt.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/view_model/delegate/agent_stream_delegate.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 会话内提问卡片（非模态）：渲染在所属对话的消息列表中。
///
/// 容器与按钮体系对齐 [PermissionApprovalCard]，区别在于「要不要做」是二值
/// 决策，而这里是「你要哪个」——每个问题给 2-4 个选项，并额外提供一个
/// 自由输入项（用户自填的文本就是答案本身，不是 "Other" 这个词）。
///
/// 多选问题的自由输入与选项互斥：二选一才能保证回传给模型的答案无歧义。
class ElicitCard extends StatefulWidget {
  final ElicitRequest request;
  final double maxHeight;

  /// 提交回调：问题文本 → 所选 label（多选按 ", " 连接）或自填文本。
  final void Function(Map<String, String> answers) onSubmit;

  const ElicitCard({
    super.key,
    required this.request,
    required this.maxHeight,
    required this.onSubmit,
  });

  @override
  State<ElicitCard> createState() => _ElicitCardState();
}

class _ElicitCardState extends State<ElicitCard> {
  /// 问题下标 → 已选 label 集合（单选恒为 0 或 1 个）。
  final Map<int, Set<String>> _selected = {};

  /// 问题下标 → 自由输入控制器（内容非空即视为选择「其它」）。
  final Map<int, TextEditingController> _other = {};

  /// 正文滚动控制器。必须显式持有并同时交给 Scrollbar 与 ScrollView：
  /// 不传 controller 时 Scrollbar 会去用 PrimaryScrollController，
  /// 而卡片自身的可滚动区没有绑定它，滚动动画期间会断言失败。
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    for (final controller in _other.values) {
      controller.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  List<ElicitQuestion> get _questions => widget.request.questions;

  TextEditingController _controllerFor(int index) =>
      _other.putIfAbsent(index, TextEditingController.new);

  /// 当前问题的答案：自由输入优先，其次选项。
  String? _answerFor(int index) {
    final other = _other[index]?.text.trim() ?? '';
    if (other.isNotEmpty) return other;
    final selected = _selected[index];
    if (selected == null || selected.isEmpty) return null;
    return selected.join(', ');
  }

  bool get _canSubmit =>
      _questions.asMap().keys.every((i) => _answerFor(i) != null);

  void _toggle(int index, String label, {required bool multiSelect}) {
    final controller = _controllerFor(index);
    setState(() {
      final selected = _selected.putIfAbsent(index, () => <String>{});
      if (multiSelect) {
        if (!selected.remove(label)) selected.add(label);
      } else {
        final wasSelected = selected.contains(label);
        selected
          ..clear()
          ..addAll(wasSelected ? const <String>[] : [label]);
      }
      // 选项与自由输入互斥，避免答案歧义
      if (selected.isNotEmpty && controller.text.isNotEmpty) {
        controller.clear();
      }
    });
  }

  void _submit() {
    final answers = <String, String>{};
    for (var i = 0; i < _questions.length; i++) {
      final answer = _answerFor(i);
      if (answer != null) answers[_questions[i].question] = answer;
    }
    widget.onSubmit(answers);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final platform = Theme.of(context).platform;
    final mobile =
        platform == TargetPlatform.android || platform == TargetPlatform.iOS;
    final rightPadding = mobile ? 40.0 : 64.0;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: colors.surfaceRaised.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(24),
        ),
        padding: EdgeInsets.fromLTRB(12, 12, rightPadding, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAvatar(colors),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(colors),
                  const SizedBox(height: 8),
                  Flexible(
                    child: Scrollbar(
                      controller: _scrollController,
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        primary: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = 0; i < _questions.length; i++)
                              _buildQuestion(colors, i),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildActions(mobile),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(AthenaColors colors) => Container(
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: colors.avatarBackground,
    ),
    height: 36,
    width: 36,
    child: Icon(Icons.help_outline, color: colors.textPrimary, size: 20),
  );

  Widget _buildHeader(AthenaColors colors) => Row(
    children: [
      Text(
        widget.request.questions.length > 1
            ? '${widget.request.questions.length} questions'
            : 'Question',
        style: GoogleFonts.firaCode(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: colors.textOnRaised,
        ),
      ),
    ],
  );

  Widget _buildQuestion(AthenaColors colors, int index) {
    final question = _questions[index];
    return Padding(
      padding: EdgeInsets.only(top: index == 0 ? 0 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (question.header.isNotEmpty) ...[
                _buildHeaderChip(colors, question.header),
                const SizedBox(width: 8),
              ],
              if (question.multiSelect)
                Text(
                  'select all that apply',
                  style: TextStyle(fontSize: 11, color: colors.textOnRaised),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            question.question,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: colors.textOnRaised,
            ),
          ),
          const SizedBox(height: 8),
          for (final option in question.options)
            _buildOptionRow(colors, index, option, question.multiSelect),
          _buildOtherRow(colors, index, question.multiSelect),
        ],
      ),
    );
  }

  Widget _buildHeaderChip(AthenaColors colors, String header) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: ShapeDecoration(
      shape: StadiumBorder(side: BorderSide(color: colors.border)),
    ),
    child: Text(
      header,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: colors.textOnRaised,
      ),
    ),
  );

  Widget _buildOptionRow(
    AthenaColors colors,
    int index,
    ElicitOption option,
    bool multiSelect,
  ) {
    final selected = _selected[index]?.contains(option.label) ?? false;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _toggle(index, option.label, multiSelect: multiSelect),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMarker(colors, selected, multiSelect),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textOnRaised,
                      ),
                    ),
                    if (option.description.isNotEmpty)
                      Text(
                        option.description,
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textOnRaised.withValues(alpha: 0.7),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 自由输入行：用户自填的文本就是答案
  Widget _buildOtherRow(AthenaColors colors, int index, bool multiSelect) {
    final controller = _controllerFor(index);
    final active = controller.text.trim().isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() {
            // 点圈体即开始自填：清空选项，聚焦输入
            _selected[index]?.clear();
          }),
          child: _buildMarker(
            colors,
            active,
            multiSelect,
            placeholderIcon: Icons.edit_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: ShapeDecoration(
              shape: RoundedRectangleBorder(
                side: BorderSide(color: colors.border),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: TextField(
              controller: controller,
              onChanged: (_) => setState(() {}),
              style: TextStyle(fontSize: 13, color: colors.textOnRaised),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Or type your own answer',
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: colors.textOnRaised.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMarker(
    AthenaColors colors,
    bool selected,
    bool multiSelect, {
    IconData? placeholderIcon,
  }) {
    final side = BorderSide(
      color: selected ? colors.cardPrimaryBackground : colors.border,
    );
    return Container(
      height: 16,
      width: 16,
      margin: const EdgeInsets.only(top: 1),
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        shape: multiSelect
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: side,
              )
            : CircleBorder(side: side),
        color: selected ? colors.cardPrimaryBackground : null,
      ),
      child: Icon(
        selected ? Icons.check : (placeholderIcon ?? Icons.check),
        size: 11,
        color: selected
            ? colors.cardPrimaryText
            : colors.textOnRaised.withValues(alpha: 0.4),
      ),
    );
  }

  Widget _buildActions(bool mobile) {
    final button = _CardPrimaryButton(
      label: 'Submit',
      onTap: _canSubmit ? _submit : null,
    );
    if (mobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [button],
      );
    }
    return Row(mainAxisAlignment: MainAxisAlignment.end, children: [button]);
  }
}

/// 浅色卡片上的主按钮：深色实心胶囊 + 白字；[onTap] 为 null 时置灰禁用。
class _CardPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _CardPrimaryButton({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final enabled = onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: Container(
          decoration: ShapeDecoration(
            color: colors.cardPrimaryBackground.withValues(
              alpha: enabled ? 1 : 0.4,
            ),
            shape: const StadiumBorder(),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: colors.cardPrimaryText,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
