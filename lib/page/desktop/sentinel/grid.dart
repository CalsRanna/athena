import 'package:athena/provider/sentinel.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/menu.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:athena/widget/window_button.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

@RoutePage()
class DesktopSentinelGridPage extends StatelessWidget {
  const DesktopSentinelGridPage({super.key});

  @override
  Widget build(BuildContext context) {
    var children = [
      Row(
        children: [
          Stack(
            children: [
              Container(
                height: 50,
                width: 120,
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => popPage(context),
                  child: Icon(
                    HugeIcons.strokeRoundedArrowTurnBackward,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              const Positioned(left: 16, top: 18, child: MacWindowButton())
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
              child: Text('Sentinel', style: TextStyle(color: Colors.white))),
        ],
      ),
      SizedBox(height: 52, child: _TagListView()),
      Expanded(child: _SentinelGridView()),
    ];
    return AScaffold(appBar: AAppBar(), body: Column(children: children));
  }

  void popPage(BuildContext context) {
    AutoRouter.of(context).maybePop();
  }
}

class _SentinelGridView extends ConsumerWidget {
  const _SentinelGridView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var provider = sentinelsNotifierProvider;
    var state = ref.watch(provider);
    return switch (state) {
      AsyncData(:final value) => _buildData(value),
      _ => const SizedBox(),
    };
  }

  Widget _buildData(List<Sentinel> sentinels) {
    const delegate = SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 4,
      childAspectRatio: 2.0,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
    );
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: delegate,
      itemCount: sentinels.length,
      itemBuilder: (context, index) => _SentinelTile(sentinels[index]),
    );
  }
}

class _SentinelTile extends StatefulWidget {
  final Sentinel sentinel;
  const _SentinelTile(this.sentinel);

  @override
  State<_SentinelTile> createState() => _SentinelTileState();
}

class _SentinelTileState extends State<_SentinelTile> {
  OverlayEntry? entry;

  @override
  Widget build(BuildContext context) {
    const nameTextStyle = TextStyle(
      color: Colors.black,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.5,
    );
    const descriptionTextStyle = TextStyle(
      color: Color(0xFF616161),
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.5,
    );
    var descriptionText = Text(
      widget.sentinel.description,
      style: descriptionTextStyle,
    );
    var children = [
      Text(widget.sentinel.name, style: nameTextStyle),
      const SizedBox(height: 4),
      Expanded(child: descriptionText),
    ];
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      color: Colors.white,
    );
    var container = Container(
      decoration: boxDecoration,
      padding: const EdgeInsets.all(12),
      child: column,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapUp: (details) => showContextMenu(context, details),
      onTap: () => handleTap(context),
      child: container,
    );
  }

  void showContextMenu(BuildContext context, TapUpDetails details) {
    var contextMenu = _ContextMenu(
      offset: details.globalPosition,
      onTap: removeEntry,
      sentinel: widget.sentinel,
    );
    entry = OverlayEntry(builder: (_) => contextMenu);
    Overlay.of(context).insert(entry!);
  }

  void removeEntry() {
    if (entry != null) {
      entry!.remove();
      entry = null;
    }
  }

  void handleTap(BuildContext context) {
    AutoRouter.of(context).maybePop<Sentinel>(widget.sentinel);
  }
}

class _ContextMenu extends StatelessWidget {
  final Offset offset;
  final void Function()? onTap;
  final Sentinel sentinel;
  const _ContextMenu(
      {required this.offset, this.onTap, required this.sentinel});

  @override
  Widget build(BuildContext context) {
    var editOption = DesktopContextMenuOption(
      text: 'Edit',
      onTap: () => navigateSentinelFormPage(context, sentinel),
    );
    var deleteOption = DesktopContextMenuOption(
      text: 'Delete',
      onTap: () => destroySentinel(context),
    );
    return DesktopContextMenu(
      offset: offset,
      onBarrierTapped: onTap,
      children: [editOption, deleteOption],
    );
  }

  void destroySentinel(BuildContext context) {
    AutoRouter.of(context).maybePop<Sentinel>(sentinel);
    onTap?.call();
  }

  void navigateSentinelFormPage(BuildContext context, Sentinel sentinel) {
    onTap?.call();
  }
}

class _Tag extends StatelessWidget {
  final String text;
  const _Tag({required this.text});

  @override
  Widget build(BuildContext context) {
    var textStyle = TextStyle(
      color: Colors.white,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 1.5,
    );
    var innerBoxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(44),
      color: Color(0xFF161616),
    );
    var container = Container(
      decoration: innerBoxDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 13),
      child: Text(text, style: textStyle),
    );
    var colors = [
      Color(0xFFEAEAEA).withValues(alpha: 0.17),
      Colors.white.withValues(alpha: 0),
    ];
    var linearGradient = LinearGradient(
      begin: Alignment.topLeft,
      colors: colors,
      end: Alignment.bottomRight,
    );
    var outerBoxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(44),
      gradient: linearGradient,
    );
    return Container(
      decoration: outerBoxDecoration,
      padding: EdgeInsets.all(1),
      child: container,
    );
  }
}

class _TagListView extends ConsumerWidget {
  const _TagListView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var provider = sentinelTagsNotifierProvider;
    var state = ref.watch(provider);
    return switch (state) {
      AsyncData(:final value) => _buildData(value),
      _ => const SizedBox(),
    };
  }

  Widget _buildData(List<String> tags) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemBuilder: (_, index) => _Tag(text: tags[index]),
      itemCount: tags.length,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      separatorBuilder: (context, index) => const SizedBox(width: 12),
    );
  }
}
