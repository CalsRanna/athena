import 'package:athena_core/agent/elicit/elicit_prompt.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/view_model/delegate/agent_stream_delegate.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// 会话内提问卡片（非模态）：渲染在所属对话的消息列表中。
///
/// 容器与按钮体系对齐 [PermissionApprovalCard]，区别在于「要不要做」是二值
/// 决策，而这里是「你要哪个」——每个问题给 2-4 个选项，并额外提供一个
/// 自由输入项（用户自填的文本就是答案本身，不是 "Other" 这个词）。
///
/// 一次只展示一个问题（多问时问题前标 `1 / 3`），单选点选即前进、
/// 最后一步点选即提交；多选与自由输入由 Next / Submit 收尾。
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

  /// 当前展示的问题下标：一次只展示一个问题。多问时按步骤推进，
  /// 卡片不会因为问题多而撑高，用户也不会漏看后面的问题。
  int _step = 0;

  /// 问题下标 → 自由输入控制器（内容非空即视为选择「其它」）。
  final Map<int, TextEditingController> _other = {};

  /// 问题下标 → 自由输入焦点：点圈体即开始自填，需要把焦点交过去。
  final Map<int, FocusNode> _focus = {};

  /// 正文滚动控制器。必须显式持有并同时交给 Scrollbar 与 ScrollView：
  /// 不传 controller 时 Scrollbar 会去用 PrimaryScrollController，
  /// 而卡片自身的可滚动区没有绑定它，滚动动画期间会断言失败。
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    for (final controller in _other.values) {
      controller.dispose();
    }
    for (final node in _focus.values) {
      node.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  List<ElicitQuestion> get _questions => widget.request.questions;

  TextEditingController _controllerFor(int index) =>
      _other.putIfAbsent(index, TextEditingController.new);

  FocusNode _focusFor(int index) => _focus.putIfAbsent(index, FocusNode.new);

  /// 当前问题的答案：自由输入优先，其次选项。
  String? _answerFor(int index) {
    final other = _other[index]?.text.trim() ?? '';
    if (other.isNotEmpty) return other;
    final selected = _selected[index];
    if (selected == null || selected.isEmpty) return null;
    return selected.join(', ');
  }

  bool get _hasMultiple => _questions.length > 1;

  bool get _isLastStep => _step >= _questions.length - 1;

  /// 当前问题是否已有答案：Next / Submit 的可用条件。
  bool get _canConfirm => _answerFor(_step) != null;

  /// 确认当前问题：不是最后一步就进入下一步，是最后一步就整卡提交。
  void _confirm() {
    if (!_canConfirm) return;
    if (_isLastStep) {
      _submit();
    } else {
      setState(() => _step++);
    }
  }

  void _toggle(int index, String label, {required bool multiSelect}) {
    final controller = _controllerFor(index);
    setState(() {
      final selected = _selected.putIfAbsent(index, () => <String>{});
      if (multiSelect) {
        if (!selected.remove(label)) selected.add(label);
      } else {
        // 单选再点一次是「保持」而不是「取消」：每题都得有答案才能往下走，
        // 允许点空会让用户卡在一个交不出去的步骤上。
        selected
          ..clear()
          ..add(label);
      }
      // 选项与自由输入互斥，避免答案歧义
      if (selected.isNotEmpty && controller.text.isNotEmpty) {
        controller.clear();
      }
    });
    // 单选点选即确认：不用再按按钮。多选还要继续勾，交给按钮收尾；
    // 自由输入需要先打字，同样交给按钮或回车。
    if (!multiSelect) _confirm();
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

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: colors.surfaceMobile,
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(AthenaRadius.container),
        ),
        padding: EdgeInsets.all(16),
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
                    children: [_buildQuestion(colors, _step)],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildActions(mobile),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AthenaColors colors) => Row(
    children: [
      Text(
        'Question',
        style: AthenaTextStyle.label.copyWith(
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
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
              if (_hasMultiple) ...[
                _buildStepIndicator(colors),
                const SizedBox(width: 8),
              ],
              if (question.header.isNotEmpty) ...[
                _buildHeaderChip(colors, question.header),
                const SizedBox(width: 8),
              ],
              if (question.multiSelect)
                Text(
                  'select all that apply',
                  style: AthenaTextStyle.caption.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            question.question,
            style: AthenaTextStyle.body.copyWith(
              fontWeight: FontWeight.w500,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          for (final option in question.options)
            _buildOptionRow(colors, index, option, question.multiSelect),
          _buildOtherRow(colors, index),
        ],
      ),
    );
  }

  /// 步骤展示（只有多问时才需要）：问题前的 `1 / 3`。
  Widget _buildStepIndicator(AthenaColors colors) => Text(
    '${_step + 1} / ${_questions.length}',
    style: AthenaTextStyle.label.copyWith(color: colors.textSecondary),
  );

  Widget _buildHeaderChip(AthenaColors colors, String header) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: ShapeDecoration(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AthenaRadius.control),
        side: BorderSide(color: colors.border),
      ),
    ),
    child: Text(
      header,
      style: AthenaTextStyle.label.copyWith(color: colors.textPrimary),
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
                      style: AthenaTextStyle.body.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    if (option.description.isNotEmpty)
                      Text(
                        option.description,
                        style: AthenaTextStyle.caption.copyWith(
                          color: colors.textSecondary,
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

  /// 自由输入行：用户自填的文本就是答案。
  ///
  /// 样式沿用全局输入约定（`AthenaInput` / 会话输入框：`inputBackground`
  /// 半透明填充 + 24 圆角 + collapsed 装饰），只有文字色与尺度不同——卡片本身
  /// 是 raised 白底，文字得用白卡家族的 `textOnRaised`；尺度取**卡片尺度**
  /// （字号 14、垂直内边距 12，与卡片内按钮同高）而不是全局输入的 56px 高，
  /// 否则一行自由输入会比整张卡片的其它内容都重。
  Widget _buildOtherRow(AthenaColors colors, int index) {
    final controller = _controllerFor(index);
    final focusNode = _focusFor(index);
    final multiSelect = _questions[index].multiSelect;
    final active = controller.text.trim().isNotEmpty;
    return Row(
      // 输入框会随内容长到多行，圈体对齐首行而不是整块居中
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() {
            // 点圈体即开始自填：清空选项，聚焦输入
            _selected[index]?.clear();
            focusNode.requestFocus();
          }),
          child: _buildMarker(
            colors,
            active,
            multiSelect,
            placeholderIcon: LucideIcons.pencilLine,
            // 12 的内边距 + 首行行盒的一半，与输入文字基线对齐
            margin: const EdgeInsets.only(top: 12),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            key: ValueKey('elicit-other-$index'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colors.inputBackground,
              border: Border.all(color: colors.border),
              borderRadius: BorderRadius.circular(AthenaRadius.control),
            ),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              cursorHeight: 15,
              cursorColor: colors.textPrimary,
              // 答案常常是一句话：1-3 行自增高，回车仍是提交而不是换行
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.done,
              // 自填文本需要收尾动作，回车与确认按钮等价
              onSubmitted: (_) => _confirm(),
              onChanged: (value) => setState(() {
                // 自填与选项互斥：一旦有文本就不再保留已选选项，
                // 否则圈体亮着但答案不是它
                if (value.trim().isNotEmpty) _selected[index]?.clear();
              }),
              style: AthenaTextStyle.body.copyWith(
                height: 1.2,
                color: colors.textPrimary,
              ),
              decoration: InputDecoration.collapsed(
                hintText: 'Or type your own answer',
                hintStyle: AthenaTextStyle.body.copyWith(
                  color: colors.textSecondary,
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
    EdgeInsets margin = const EdgeInsets.only(top: 1),
  }) {
    final side = BorderSide(
      color: selected ? colors.surfaceRaised : colors.border,
    );
    return Container(
      height: 16,
      width: 16,
      margin: margin,
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        shape: multiSelect
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AthenaRadius.inline),
                side: side,
              )
            : CircleBorder(side: side),
        color: selected ? colors.surfaceRaised : null,
      ),
      child: Icon(
        selected ? LucideIcons.check : (placeholderIcon ?? LucideIcons.check),
        size: 11,
        color: selected ? colors.textPrimary : colors.textSecondary,
      ),
    );
  }

  Widget _buildActions(bool mobile) {
    // 移动端按钮整行拉伸，文字要居中；桌面端按钮在行内按内容收缩，
    // 不能再套 Center（Center 会把按钮撑到整行宽）。
    final label = _isLastStep ? 'Submit' : 'Next';
    final primary = AthenaPrimaryButton(
      onTap: _canConfirm ? _confirm : null,
      child: mobile ? Center(child: Text(label)) : Text(label),
    );
    // 多问时给一个回到上一步的出口：单选点选会自动前进，
    // 没有退路的话手滑就无法改答案。
    final back = _step > 0
        ? AthenaSecondaryButton(
            onTap: () => setState(() => _step--),
            child: mobile
                ? const Center(child: Text('Back'))
                : const Text('Back'),
          )
        : null;
    if (mobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          primary,
          if (back != null) ...[const SizedBox(height: 8), back],
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (back != null) ...[back, const SizedBox(width: 12)],
        primary,
      ],
    );
  }
}
