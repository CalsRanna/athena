import 'package:athena_gui/util/color_util.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// 错误色（对齐 AthenaMessageType.error）。
const _accentError = Color(0xFFE38B8B);

/// 权限审批内容组件：标题行 + 请求内容 + 三个操作按钮。
///
/// 宿主无关（模态弹窗 / 会话内卡片均可复用），决策通过 [onDecision]
/// 回调返回：
/// - Allow Once：仅放行本次
/// - Always Allow：放行并持久化规则
/// - Deny：拒绝
class PermissionDialogContent extends StatelessWidget {
  final String toolName;
  final String description;
  final String? warning;

  /// 是否移动端布局（全宽胶囊按钮，主操作在最上）。
  final bool mobile;
  final void Function(bool approved, bool persistExact) onDecision;

  const PermissionDialogContent({
    super.key,
    required this.toolName,
    required this.description,
    required this.onDecision,
    this.warning,
    this.mobile = false,
  });

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      _buildHeader(),
      const SizedBox(height: 16),
      _buildCodeBlock(),
    ];

    if (warning != null) {
      children.add(const SizedBox(height: 12));
      children.add(_buildWarning(warning!));
    }

    children.add(const SizedBox(height: 24));
    children.add(_buildButtons(context));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget _buildHeader() {
    // 标题样式对齐其他对话框（如 Edit Sentinel）：纯文字、普通字体、20px w500
    const titleTextStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      fontSize: 20,
      fontWeight: FontWeight.w500,
    );
    return Row(
      children: [
        Text('Tool Approval', style: titleTextStyle),
        const Spacer(),
        // 工具名 chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: ColorUtil.FF616161,
            borderRadius: BorderRadius.circular(44),
          ),
          child: Text(
            toolName,
            style: const TextStyle(
              fontSize: 12,
              color: ColorUtil.FFFFFFFF,
            ),
          ),
        ),
      ],
    );
  }

  /// 请求内容（shell 为完整命令，其他为参数键值）。
  Widget _buildCodeBlock() {
    // 正文样式对齐其他对话框的 messageStyle（普通字体、14、白 0.8）
    const contentStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.6,
    );
    return SingleChildScrollView(
      child: Text(description, style: contentStyle),
    );
  }

  Widget _buildWarning(String warning) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          HugeIcons.strokeRoundedAlert02,
          size: 16,
          color: _accentError,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            warning,
            style: const TextStyle(
              fontSize: 13,
              color: _accentError,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildButtons(BuildContext context) {
    if (!mobile) {
      // 桌面：行内按钮，主操作（Allow Once）在最右
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          AthenaSecondaryButton(
            onTap: () => onDecision(false, false),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Deny'),
            ),
          ),
          const SizedBox(width: 12),
          AthenaSecondaryButton(
            onTap: () => onDecision(true, true),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Always Allow'),
            ),
          ),
          const SizedBox(width: 12),
          AthenaPrimaryButton(
            onTap: () => onDecision(true, false),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Allow Once'),
            ),
          ),
        ],
      );
    }

    // 移动：全宽胶囊按钮，主操作在最上
    return Column(
      children: [
        _buildMobileButton(
          label: 'Allow Once',
          onTap: () => onDecision(true, false),
          background: ColorUtil.FFFFFFFF,
          foreground: ColorUtil.FF161616,
          bordered: false,
        ),
        const SizedBox(height: 12),
        _buildMobileButton(
          label: 'Always Allow',
          onTap: () => onDecision(true, true),
          background: Colors.transparent,
          foreground: ColorUtil.FFFFFFFF,
          bordered: true,
        ),
        const SizedBox(height: 12),
        _buildMobileButton(
          label: 'Deny',
          onTap: () => onDecision(false, false),
          background: ColorUtil.FF616161,
          foreground: ColorUtil.FFFFFFFF,
          bordered: false,
        ),
        SizedBox(height: MediaQuery.paddingOf(context).bottom),
      ],
    );
  }

  Widget _buildMobileButton({
    required String label,
    required VoidCallback onTap,
    required Color background,
    required Color foreground,
    required bool bordered,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          shape: StadiumBorder(
            side: bordered
                ? const BorderSide(color: ColorUtil.FFC2C2C2)
                : BorderSide.none,
          ),
          color: background,
        ),
        padding: const EdgeInsets.all(16),
        child: Text(
          label,
          style: TextStyle(
            color: foreground,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
