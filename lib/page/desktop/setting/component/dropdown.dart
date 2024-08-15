import 'package:athena/provider/model.dart';
import 'package:athena/schema/model.dart';
import 'package:athena/widget/card.dart';
import 'package:athena/widget/tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ModelsDropdown extends StatelessWidget {
  final Alignment followerAnchor;
  final LayerLink link;
  final Offset offset;
  final void Function(Model)? onChanged;
  final void Function()? onClose;
  final Alignment targetAnchor;

  const ModelsDropdown({
    super.key,
    this.followerAnchor = Alignment.topCenter,
    required this.link,
    this.offset = const Offset(0, 24),
    this.onChanged,
    this.onClose,
    this.targetAnchor = Alignment.bottomRight,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onClose,
      child: SizedBox.expand(
        child: UnconstrainedBox(
          child: CompositedTransformFollower(
            followerAnchor: followerAnchor,
            link: link,
            offset: offset,
            targetAnchor: targetAnchor,
            child: _Target(onChanged: onChanged),
          ),
        ),
      ),
    );
  }
}

class _List extends StatelessWidget {
  final void Function(Model)? onChanged;
  final List<Model> models;
  const _List({this.onChanged, required this.models});

  @override
  Widget build(BuildContext context) {
    if (models.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: getChildren(context),
    );
  }

  List<Widget> getChildren(BuildContext context) {
    return models.map((model) {
      return _Tile(model, onTap: () => handleTap(model));
    }).toList();
  }

  void handleTap(Model model) {
    onChanged?.call(model);
  }
}

class _Target extends StatelessWidget {
  final void Function(Model)? onChanged;
  const _Target({this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ACard(
      width: 200,
      child: Consumer(builder: (context, ref, child) {
        final state = ref.watch(modelsNotifierProvider);
        return switch (state) {
          AsyncData(:final value) => _List(onChanged: onChanged, models: value),
          _ => const SizedBox(),
        };
      }),
    );
  }
}

class _Tile extends StatelessWidget {
  final void Function()? onTap;
  final Model model;
  const _Tile(this.model, {this.onTap});

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, child) {
      return ATile(onTap: () => handleTap(ref), title: model.name);
    });
  }

  void handleTap(WidgetRef ref) {
    onTap?.call();
  }
}
