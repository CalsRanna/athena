import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_gui/router/router.gr.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/view_model/sentinel_view_model.dart';
import 'package:athena_gui/widget/app_bar.dart';
import 'package:athena_gui/widget/bottom_sheet_tile.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/scaffold.dart';
import 'package:athena_gui/widget/tile.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get_it/get_it.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:signals_flutter/signals_flutter.dart';

@RoutePage()
class MobileSentinelListPage extends StatelessWidget {
  const MobileSentinelListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final colors = Theme.of(context).extension<AthenaColors>()!;
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
                  decoration: BoxDecoration(
                    color: colors.surfaceDeep,
                    border: Border.all(color: colors.border),
                    borderRadius: BorderRadius.circular(AthenaRadius.control),
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
                          color: colors.surfaceRaised,
                          borderRadius: BorderRadius.circular(
                            AthenaRadius.inline,
                          ),
                        ),
                        height: 24,
                        width: 24,
                        child: Icon(
                          LucideIcons.plus,
                          size: 12,
                          color: colors.iconOnRaised,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Add a sentinel',
                        style: AthenaTextStyle.section.copyWith(
                          color: colors.textPrimary,
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
      itemBuilder: (context, index) {
        var sentinel = sentinels[index];
        return MobileGridTile(
          title: sentinel.name,
          subtitle: sentinel.description,
          onTap: () => editSentinel(context, sentinel),
          onLongPress: () => openBottomSheet(context, sentinel),
        );
      },
      padding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  void destroySentinel(BuildContext context, SentinelEntity sentinel) {
    AthenaDialog.dismiss();
    GetIt.instance<SentinelViewModel>().deleteSentinel(sentinel);
  }

  void editSentinel(BuildContext context, SentinelEntity sentinel) {
    MobileSentinelFormRoute(sentinel: sentinel).push(context);
  }

  void openBottomSheet(BuildContext context, SentinelEntity sentinel) {
    HapticFeedback.heavyImpact();
    if (sentinel.isPreset) return;
    var editTile = AthenaBottomSheetTile(
      leading: Icon(LucideIcons.pencilLine),
      title: 'Edit',
      onTap: () => editSentinel(context, sentinel),
    );
    var deleteTile = AthenaBottomSheetTile(
      leading: Icon(LucideIcons.trash2),
      title: 'Delete',
      onTap: () => destroySentinel(context, sentinel),
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
