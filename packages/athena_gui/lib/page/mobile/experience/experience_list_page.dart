import 'package:athena_core/entity/experience_entity.dart';
import 'package:athena_gui/page/mobile/component/empty_state.dart';
import 'package:athena_gui/router/router.gr.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/view_model/experience_view_model.dart';
import 'package:athena_gui/widget/app_bar.dart';
import 'package:athena_gui/widget/bottom_sheet_tile.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/scaffold.dart';
import 'package:athena_gui/widget/tag.dart';
import 'package:athena_gui/page/mobile/component/grid_tile.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get_it/get_it.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:athena_gui/extension/athena_theme_context.dart';

/// 经验管理列表：All / Shared / Private 过滤；活跃与归档分区展示。
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
    return SignalBuilder(
      builder: (context) {
        final all = viewModel.experiences.value;
        final experiences = scopeFilter == null
            ? all
            : all.where((e) => e.scope == scopeFilter).toList();
        return AthenaScaffold(
          appBar: const AthenaAppBar(title: Text('Experiences')),
          body: Column(
            children: [
              _buildFilterBar(context),
              Expanded(child: _buildData(context, experiences)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    final children = [
      AthenaTagButton.small(
        selected: scopeFilter == null,
        onTap: () => setState(() => scopeFilter = null),
        child: const Text('All'),
      ),
      AthenaTagButton.small(
        selected: scopeFilter == 'shared',
        onTap: () => setState(() => scopeFilter = 'shared'),
        child: const Text('Shared'),
      ),
      AthenaTagButton.small(
        selected: scopeFilter == 'self',
        onTap: () => setState(() => scopeFilter = 'self'),
        child: const Text('Private'),
      ),
    ];
    // 系统字号放大后三个 chip 会超出屏宽，用 Wrap 换行而不是让 Row 溢出。
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(spacing: 8, runSpacing: 8, children: children),
    );
  }

  Widget _buildData(BuildContext context, List<ExperienceEntity> experiences) {
    final active = experiences
        .where((e) => e.status != ExperienceEntity.statusArchived)
        .toList();
    final archived = experiences
        .where((e) => e.status == ExperienceEntity.statusArchived)
        .toList();
    if (active.isEmpty && archived.isEmpty) {
      return MobileEmptyState(
        icon: LucideIcons.brain,
        title: scopeFilter == null
            ? 'No experiences yet'
            : 'No ${scopeFilter == 'shared' ? 'shared' : 'private'} experiences',
        hint:
            'Experiences are lessons the agent saves after a session. '
            'They appear here once there are some.',
      );
    }
    return RefreshIndicator(
      onRefresh: viewModel.load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (active.isNotEmpty) ...[
            _sectionTitle(context, 'Experiences'),
            _grid(context, active),
          ],
          if (archived.isNotEmpty) ...[
            _sectionTitle(context, 'Archived'),
            _grid(context, archived),
          ],
          SliverToBoxAdapter(
            child: SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    final colors = context.athenaColors;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Text(
          title,
          style: AthenaTextStyle.title.copyWith(color: colors.textPrimary),
        ),
      ),
    );
  }

  Widget _grid(BuildContext context, List<ExperienceEntity> experiences) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverMasonryGrid.count(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childCount: experiences.length,
        itemBuilder: (context, index) =>
            _buildTile(context, experiences[index]),
      ),
    );
  }

  Widget _buildTile(BuildContext context, ExperienceEntity experience) {
    final isArchived = experience.status == ExperienceEntity.statusArchived;
    final owner = viewModel.ownerLabel(experience);
    return MobileGridTile(
      title: experience.lesson,
      subtitle: '$owner · ${_formatDate(experience.createdAt)}',
      titleMaxLines: 3,
      subtitleMaxLines: 2,
      trailing: isArchived ? const Icon(LucideIcons.archive) : null,
      onTap: () => _navigateDetailPage(context, experience),
      onLongPress: () => openBottomSheet(context, experience),
    );
  }

  void _navigateDetailPage(BuildContext context, ExperienceEntity experience) {
    MobileExperienceDetailRoute(experience: experience).push<void>(context);
  }

  void openBottomSheet(BuildContext context, ExperienceEntity experience) {
    HapticFeedback.heavyImpact();
    final isArchived = experience.status == ExperienceEntity.statusArchived;
    final statusTile = AthenaBottomSheetTile(
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
    final deleteTile = AthenaBottomSheetTile(
      leading: const Icon(LucideIcons.trash2),
      title: 'Delete',
      onTap: () async {
        AthenaDialog.dismiss();
        final result = await AthenaDialog.confirm('Delete this experience?');
        if (result != true) return;
        await viewModel.deleteExperience(experience);
      },
    );
    final children = [statusTile, deleteTile];
    final column = Column(mainAxisSize: MainAxisSize.min, children: children);
    final padding = Padding(
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
