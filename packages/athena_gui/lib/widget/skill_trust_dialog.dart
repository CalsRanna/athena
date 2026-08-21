import 'package:athena_gui/router/router.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_core/util/platform_util.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';

/// 提示用户是否信任当前项目目录的项目级 Skill。
///
/// 返回 `true` 表示用户选择信任；返回 `false` 表示拒绝/跳过/被关闭（含 null）。
/// 镜像 `permission_dialog.dart` 的桌面/移动端拆分与样式，且不可被点击空白关闭。
Future<bool> showSkillTrustDialog({
  required String projectDir,
  required List<String> skillNames,
}) async {
  final context = router.navigatorKey.currentContext!;
  if (PlatformUtil.isDesktop) {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DesktopSkillTrustDialog(
        projectDir: projectDir,
        skillNames: skillNames,
      ),
    );
    return result ?? false;
  } else {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Theme.of(
        context,
      ).extension<AthenaColors>()!.surfaceMobile,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => _MobileSkillTrustDialog(
        projectDir: projectDir,
        skillNames: skillNames,
      ),
    );
    return result ?? false;
  }
}

Widget _buildTitleRow(BuildContext context) {
  final colors = Theme.of(context).extension<AthenaColors>()!;
  return Row(
    children: [
      Icon(
        HugeIcons.strokeRoundedAlert02,
        size: 20,
        color: const Color(0xFFE8B86D),
      ),
      SizedBox(width: 8),
      Text(
        'Trust project skills?',
        style: GoogleFonts.firaCode(
          fontSize: 16,
          color: colors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
}

Widget _buildBody(
  BuildContext context,
  String projectDir,
  List<String> skillNames,
) {
  final colors = Theme.of(context).extension<AthenaColors>()!;
  var descriptionText = Text(
    'The current working directory ships project skills. Trusting them will '
    'inject their instructions into the AI\'s system prompt. '
    'Only trust directories you control.',
    style: GoogleFonts.firaCode(
      fontSize: 13,
      color: colors.textPrimary,
      height: 1.6,
    ),
  );
  var dirText = Text(
    projectDir,
    style: GoogleFonts.firaCode(
      fontSize: 12,
      color: colors.border,
      height: 1.5,
    ),
  );
  var skillsLabel = Text(
    'Skills:',
    style: GoogleFonts.firaCode(
      fontSize: 13,
      color: colors.textPrimary,
      fontWeight: FontWeight.w500,
    ),
  );
  var skillsList = Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final name in skillNames)
        Text(
          '- $name',
          style: GoogleFonts.firaCode(
            fontSize: 12,
            color: colors.border,
            height: 1.5,
          ),
        ),
    ],
  );
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      descriptionText,
      const SizedBox(height: 12),
      dirText,
      const SizedBox(height: 12),
      skillsLabel,
      const SizedBox(height: 4),
      skillsList,
    ],
  );
}

class _DesktopSkillTrustDialog extends StatelessWidget {
  final String projectDir;
  final List<String> skillNames;

  const _DesktopSkillTrustDialog({
    required this.projectDir,
    required this.skillNames,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildTitleRow(context),
        const SizedBox(height: 16),
        _buildBody(context, projectDir, skillNames),
        const SizedBox(height: 24),
        _buildButtons(context),
      ],
    );
    var container = Container(
      constraints: BoxConstraints(minWidth: 360, maxWidth: 520),
      decoration: BoxDecoration(
        color: colors.surfaceMobile,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(24),
      child: column,
    );
    return Dialog(backgroundColor: Colors.transparent, child: container);
  }

  Widget _buildButtons(BuildContext context) {
    const edgeInsets = EdgeInsets.symmetric(horizontal: 16);
    var denyButton = AthenaSecondaryButton(
      onTap: () => Navigator.pop(context, false),
      child: Padding(padding: edgeInsets, child: const Text('Skip')),
    );
    var allowButton = AthenaPrimaryButton(
      onTap: () => Navigator.pop(context, true),
      child: Padding(padding: edgeInsets, child: const Text('Trust')),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [denyButton, const SizedBox(width: 12), allowButton],
    );
  }
}

class _MobileSkillTrustDialog extends StatelessWidget {
  final String projectDir;
  final List<String> skillNames;

  const _MobileSkillTrustDialog({
    required this.projectDir,
    required this.skillNames,
  });

  @override
  Widget build(BuildContext context) {
    var children = <Widget>[
      _buildTitleRow(context),
      const SizedBox(height: 16),
      _buildBody(context, projectDir, skillNames),
      const SizedBox(height: 24),
      _buildAllowButton(context),
      const SizedBox(height: 12),
      _buildDenyButton(context),
      SizedBox(height: MediaQuery.paddingOf(context).bottom),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  Widget _buildAllowButton(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var shapeDecoration = ShapeDecoration(
      shape: StadiumBorder(),
      color: colors.surfaceRaised,
      shadows: [
        BoxShadow(blurRadius: 16, color: colors.ctaGlow.withValues(alpha: 0.5)),
      ],
    );
    var textStyle = TextStyle(
      color: colors.textOnRaised,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.pop(context, true),
      child: Container(
        alignment: Alignment.center,
        decoration: shapeDecoration,
        padding: const EdgeInsets.all(16),
        child: Text('Trust', style: textStyle),
      ),
    );
  }

  Widget _buildDenyButton(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var shapeDecoration = ShapeDecoration(
      color: colors.surfaceButtonSecondary,
      shape: const StadiumBorder(),
    );
    var textStyle = TextStyle(
      color: colors.textPrimary,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.pop(context, false),
      child: Container(
        alignment: Alignment.center,
        decoration: shapeDecoration,
        padding: const EdgeInsets.all(16),
        child: Text('Skip', style: textStyle),
      ),
    );
  }
}
