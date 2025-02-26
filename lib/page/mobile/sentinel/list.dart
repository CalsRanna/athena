import 'package:athena/provider/sentinel.dart';
import 'package:athena/router/router.gr.dart';
import 'package:athena/schema/sentinel.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/chat.dart';
import 'package:athena/view_model/sentinel.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/bottom_sheet_tile.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:hugeicons/hugeicons.dart';

@RoutePage()
class MobileSentinelListPage extends ConsumerWidget {
  const MobileSentinelListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var provider = sentinelsNotifierProvider;
    var state = ref.watch(provider);
    var listView = switch (state) {
      AsyncData(:final value) => _buildData(value),
      _ => const SizedBox(),
    };
    return AScaffold(
      appBar: AAppBar(title: const Text('Sentinel')),
      body: Stack(
        children: [
          listView,
          Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => navigateSentinelFormPage(context),
              child: Container(
                decoration: ShapeDecoration(
                  color: ColorUtil.FF161616,
                  shape: StadiumBorder(),
                ),
                padding: EdgeInsets.fromLTRB(8, 12, 12, 12),
                margin: EdgeInsets.only(
                    bottom: MediaQuery.paddingOf(context).bottom),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: ColorUtil.FFFFFFFF,
                        shape: BoxShape.circle,
                      ),
                      height: 24,
                      width: 24,
                      child: Icon(
                        HugeIcons.strokeRoundedAdd01,
                        size: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Add a sentinel',
                      style: TextStyle(
                        color: ColorUtil.FFFFFFFF,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  void navigateSentinelFormPage(BuildContext context) {
    MobileSentinelFormRoute().push(context);
  }

  Widget _buildData(List<Sentinel> sentinels) {
    return MasonryGridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      itemCount: sentinels.length,
      itemBuilder: (context, index) => _Tile(sentinel: sentinels[index]),
      padding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}

class _Tile extends ConsumerWidget {
  final Sentinel sentinel;
  const _Tile({required this.sentinel});
  @override
  Widget build(BuildContext context, ref) {
    const nameTextStyle = TextStyle(
      color: Colors.black,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );
    const descriptionTextStyle = TextStyle(
      color: ColorUtil.FF616161,
      fontSize: 12,
    );
    var children = [
      Text(sentinel.name, style: nameTextStyle),
      Text(sentinel.description, style: descriptionTextStyle),
    ];
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      color: ColorUtil.FFFFFFFF,
    );
    var container = Container(
      decoration: boxDecoration,
      padding: EdgeInsets.all(12),
      child: column,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () => openBottomSheet(context, ref),
      onTap: () => navigateChatPage(context, ref),
      child: container,
    );
  }

  void destroySentinel(BuildContext context, WidgetRef ref) {
    ADialog.dismiss();
    SentinelViewModel(ref).destroySentinel(sentinel);
  }

  void editSentinel(BuildContext context) {
    ADialog.dismiss();
    MobileSentinelFormRoute(sentinel: sentinel).push(context);
  }

  Future<void> navigateChatPage(BuildContext context, WidgetRef ref) async {
    ADialog.dismiss();
    var viewModel = ChatViewModel(ref);
    var chat = await viewModel.createChat(sentinel: sentinel);
    if (!context.mounted) return;
    MobileChatRoute(chat: chat).push(context);
  }

  void openBottomSheet(BuildContext context, WidgetRef ref) {
    HapticFeedback.heavyImpact();
    if (sentinel.name == 'Athena') return;
    var editTile = ABottomSheetTile(
      leading: Icon(HugeIcons.strokeRoundedPencilEdit02),
      title: 'Edit',
      onTap: () => editSentinel(context),
    );
    var deleteTile = ABottomSheetTile(
      leading: Icon(HugeIcons.strokeRoundedDelete02),
      title: 'Delete',
      onTap: () => destroySentinel(context, ref),
    );
    var children = [editTile, deleteTile];
    var column = Column(mainAxisSize: MainAxisSize.min, children: children);
    var padding = Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: column,
    );
    ADialog.show(SafeArea(child: padding));
  }
}
