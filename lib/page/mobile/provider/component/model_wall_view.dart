import 'package:athena/entity/ai_provider_entity.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:athena/view_model/model_view_model.dart';
import 'package:athena/widget/tag.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

class MobileModelWallView extends StatelessWidget {
  final void Function(ModelEntity)? onLongPress;
  final void Function(ModelEntity)? onTap;
  final AIProviderEntity provider;
  const MobileModelWallView({
    super.key,
    this.onLongPress,
    this.onTap,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      var modelViewModel = GetIt.instance<ModelViewModel>();
      var models = modelViewModel.models.value
          .where((m) => m.providerId == provider.id)
          .toList();
      if (models.isEmpty) return const SizedBox();
      List<Widget> children1 = [];
      List<Widget> children2 = [];
      List<Widget> children3 = [];
      for (var i = 0; i < models.length; i++) {
        var tile = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPress: () => onLongPress?.call(models[i]),
          onTap: () => onTap?.call(models[i]),
          child: AthenaTag(text: models[i].name),
        );
        if (i % 3 == 0) children1.add(tile);
        if (i % 3 == 1) children2.add(tile);
        if (i % 3 == 2) children3.add(tile);
      }
      var columnChildren = [
        Row(spacing: 12, children: children1),
        Row(spacing: 12, children: children2),
        Row(spacing: 12, children: children3),
      ];
      var column = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: columnChildren,
      );
      var singleChildScrollView = SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        child: column,
      );
      return SizedBox(height: 164, child: singleChildScrollView);
    });
  }
}
