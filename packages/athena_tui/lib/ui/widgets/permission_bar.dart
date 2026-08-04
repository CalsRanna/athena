import 'package:athena_tui/ui/theme.dart';
import 'package:nocterm/nocterm.dart';

/// 审批条:输入区上方的模态提示(权限请求 / Skill 信任)。
///
/// 显示期间全局按键被 app 层接管,输入区不接收输入。
class PermissionBar extends StatelessComponent {
  const PermissionBar({
    super.key,
    required this.title,
    required this.detail,
    required this.hint,
  });

  final String title;
  final String detail;
  final String hint;

  @override
  Component build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 0),
      decoration: BoxDecoration(
        border: BoxBorder.all(color: AthenaColors.warning),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(
            color: AthenaColors.warning,
            fontWeight: FontWeight.bold,
          )),
          Text(detail, softWrap: true),
          Text(hint, style: AthenaTextStyles.dim),
        ],
      ),
    );
  }
}
