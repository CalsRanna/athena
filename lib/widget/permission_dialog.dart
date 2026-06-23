import 'package:athena/router/router.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/util/platform_util.dart';
import 'package:athena/widget/button.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';

enum _RememberMode { none, exact, pattern }

class PermissionDialogResult {
  final bool approved;
  final bool persistExact;
  final String? persistPattern;

  const PermissionDialogResult({
    required this.approved,
    this.persistExact = false,
    this.persistPattern,
  });
}

Future<PermissionDialogResult> showPermissionDialog({
  required String toolName,
  required String description,
  required String keyArg,
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
        keyArg: keyArg,
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
        keyArg: keyArg,
        warning: warning,
      ),
    );
    return result ?? const PermissionDialogResult(approved: false);
  }
}

class _DesktopPermissionDialog extends StatefulWidget {
  final String toolName;
  final String description;
  final String keyArg;
  final String? warning;

  const _DesktopPermissionDialog({
    required this.toolName,
    required this.description,
    required this.keyArg,
    this.warning,
  });

  @override
  State<_DesktopPermissionDialog> createState() =>
      _DesktopPermissionDialogState();
}

class _DesktopPermissionDialogState extends State<_DesktopPermissionDialog> {
  var _rememberMode = _RememberMode.none;
  late final _patternController = TextEditingController(text: widget.keyArg);

  @override
  void dispose() {
    _patternController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      _buildHeader(),
      const SizedBox(height: 16),
      _buildDescription(),
    ];

    if (widget.warning != null) {
      children.add(const SizedBox(height: 12));
      children.add(_buildWarning(widget.warning!));
    }

    children.add(const SizedBox(height: 20));
    children.add(_buildRememberSection());
    children.add(const SizedBox(height: 24));
    children.add(_buildButtons());

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(minWidth: 400, maxWidth: 560),
        decoration: BoxDecoration(
          color: ColorUtil.FF282F32,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(
          HugeIcons.strokeRoundedAlert02,
          size: 20,
          color: Colors.orange.shade700,
        ),
        const SizedBox(width: 8),
        Text(
          widget.toolName,
          style: GoogleFonts.firaCode(
            fontSize: 16,
            color: ColorUtil.FFFFFFFF,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDescription() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      child: SingleChildScrollView(
        child: Text(
          widget.description,
          style: GoogleFonts.firaCode(
            fontSize: 13,
            color: ColorUtil.FFFFFFFF,
            height: 1.6,
          ),
        ),
      ),
    );
  }

  Widget _buildWarning(String warning) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          HugeIcons.strokeRoundedAlert02,
          size: 16,
          color: Colors.red.shade400,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            warning,
            style: GoogleFonts.firaCode(
              fontSize: 12,
              color: Colors.red.shade400,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRememberSection() {
    final baseStyle = TextStyle(color: ColorUtil.FFC2C2C2, fontSize: 13);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Remember:', style: baseStyle),
        const SizedBox(height: 8),
        RadioGroup<_RememberMode>(
          groupValue: _rememberMode,
          onChanged: (v) => setState(() => _rememberMode = v ?? _RememberMode.none),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _radioOption(_RememberMode.none),
              const SizedBox(height: 6),
              _radioOption(_RememberMode.exact),
              const SizedBox(height: 6),
              _radioOption(_RememberMode.pattern, trailing: _buildPatternInput()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _radioOption(_RememberMode mode, {Widget? trailing}) {
    final selected = _rememberMode == mode;
    final labelText = switch (mode) {
      _RememberMode.none => 'Don\'t remember',
      _RememberMode.exact => 'Exactly this call',
      _RememberMode.pattern => 'Pattern:',
    };

    return GestureDetector(
      onTap: () => setState(() => _rememberMode = mode),
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: Radio<_RememberMode>(
              value: mode,
              activeColor: Colors.orange.shade700,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            labelText,
            style: TextStyle(
              color: selected ? ColorUtil.FFFFFFFF : ColorUtil.FFC2C2C2,
              fontSize: 12,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 4),
            Expanded(child: trailing),
          ],
        ],
      ),
    );
  }

  Widget _buildPatternInput() {
    final enabled = _rememberMode == _RememberMode.pattern;
    return TextField(
      controller: _patternController,
      enabled: enabled,
      style: GoogleFonts.firaCode(
        fontSize: 12,
        color: enabled ? ColorUtil.FFFFFFFF : ColorUtil.FF616161,
      ),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(
            color: enabled ? ColorUtil.FFC2C2C2 : ColorUtil.FF616161,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: ColorUtil.FFC2C2C2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: ColorUtil.FF616161),
        ),
        filled: true,
        fillColor: enabled ? ColorUtil.FF161616 : ColorUtil.FF282828,
      ),
    );
  }

  Widget _buildButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        AthenaSecondaryButton(
          onTap: () => Navigator.pop(
            context,
            const PermissionDialogResult(approved: false),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Deny'),
          ),
        ),
        const SizedBox(width: 12),
        AthenaPrimaryButton(
          onTap: () {
            final pattern = _rememberMode == _RememberMode.pattern
                ? _patternController.text.trim()
                : null;
            Navigator.pop(
              context,
              PermissionDialogResult(
                approved: true,
                persistExact: _rememberMode == _RememberMode.exact,
                persistPattern: (pattern != null && pattern.isNotEmpty) ? pattern : null,
              ),
            );
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Allow'),
          ),
        ),
      ],
    );
  }
}

class _MobilePermissionDialog extends StatefulWidget {
  final String toolName;
  final String description;
  final String keyArg;
  final String? warning;

  const _MobilePermissionDialog({
    required this.toolName,
    required this.description,
    required this.keyArg,
    this.warning,
  });

  @override
  State<_MobilePermissionDialog> createState() =>
      _MobilePermissionDialogState();
}

class _MobilePermissionDialogState extends State<_MobilePermissionDialog> {
  var _rememberMode = _RememberMode.none;
  late final _patternController = TextEditingController(text: widget.keyArg);

  @override
  void dispose() {
    _patternController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      _buildHeader(),
      const SizedBox(height: 16),
      _buildDescription(),
    ];

    if (widget.warning != null) {
      children.add(const SizedBox(height: 12));
      children.add(_buildWarning(widget.warning!));
    }

    children.add(const SizedBox(height: 20));
    children.add(_buildRememberSection());
    children.add(const SizedBox(height: 24));
    children.add(_buildAllowButton());
    children.add(const SizedBox(height: 12));
    children.add(_buildDenyButton());
    children.add(SizedBox(height: MediaQuery.paddingOf(context).bottom));

    return Container(
      decoration: const BoxDecoration(
        color: ColorUtil.FF282F32,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(
          HugeIcons.strokeRoundedAlert02,
          size: 20,
          color: Colors.orange.shade700,
        ),
        const SizedBox(width: 8),
        Text(
          widget.toolName,
          style: GoogleFonts.firaCode(
            fontSize: 16,
            color: ColorUtil.FFFFFFFF,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDescription() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      child: SingleChildScrollView(
        child: Text(
          widget.description,
          style: GoogleFonts.firaCode(
            fontSize: 13,
            color: ColorUtil.FFFFFFFF,
            height: 1.6,
          ),
        ),
      ),
    );
  }

  Widget _buildWarning(String warning) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          HugeIcons.strokeRoundedAlert02,
          size: 16,
          color: Colors.red.shade400,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            warning,
            style: GoogleFonts.firaCode(
              fontSize: 12,
              color: Colors.red.shade400,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRememberSection() {
    final baseStyle = TextStyle(color: ColorUtil.FFC2C2C2, fontSize: 13);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Remember:', style: baseStyle),
        const SizedBox(height: 8),
        RadioGroup<_RememberMode>(
          groupValue: _rememberMode,
          onChanged: (v) => setState(() => _rememberMode = v ?? _RememberMode.none),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _radioOption(_RememberMode.none),
              const SizedBox(height: 6),
              _radioOption(_RememberMode.exact),
              const SizedBox(height: 6),
              _radioOption(_RememberMode.pattern, trailing: _buildPatternInput()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _radioOption(_RememberMode mode, {Widget? trailing}) {
    final selected = _rememberMode == mode;
    final labelText = switch (mode) {
      _RememberMode.none => 'Don\'t remember',
      _RememberMode.exact => 'Exactly this call',
      _RememberMode.pattern => 'Pattern:',
    };

    return GestureDetector(
      onTap: () => setState(() => _rememberMode = mode),
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: Radio<_RememberMode>(
              value: mode,
              activeColor: Colors.orange.shade700,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            labelText,
            style: TextStyle(
              color: selected ? ColorUtil.FFFFFFFF : ColorUtil.FFC2C2C2,
              fontSize: 12,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 4),
            Expanded(child: trailing),
          ],
        ],
      ),
    );
  }

  Widget _buildPatternInput() {
    final enabled = _rememberMode == _RememberMode.pattern;
    return TextField(
      controller: _patternController,
      enabled: enabled,
      style: GoogleFonts.firaCode(
        fontSize: 12,
        color: enabled ? ColorUtil.FFFFFFFF : ColorUtil.FF616161,
      ),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(
            color: enabled ? ColorUtil.FFC2C2C2 : ColorUtil.FF616161,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: ColorUtil.FFC2C2C2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: ColorUtil.FF616161),
        ),
        filled: true,
        fillColor: enabled ? ColorUtil.FF161616 : ColorUtil.FF282828,
      ),
    );
  }

  Widget _buildAllowButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        final pattern = _rememberMode == _RememberMode.pattern
            ? _patternController.text.trim()
            : null;
        Navigator.pop(
          context,
          PermissionDialogResult(
            approved: true,
            persistExact: _rememberMode == _RememberMode.exact,
            persistPattern: (pattern != null && pattern.isNotEmpty) ? pattern : null,
          ),
        );
      },
      child: Container(
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          shape: const StadiumBorder(),
          color: ColorUtil.FFFFFFFF,
          shadows: [
            BoxShadow(
              blurRadius: 16,
              color: ColorUtil.FFCED2C7.withValues(alpha: 0.5),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Text(
          'Allow',
          style: TextStyle(
            color: ColorUtil.FF161616,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildDenyButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.pop(
        context,
        const PermissionDialogResult(approved: false),
      ),
      child: Container(
        alignment: Alignment.center,
        decoration: const ShapeDecoration(
          color: ColorUtil.FF616161,
          shape: StadiumBorder(),
        ),
        padding: const EdgeInsets.all(16),
        child: Text(
          'Deny',
          style: TextStyle(
            color: ColorUtil.FFFFFFFF,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
