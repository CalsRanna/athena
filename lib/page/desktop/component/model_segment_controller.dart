import 'package:athena/creator/chat.dart';
import 'package:athena/page/desktop/component/model_tile.dart';
import 'package:athena/provider/chat_provider.dart';
import 'package:athena/provider/model_provider.dart';
import 'package:creator/creator.dart';
import 'package:flutter/material.dart';

class ModelSegmentController extends StatefulWidget {
  const ModelSegmentController({super.key});

  @override
  State<StatefulWidget> createState() => _ModelSegmentControllerState();
}

class _ModelSegmentControllerState extends State<ModelSegmentController>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;
  double offset = 0;
  List<String> models = ['gpt-3.5-turbo-16k', 'gpt-4'];

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    controller.addListener(() {
      setState(() {
        offset = controller.value * 150;
      });
    });
  }

  @override
  void didChangeDependencies() {
    context.ref.set(animationControllerCreator, controller);
    ModelProvider.of(context).animate();
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    controller.dispose();
    context.ref.set(animationControllerCreator, null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final models = ModelProvider.of(context).models;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).colorScheme.surfaceVariant,
      ),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(8),
      child: Stack(
        children: [
          Positioned(
            left: offset,
            width: 150,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Theme.of(context).colorScheme.background,
              ),
              child: const Text(''),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(models.length, (index) {
              final title = models[index].replaceAll('-turbo-16k', '');
              return ModelTile(
                name: title.toUpperCase(),
                onTap: () => handleTap(index),
              );
            }),
          )
        ],
      ),
    );
  }

  void handleTap(int index) {
    controller.animateTo(index.toDouble());
    ChatProvider.of(context).updateChat(models[index]);
  }
}
