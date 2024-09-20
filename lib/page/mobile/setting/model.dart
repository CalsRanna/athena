import 'package:athena/provider/model.dart';
import 'package:athena/provider/setting.dart';
import 'package:athena/schema/model.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

class ModelPage extends ConsumerWidget {
  const ModelPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final models = ref.watch(modelsNotifierProvider).valueOrNull;
    if (models == null) return const AScaffold(appBar: AAppBar());
    return AScaffold(
      appBar: const AAppBar(title: Text('Default Model')),
      body: ListView.builder(
        itemBuilder: (context, index) {
          return _Tile(model: models[index]);
        },
        itemCount: models.length,
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class _Tile extends ConsumerWidget {
  const _Tile({required this.model});

  final Model model;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setting = ref.watch(settingNotifierProvider).valueOrNull;
    const color = Color(0xffffffff);
    const selected = HugeIcon(
      color: color,
      icon: HugeIcons.strokeRoundedTick02,
    );
    return ListTile(
      onTap: () => handleTap(ref),
      title: Text(model.name, style: const TextStyle(color: color)),
      trailing: setting?.model == model.value ? selected : null,
    );
  }

  void handleTap(WidgetRef ref) {
    final notifier = ref.read(settingNotifierProvider.notifier);
    notifier.updateModel(model.value);
  }
}
