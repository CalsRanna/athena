import 'package:athena_core/agent/elicit/elicit_prompt.dart';
import 'package:athena_tui/ui/text_util.dart';
import 'package:athena_tui/ui/theme.dart';
import 'package:nocterm/nocterm.dart';

/// 提问条:输入区上方的模态提示(向用户提问)。
///
/// 与 [PermissionBar] 同构——审批问的是「要不要做」(y/n/a),这里问的是
/// 「你要哪个」:数字键选选项、上下键切问题、[e] 转输入区自填。
/// 显示期间 app 层接管全局按键,输入区只在自填模式下接收输入。
class QuestionBar extends StatelessComponent {
  const QuestionBar({
    super.key,
    required this.questions,
    required this.currentIndex,
    required this.selected,
    required this.freeText,
    required this.hint,
    this.scrollController,
  });

  final List<ElicitQuestion> questions;
  final int currentIndex;

  /// 问题下标 → 已选 label 集合。
  final Map<int, Set<String>> selected;

  /// 问题下标 → 用户自填的文本(与选项互斥)。
  final Map<int, String> freeText;

  final String hint;
  final ScrollController? scrollController;

  @override
  Component build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 1),
      padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 0),
      decoration: BoxDecoration(
        border: BoxBorder.all(color: AthenaColors.warning),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            questions.length > 1 ? '提问（${questions.length} 个）' : '提问',
            style: const TextStyle(
              color: AthenaColors.warning,
              fontWeight: FontWeight.bold,
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              controller: scrollController,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < questions.length; i++)
                    ..._buildQuestion(i),
                ],
              ),
            ),
          ),
          Text(hint, style: AthenaTextStyles.dim),
        ],
      ),
    );
  }

  /// 一个问题:标题行 + 各选项 + 自填行。
  ///
  /// 问句与选项都来自模型,渲染前一律 [sanitizeAnsi] 清洗——
  /// 终端转义序列可由模型输出携带,不清洗等于把终端交给模型。
  List<Component> _buildQuestion(int index) {
    final question = questions[index];
    final isCurrent = index == currentIndex;
    final chosen = selected[index] ?? const <String>{};
    final custom = freeText[index]?.trim() ?? '';

    return [
      Text(
        '${isCurrent ? '▶' : ' '} ${sanitizeAnsi(question.header)}'
        '${question.multiSelect ? '（多选）' : ''}  '
        '${sanitizeAnsi(question.question)}',
        softWrap: true,
        style: isCurrent
            ? const TextStyle(fontWeight: FontWeight.bold)
            : AthenaTextStyles.dim,
      ),
      for (var j = 0; j < question.options.length; j++)
        Text(
          '    ${j + 1}) ${sanitizeAnsi(question.options[j].label)}'
          '${chosen.contains(question.options[j].label) ? ' ✔' : ''}'
          '  ${sanitizeAnsi(question.options[j].description)}',
          softWrap: true,
          style: chosen.contains(question.options[j].label)
              ? AthenaTextStyles.teal
              : null,
        ),
      if (custom.isNotEmpty)
        Text(
          '    自填：${sanitizeAnsi(custom)} ✔',
          softWrap: true,
          style: AthenaTextStyles.teal,
        ),
    ];
  }
}
