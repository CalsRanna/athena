import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/view_model/sentinel_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

class _DesktopSentinelSelectDialogTile extends StatefulWidget {
  final SentinelEntity sentinel;
  final String? label;
  final void Function()? onTap;
  const _DesktopSentinelSelectDialogTile({
    required this.sentinel,
    this.label,
    this.onTap,
  });

  @override
  State<_DesktopSentinelSelectDialogTile> createState() =>
      _DesktopSentinelSelectDialogTileState();
}

class _DesktopSentinelSelectDialogTileState
    extends State<_DesktopSentinelSelectDialogTile> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var textStyle = AthenaTextStyle.row.copyWith(
      color: colors.textPrimary,
      decoration: TextDecoration.none,
    );
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      color: hover ? colors.surfaceButtonSecondary : null,
    );
    var container = AnimatedContainer(
      alignment: Alignment.centerLeft,
      decoration: boxDecoration,
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Text(widget.label ?? widget.sentinel.name, style: textStyle),
    );
    var mouseRegion = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: handleEnter,
      onExit: handleExit,
      child: container,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: mouseRegion,
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

class DesktopSentinelSelectDialog extends StatelessWidget {
  final void Function(SentinelEntity)? onTap;
  const DesktopSentinelSelectDialog({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final sentinelViewModel = GetIt.instance<SentinelViewModel>();
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var boxDecoration = BoxDecoration(
      color: colors.surfaceMobile,
      borderRadius: BorderRadius.circular(8),
    );

    return Watch((context) {
      var sentinels = sentinelViewModel.sentinels.value;
      var child = _buildData(sentinels);
      var container = Container(
        decoration: boxDecoration,
        padding: EdgeInsets.all(8),
        child: child,
      );
      return UnconstrainedBox(child: container);
    });
  }

  Widget _buildData(List<SentinelEntity> sentinels) {
    List<Widget> children = [
      _DesktopSentinelSelectDialogTile(
        sentinel: SentinelViewModel.directChatSentinel,
        label: SentinelViewModel.directChatOptionLabel,
        onTap: () => onTap?.call(SentinelViewModel.directChatSentinel),
      ),
      ...sentinels.map(_itemBuilder),
    ];
    return ConstrainedBox(
      constraints: BoxConstraints.loose(Size(520, 640)),
      child: ListView(shrinkWrap: true, children: children),
    );
  }

  Widget _itemBuilder(SentinelEntity sentinel) {
    return _DesktopSentinelSelectDialogTile(
      sentinel: sentinel,
      onTap: () => onTap?.call(sentinel),
    );
  }
}
