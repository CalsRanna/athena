import 'package:athena/provider/sentinel.dart';
import 'package:athena/router/router.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/form_tile_label.dart';
import 'package:athena/widget/input.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@RoutePage()
class MobileSentinelFormPage extends StatefulWidget {
  final Sentinel? sentinel;
  const MobileSentinelFormPage({super.key, this.sentinel});

  @override
  State<MobileSentinelFormPage> createState() => _MobileSentinelFormPageState();
}

class _MobileSentinelFormPageState extends State<MobileSentinelFormPage> {
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final promptController = TextEditingController();

  @override
  void initState() {
    super.initState();
    nameController.text = widget.sentinel?.name ?? '';
    descriptionController.text = widget.sentinel?.description ?? '';
    promptController.text = widget.sentinel?.prompt ?? '';
  }

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AScaffold(
      appBar: const AAppBar(title: Text('New Sentinel')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            16, 0, 16, MediaQuery.paddingOf(context).bottom),
        children: [
          const AFormTileLabel(title: 'Prompt'),
          const SizedBox(height: 12),
          AInput(controller: promptController, minLines: 8),
          const SizedBox(height: 32),
          const AFormTileLabel(title: 'Name'),
          const SizedBox(height: 12),
          AInput(controller: nameController),
          const SizedBox(height: 16),
          const AFormTileLabel(title: 'Description'),
          const SizedBox(height: 12),
          AInput(controller: descriptionController, minLines: 4),
          const SizedBox(height: 16),
          AOutlinedButton(
            child: Center(
                child: Text(
              'Generate',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            )),
            onTap: () => generateSentinel(context),
          ),
          const SizedBox(height: 12),
          APrimaryButton(
            child: Center(
              child: Text(
                'Store',
                style: TextStyle(
                  color: Color(0xFF161616),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            onTap: () => storeSentinel(context),
          ),
        ],
      ),
    );
  }

  Future<void> generateSentinel(BuildContext context) async {
    if (promptController.text.isEmpty) {
      ADialog.success('Prompt is required');
    } else {
      ADialog.loading();
      var container = ProviderScope.containerOf(context);
      var provider = sentinelNotifierProvider(0);
      var notifier = container.read(provider.notifier);
      var sentinel = await notifier.generate(promptController.text);
      nameController.text = sentinel.name;
      descriptionController.text = sentinel.description;
      ADialog.dismiss();
    }
  }

  Future<void> storeSentinel(BuildContext context) async {
    var message = _validate();
    if (message != null) {
      ADialog.success(message);
    } else {
      var container = ProviderScope.containerOf(context);
      var provider = sentinelsNotifierProvider;
      var notifier = container.read(provider.notifier);
      if (widget.sentinel == null) {
        var sentinel = Sentinel()
          ..name = nameController.text
          ..description = descriptionController.text
          ..prompt = promptController.text;
        await notifier.store(sentinel);
      } else {
        var sentinel = widget.sentinel!.copyWith(
          name: nameController.text,
          description: descriptionController.text,
          prompt: promptController.text,
        );
        await notifier.updateSentinel(sentinel);
      }
      if (!context.mounted) return;
      AutoRouter.of(context).maybePop();
    }
  }

  String? _validate() {
    if (nameController.text.isEmpty) return 'Name is required';
    if (descriptionController.text.isEmpty) return 'Description is required';
    if (promptController.text.isEmpty) return 'Prompt is required';
    return null;
  }
}
