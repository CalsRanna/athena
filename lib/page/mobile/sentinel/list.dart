import 'package:athena/entity/sentinel_entity.dart';
import 'package:athena/router/router.gr.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/chat_view_model.dart';
import 'package:athena/view_model/sentinel_view_model.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/bottom_sheet_tile.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get_it/get_it.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:signals_flutter/signals_flutter.dart';

@RoutePage()
class MobileSentinelListPage extends StatelessWidget {
  const MobileSentinelListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      var sentinelViewModel = GetIt.instance<SentinelViewModel>();
      var sentinels = sentinelViewModel.sentinels.value;
      return AthenaScaffold(
        appBar: AthenaAppBar(title: const Text('Sentinel')),
        body: Stack(
          children: [
            _buildData(sentinels),
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
                    bottom: MediaQuery.paddingOf(context).bottom,
                  ),
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
                        child: Icon(HugeIcons.strokeRoundedAdd01, size: 12),
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
            ),
          ],
        ),
      );
    });
  }

  void navigateSentinelFormPage(BuildContext context) {
    MobileSentinelFormRoute().push(context);
  }

  Widget _buildData(List<SentinelEntity> sentinels) {
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

class _Tile extends StatelessWidget {
  final SentinelEntity sentinel;
  const _Tile({required this.sentinel});
  @override
  Widget build(BuildContext context) {
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
      onLongPress: () => openBottomSheet(context),
      onTap: () => navigateChatPage(context),
      child: container,
    );
  }

  void destroySentinel(BuildContext context) {
    AthenaDialog.dismiss();
    GetIt.instance<SentinelViewModel>().deleteSentinel(sentinel);
  }

  void editSentinel(BuildContext context) {
    AthenaDialog.dismiss();
    MobileSentinelFormRoute(sentinel: sentinel).push(context);
  }

  Future<void> navigateChatPage(BuildContext context) async {
    AthenaDialog.dismiss();
    var viewModel = GetIt.instance<ChatViewModel>();
    var chat = await viewModel.createChat(sentinel: sentinel);
    if (!context.mounted) return;
    if (chat != null) {
      MobileChatRoute(chat: chat).push(context);
    }
  }

  void openBottomSheet(BuildContext context) {
    HapticFeedback.heavyImpact();
    if (sentinel.name == 'Athena') return;
    var editTile = AthenaBottomSheetTile(
      leading: Icon(HugeIcons.strokeRoundedPencilEdit02),
      title: 'Edit',
      onTap: () => editSentinel(context),
    );
    var deleteTile = AthenaBottomSheetTile(
      leading: Icon(HugeIcons.strokeRoundedDelete02),
      title: 'Delete',
      onTap: () => destroySentinel(context),
    );
    var children = [editTile, deleteTile];
    var column = Column(mainAxisSize: MainAxisSize.min, children: children);
    var padding = Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: column,
    );
    AthenaDialog.show(SafeArea(child: padding));
  }
}
