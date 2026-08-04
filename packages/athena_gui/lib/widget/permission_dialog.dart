import 'package:athena_gui/router/router.dart';
import 'package:athena_gui/util/color_util.dart';
import 'package:athena_core/util/platform_util.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// 错误色（对齐 AthenaMessageType.error）。
const _accentError = Color(0xFFE38B8B);

class PermissionDialogResult {
  final bool approved;

  /// Always Allow：持久化规则（shell 存动作级规则，其他存精确 keyArg）。
  final bool persistExact;

  const PermissionDialogResult({
    required this.approved,
    this.persistExact = false,
  });
}

Future<PermissionDialogResult> showPermissionDialog({
  required String toolName,
  required String description,
  String? warning,
}) async {
  final context = router.navigatorKey.currentContext!;
  if (PlatformUtil.isDesktop) {
    final result = await showDialog<PermissionDialogResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DesktopPermissionDialog(
        toolName: toolName,
        description: description,
        warning: warning,
      ),
    );
    return result ?? const PermissionDialogResult(approved: false);
  } else {
    final result = await showModalBottomSheet<PermissionDialogResult>(
      context: context,
      backgroundColor: ColorUtil.FF282F32,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => _MobilePermissionDialog(
        toolName: toolName,
        description: description,
        warning: warning,
      ),
    );
    return result ?? const PermissionDialogResult(approved: false);
  }
}

class _DesktopPermissionDialog extends StatelessWidget {
  final String toolName;
  final String description;
  final String? warning;

  const _DesktopPermissionDialog({
    required this.toolName,
    required this.description,
    this.warning,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(minWidth: 400, maxWidth: 560),
        decoration: BoxDecoration(
          color: ColorUtil.FF282F32,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(24),
        child: _PermissionDialogContent(
          toolName: toolName,
          description: description,
          warning: warning,
          mobile: false,
        ),
      ),
    );
  }
}

class _MobilePermissionDialog extends StatelessWidget {
  final String toolName;
  final String description;
  final String? warning;

  const _MobilePermissionDialog({
    required this.toolName,
    required this.description,
    this.warning,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: ColorUtil.FF282F32,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: _PermissionDialogContent(
          toolName: toolName,
          description: description,
          warning: warning,
          mobile: true,
        ),
      ),
    );
  }
}

/// 桌面/移动共享的对话框内容：标题行 + 请求内容 + 三个操作按钮。
///
/// 三个按钮即三种决策，无需额外步骤：
/// - Allow Once：仅放行本次
/// - Always Allow：放行并持久化规则
/// - Deny：拒绝
class _PermissionDialogContent extends StatelessWidget {
  final String toolName;
  final String description;
  final String? warning;
  final bool mobile;

  const _PermissionDialogContent({
    required this.toolName,
    required this.description,
    required this.warning,
    required this.mobile,
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

  void _allowOnce(BuildContext context) {
    Navigator.pop(
      context,
      const PermissionDialogResult(approved: true),
    );
  }

  void _alwaysAllow(BuildContext context) {
    Navigator.pop(
      context,
      const PermissionDialogResult(approved: true, persistExact: true),
    );
  }

  void _deny(BuildContext context) {
    Navigator.pop(
      context,
      const PermissionDialogResult(approved: false),
    );
  }

  Widget _buildButtons(BuildContext context) {
    if (!mobile) {
      // 桌面：行内按钮，主操作（Allow Once）在最右
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          AthenaSecondaryButton(
            onTap: () => _deny(context),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Deny'),
            ),
          ),
          const SizedBox(width: 12),
          AthenaSecondaryButton(
            onTap: () => _alwaysAllow(context),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Always Allow'),
            ),
          ),
          const SizedBox(width: 12),
          AthenaPrimaryButton(
            onTap: () => _allowOnce(context),
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
          onTap: () => _allowOnce(context),
          background: ColorUtil.FFFFFFFF,
          foreground: ColorUtil.FF161616,
          bordered: false,
        ),
        const SizedBox(height: 12),
        _buildMobileButton(
          label: 'Always Allow',
          onTap: () => _alwaysAllow(context),
          background: Colors.transparent,
          foreground: ColorUtil.FFFFFFFF,
          bordered: true,
        ),
        const SizedBox(height: 12),
        _buildMobileButton(
          label: 'Deny',
          onTap: () => _deny(context),
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
