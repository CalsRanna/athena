import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

class ATile extends StatefulWidget {
  final double? height;
  final Widget? leading;
  final void Function()? onTap;
  final String title;
  final Widget? trailing;
  final double? width;
  const ATile({
    super.key,
    this.height,
    this.leading,
    this.onTap,
    required this.title,
    this.trailing,
    this.width,
  });

  @override
  State<ATile> createState() => _ATileState();
}

class _ATileState extends State<ATile> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final surfaceContainer = colorScheme.surfaceContainer;
    final onSurface = colorScheme.onSurface;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: handleEnter,
        onExit: handleExit,
        child: Container(
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: hover ? surfaceContainer : null,
          ),
          height: widget.height,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          width: widget.width,
          child: Row(
            children: [
              if (widget.leading != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: widget.leading,
                ),
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    color: onSurface,
                    decoration: TextDecoration.none,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              if (widget.trailing != null && hover)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: widget.trailing,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void handleEnter(PointerEnterEvent event) {
    setState(() {
      hover = true;
    });
  }

  void handleExit(PointerExitEvent event) {
    setState(() {
      hover = false;
    });
  }
}

class MobileSettingTile extends StatelessWidget {
  final Widget? leading;
  final void Function()? onTap;
  final String? subtitle;
  final String title;
  final String? trailing;
  const MobileSettingTile({
    super.key,
    this.leading,
    this.onTap,
    this.subtitle,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    const titleTextStyle = TextStyle(
      fontSize: 16,
      color: Color(0xFFFFFFFF),
      fontWeight: FontWeight.w500,
      height: 1.5,
    );
    const subtitleTextStyle = TextStyle(
      fontSize: 12,
      color: Color(0xFFE0E0E0),
      fontWeight: FontWeight.w400,
      height: 1.5,
    );
    var titleChildren = [
      Text(title, style: titleTextStyle),
      if (subtitle != null) Text(subtitle!, style: subtitleTextStyle)
    ];
    var titleColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: titleChildren,
    );
    final trailingText = Text(
      trailing ?? '',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: subtitleTextStyle,
      textAlign: TextAlign.end,
    );
    var tileChildren = [
      leading ?? const SizedBox(),
      if (leading != null) const SizedBox(width: 12),
      Expanded(child: titleColumn),
      trailingText,
      Icon(HugeIcons.strokeRoundedArrowRight01),
    ];
    var tileRow = IconTheme(
      data: const IconThemeData(color: Color(0xFFE0E0E0), size: 16),
      child: Row(children: tileChildren),
    );
    return ListTile(title: tileRow, onTap: onTap);
  }
}
