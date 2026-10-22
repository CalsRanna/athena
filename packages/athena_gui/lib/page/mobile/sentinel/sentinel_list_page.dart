import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_gui/page/mobile/component/empty_state.dart';
import 'package:athena_gui/router/router.gr.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/view_model/sentinel_view_model.dart';
import 'package:athena_gui/widget/app_bar.dart';
import 'package:athena_gui/widget/bottom_sheet_tile.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/scaffold.dart';
import 'package:athena_gui/page/mobile/component/grid_tile.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get_it/get_it.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:athena_gui/extension/athena_theme_context.dart';

@RoutePage()
class MobileSentinelListPage extends StatelessWidget {
  const MobileSentinelListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final colors = context.athenaColors;
      final sentinelViewModel = GetIt.instance<SentinelViewModel>();
      final sentinels = sentinelViewModel.sentinels.value;
      return AthenaScaffold(
        appBar: const AthenaAppBar(title: Text('Sentinel')),
        body: Stack(
          children: [
            _buildData(context, sentinels),
            Align(
              alignment: Alignment.bottomCenter,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => navigateSentinelFormPage(context),
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.surfaceButtonSecondary,
                    border: Border.all(color: colors.border),
                    borderRadius: BorderRadius.circular(AthenaRadius.control),
                  ),
                  padding: const EdgeInsets.fromLTRB(8, 12, 12, 12),
                  margin: EdgeInsets.only(
                    bottom: 16 + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: colors.surfaceMobile,
                          border: Border.all(color: colors.border),
                          borderRadius: BorderRadius.circular(
                            AthenaRadius.inline,
                          ),
                        ),
                        height: 24,
                        width: 24,
                        child: Icon(
                          LucideIcons.plus,
                          // 24 圆角容器内的小符号，按容器比例取 12，不套用三档映射
                          size: 12,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
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
    MobileSentinelFormRoute().push<void>(context);
  }

  Widget _buildData(BuildContext context, List<SentinelEntity> sentinels) {
    if (sentinels.isEmpty) {
      return const MobileEmptyState(
        icon: LucideIcons.userRound,
        title: 'No Sentinels yet',
        hint:
            'Sentinels are reusable roles with their own system prompt. '
            'Add one with the button below.',
      );
    }
    final colors = context.athenaColors;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'Sentinels',
              style: AthenaTextStyle.title.copyWith(color: colors.textPrimary),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverMasonryGrid.count(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childCount: sentinels.length,
            itemBuilder: (context, index) {
              final sentinel = sentinels[index];
              return MobileGridTile(
                title: sentinel.name,
                subtitle: sentinel.description,
                trailing: sentinel.isPreset
                    ? const Icon(LucideIcons.lockKeyhole)
                    : null,
                onTap: () => editSentinel(context, sentinel),
                onLongPress: () => openBottomSheet(context, sentinel),
              );
            },
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(height: 96 + MediaQuery.paddingOf(context).bottom),
        ),
      ],
    );
  }

  Future<void> destroySentinel(
    BuildContext context,
    SentinelEntity sentinel,
  ) async {
    AthenaDialog.dismiss();
    final confirmed = await AthenaDialog.confirm(
      'Delete ${sentinel.name}?\n\n'
      'Its private experiences and evolution history are deleted with it. '
      'Shared experiences are kept. This cannot be undone.',
    );
    if (confirmed != true) return;
    final viewModel = GetIt.instance<SentinelViewModel>();
    await viewModel.deleteSentinel(sentinel);
    if (!context.mounted) return;
    final error = viewModel.error.value;
    if (error != null) AthenaDialog.error(error);
  }

  Future<void> duplicateSentinel(
    BuildContext context,
    SentinelEntity source,
  ) async {
    AthenaDialog.dismiss();
    final copy = SentinelEntity(
      name: '${source.name} copy',
      description: source.description,
      prompt: source.prompt,
      tags: source.tags,
    );
    final viewModel = GetIt.instance<SentinelViewModel>();
    final created = await viewModel.createSentinel(copy);
    if (!context.mounted) return;
    if (created == null) {
      AthenaDialog.error(viewModel.error.value ?? 'Failed to duplicate');
      return;
    }
    MobileSentinelFormRoute(sentinel: created).push<void>(context);
  }

  void editSentinel(BuildContext context, SentinelEntity sentinel) {
    MobileSentinelFormRoute(sentinel: sentinel).push<void>(context);
  }

  void openBottomSheet(BuildContext context, SentinelEntity sentinel) {
    HapticFeedback.heavyImpact();
    final duplicateTile = AthenaBottomSheetTile(
      leading: const Icon(LucideIcons.copy),
      title: 'Duplicate',
      onTap: () => duplicateSentinel(context, sentinel),
    );
    final children = <Widget>[];
    if (!sentinel.isPreset) {
      children.add(
        AthenaBottomSheetTile(
          leading: const Icon(LucideIcons.pencilLine),
          title: 'Edit',
          onTap: () => editSentinel(context, sentinel),
        ),
      );
    }
    children.add(duplicateTile);
    if (!sentinel.isPreset) {
      children.add(
        AthenaBottomSheetTile(
          leading: const Icon(LucideIcons.trash2),
          title: 'Delete',
          onTap: () => destroySentinel(context, sentinel),
        ),
      );
    }
    final column = Column(mainAxisSize: MainAxisSize.min, children: children);
    final padding = Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: column,
    );
    AthenaDialog.show(SafeArea(child: padding));
  }
}
