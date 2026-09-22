import 'package:athena_core/entity/experience_entity.dart';
import 'package:athena_gui/router/router.gr.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/view_model/experience_view_model.dart';
import 'package:athena_gui/widget/app_bar.dart';
import 'package:athena_gui/widget/bottom_sheet_tile.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/scaffold.dart';
import 'package:athena_gui/widget/tag.dart';
import 'package:athena_gui/widget/tile.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get_it/get_it.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// 经验管理列表：All / Shared / Private 过滤 + 归档开关；
/// 长按归档/恢复或删除，点击进入详情。
@RoutePage()
class MobileExperienceListPage extends StatefulWidget {
  const MobileExperienceListPage({super.key});

  @override
  State<MobileExperienceListPage> createState() =>
      _MobileExperienceListPageState();
}

class _MobileExperienceListPageState extends State<MobileExperienceListPage> {
  late final viewModel = GetIt.instance<ExperienceViewModel>();
  String? scopeFilter; // null = all, 'shared', 'self'

  @override
  void initState() {
    super.initState();
    viewModel.load();
  }

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      var all = viewModel.experiences.value;
      var experiences = scopeFilter == null
          ? all
          : all.where((e) => e.scope == scopeFilter).toList();
      return AthenaScaffold(
        appBar: AthenaAppBar(title: const Text('Experiences')),
        body: Column(
          children: [
            _buildFilterBar(context),
            Expanded(child: _buildData(context, experiences)),
          ],
        ),
      );
    });
  }

  Widget _buildFilterBar(BuildContext context) {
    var children = [
      AthenaTagButton.small(
        selected: scopeFilter == null,
        onTap: () => setState(() => scopeFilter = null),
        child: const Text('All'),
      ),
      const SizedBox(width: 8),
      AthenaTagButton.small(
        selected: scopeFilter == 'shared',
        onTap: () => setState(() => scopeFilter = 'shared'),
        child: const Text('Shared'),
      ),
      const SizedBox(width: 8),
      AthenaTagButton.small(
        selected: scopeFilter == 'self',
        onTap: () => setState(() => scopeFilter = 'self'),
        child: const Text('Private'),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: children),
    );
  }

  Widget _buildData(BuildContext context, List<ExperienceEntity> experiences) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    if (experiences.isEmpty) {
      var textStyle = AthenaTextStyle.body.copyWith(color: colors.textPrimary);
      return Center(child: Text('No experiences yet', style: textStyle));
    }
    return MasonryGridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      itemCount: experiences.length,
      itemBuilder: (context, index) {
        var experience = experiences[index];
        var isArchived = experience.status == ExperienceEntity.statusArchived;
        var owner = viewModel.ownerLabel(experience);
        return MobileGridTile(
          title: experience.lesson,
          subtitle: '$owner · ${_formatDate(experience.createdAt)}',
          titleMaxLines: 3,
          subtitleMaxLines: 2,
          trailing: isArchived
              ? const Icon(HugeIcons.strokeRoundedArchive)
              : null,
          onTap: () => _navigateDetailPage(context, experience),
          onLongPress: () => openBottomSheet(context, experience),
        );
      },
      padding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  void _navigateDetailPage(BuildContext context, ExperienceEntity experience) {
    MobileExperienceDetailRoute(experience: experience).push(context);
  }

  void openBottomSheet(BuildContext context, ExperienceEntity experience) {
    HapticFeedback.heavyImpact();
    var isArchived = experience.status == ExperienceEntity.statusArchived;
    var statusTile = AthenaBottomSheetTile(
      title: isArchived ? 'Restore' : 'Archive',
      onTap: () {
        AthenaDialog.dismiss();
        if (isArchived) {
          viewModel.restoreExperience(experience);
        } else {
          viewModel.archiveExperience(experience);
        }
      },
    );
    var deleteTile = AthenaBottomSheetTile(
      leading: const Icon(HugeIcons.strokeRoundedDelete02),
      title: 'Delete',
      onTap: () async {
        AthenaDialog.dismiss();
        var result = await AthenaDialog.confirm('Delete this experience?');
        if (result != true) return;
        await viewModel.deleteExperience(experience);
      },
    );
    var children = [statusTile, deleteTile];
    var column = Column(mainAxisSize: MainAxisSize.min, children: children);
    var padding = Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: column,
    );
    AthenaDialog.show(SafeArea(child: padding));
  }
}

String _formatDate(DateTime dt) {
  String pad(int n) => n.toString().padLeft(2, '0');
  return '${dt.year}-${pad(dt.month)}-${pad(dt.day)}';
}
