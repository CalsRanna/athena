import 'package:athena/provider/model.dart';
import 'package:athena/provider/setting.dart';
import 'package:athena/router/router.gr.dart';
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
      appBar: const AAppBar(title: Text('Model')),
      body: Stack(
        children: [
          ListView.builder(
            itemBuilder: (context, index) {
              return _Tile(model: models[index]);
            },
            itemCount: models.length,
            padding: EdgeInsets.zero,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => navigateModelFormPage(context),
              child: Container(
                decoration: ShapeDecoration(
                  color: Color(0xFF161616),
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
                        color: Colors.white,
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
                      'Add a model',
                      style: TextStyle(
                        color: Colors.white,
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

  void navigateModelFormPage(BuildContext context) {
    MobileModelFormRoute().push(context);
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
