import 'package:athena_core/entity/experience_entity.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/view_model/experience_view_model.dart';
import 'package:athena_gui/widget/app_bar.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/scaffold.dart';
import 'package:athena_gui/widget/tag.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// 经验详情页：完整 lesson / context / tags / 归属与状态，
/// 提供编辑、归档/恢复与删除。
@RoutePage()
class MobileExperienceDetailPage extends StatefulWidget {
  final ExperienceEntity experience;
  const MobileExperienceDetailPage({super.key, required this.experience});

  @override
  State<MobileExperienceDetailPage> createState() =>
      _MobileExperienceDetailPageState();
}

class _MobileExperienceDetailPageState
    extends State<MobileExperienceDetailPage> {
  late final viewModel = GetIt.instance<ExperienceViewModel>();

  @override
  void initState() {
    super.initState();
    viewModel.load();
  }

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final colors = Theme.of(context).extension<AthenaColors>()!;
      var experience = viewModel.experiences.value
          .where((e) => e.id == widget.experience.id)
          .firstOrNull;
      experience ??= widget.experience;
      var isArchived = experience.status == ExperienceEntity.statusArchived;
      var children = [
        Text(
          experience.lesson,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        _metaRow(context, 'Owner', viewModel.ownerLabel(experience)),
        _metaRow(context, 'Scope', experience.scope),
        _metaRow(context, 'Source', experience.source),
        _metaRow(context, 'Status', isArchived ? 'Archived' : 'Active'),
        _metaRow(context, 'Created', _formatDate(experience.createdAt)),
        if (experience.updatedAt != null)
          _metaRow(context, 'Updated', _formatDate(experience.updatedAt!)),
        if (experience.context.isNotEmpty) ...[
          const SizedBox(height: 16),
          _label(context, 'Context'),
          const SizedBox(height: 8),
          Text(
            experience.context,
            style: TextStyle(color: colors.textPrimary, fontSize: 14),
          ),
        ],
        if (experience.tags.isNotEmpty) ...[
          const SizedBox(height: 16),
          _label(context, 'Tags'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in experience.tags) AthenaTag.small(text: tag),
            ],
          ),
        ],
        const SizedBox(height: 24),
        _buildButtons(context, experience, isArchived),
        SafeArea(top: false, child: const SizedBox()),
      ];
      return AthenaScaffold(
        appBar: AthenaAppBar(title: const Text('Experience')),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: children,
        ),
      );
    });
  }

  Widget _label(BuildContext context, String text) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return Text(
      text,
      style: TextStyle(
        color: colors.textWeak,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _metaRow(BuildContext context, String label, String value) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(color: colors.textWeak, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: colors.textPrimary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtons(
    BuildContext context,
    ExperienceEntity experience,
    bool isArchived,
  ) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var textStyle = TextStyle(
      color: colors.textOnRaised,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );
    var children = [
      Expanded(
        child: AthenaPrimaryButton(
          onTap: () => _toggleStatus(experience, isArchived),
          child: Center(
            child: Text(
              isArchived ? 'Restore' : 'Archive',
              style: textStyle,
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: AthenaTextButton(
          text: 'Delete',
          onTap: () => destroyExperience(context, experience),
        ),
      ),
    ];
    return Row(children: children);
  }

  Future<void> _toggleStatus(
    ExperienceEntity experience,
    bool isArchived,
  ) async {
    var ok = isArchived
        ? await viewModel.restoreExperience(experience)
        : await viewModel.archiveExperience(experience);
    if (!mounted) return;
    if (!ok) {
      AthenaDialog.warning(viewModel.error.value ?? 'Operation failed');
    }
  }

  Future<void> destroyExperience(
    BuildContext context,
    ExperienceEntity experience,
  ) async {
    var result = await AthenaDialog.confirm('Delete this experience?');
    if (result != true) return;
    var removed = await viewModel.deleteExperience(experience);
    if (!context.mounted) return;
    if (!removed) {
      AthenaDialog.warning(
        viewModel.error.value ?? 'Failed to delete experience',
      );
      return;
    }
    AutoRouter.of(context).maybePop();
  }
}

String _formatDate(DateTime dt) {
  String pad(int n) => n.toString().padLeft(2, '0');
  return '${dt.year}-${pad(dt.month)}-${pad(dt.day)}';
}
