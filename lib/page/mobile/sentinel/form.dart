import 'package:athena/provider/sentinel.dart';
import 'package:athena/schema/sentinel.dart';
import 'package:athena/view_model/sentinel.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/form_tile_label.dart';
import 'package:athena/widget/input.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

@RoutePage()
class MobileSentinelFormPage extends ConsumerStatefulWidget {
  final Sentinel? sentinel;
  const MobileSentinelFormPage({super.key, this.sentinel});

  @override
  ConsumerState<MobileSentinelFormPage> createState() =>
      _MobileSentinelFormPageState();
}

class _MobileSentinelFormPageState
    extends ConsumerState<MobileSentinelFormPage> {
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final promptController = TextEditingController();

  late final viewModel = SentinelViewModel(ref);

  @override
  Widget build(BuildContext context) {
    var children = [
      const AFormTileLabel.large(title: 'Prompt'),
      const SizedBox(height: 12),
      AInput(controller: promptController, maxLines: 8, minLines: 8),
      const SizedBox(height: 32),
      _buildNameLabel(),
      const SizedBox(height: 12),
      AInput(controller: nameController),
      const SizedBox(height: 16),
      _buildDescriptionLabel(),
      const SizedBox(height: 12),
      AInput(controller: descriptionController, maxLines: 4, minLines: 4),
      const SizedBox(height: 32),
      Row(
        children: [
          Expanded(child: _buildStoreButton()),
          const SizedBox(width: 8),
          Expanded(child: _buildGenerateButton()),
        ],
      ),
    ];
    var bottom = MediaQuery.paddingOf(context).bottom;
    var listView = ListView(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottom),
      children: children,
    );
    return AScaffold(
      appBar: AAppBar(title: Text(widget.sentinel?.name ?? 'New Sentinel')),
      body: listView,
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    promptController.dispose();
    super.dispose();
  }

  Future<void> generateSentinel() async {
    if (promptController.text.isEmpty) {
      ADialog.message('Prompt is required');
    } else {
      ADialog.loading();
      var sentinel = await viewModel.generateSentinel(promptController.text);
      if (sentinel == null) {
        ADialog.dismiss();
        return;
      }
      nameController.text = sentinel.name;
      descriptionController.text = sentinel.description;
      ADialog.dismiss();
    }
  }

  Future<void> generateSentinelDescription() async {
    if (promptController.text.isEmpty) {
      ADialog.message('Prompt is required');
    } else {
      ADialog.loading();
      var sentinel = await viewModel.generateSentinel(promptController.text);
      if (sentinel == null) {
        ADialog.dismiss();
        return;
      }
      descriptionController.text = sentinel.description;
      ADialog.dismiss();
    }
  }

  Future<void> generateSentinelName() async {
    if (promptController.text.isEmpty) {
      ADialog.message('Prompt is required');
    } else {
      ADialog.loading();
      var sentinel = await viewModel.generateSentinel(promptController.text);
      if (sentinel == null) {
        ADialog.dismiss();
        return;
      }
      nameController.text = sentinel.name;
      ADialog.dismiss();
    }
  }

  @override
  void initState() {
    super.initState();
    nameController.text = widget.sentinel?.name ?? '';
    descriptionController.text = widget.sentinel?.description ?? '';
    promptController.text = widget.sentinel?.prompt ?? '';
  }

  Future<void> storeSentinel() async {
    var message = _validate();
    if (message != null) return ADialog.success(message);
    if (widget.sentinel == null) return _store();
    _update();
  }

  Widget _buildDescriptionLabel() {
    const icon = Icon(
      HugeIcons.strokeRoundedAiBeautify,
      color: Colors.white,
      size: 16,
    );
    var gestureDetector = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: generateSentinelDescription,
      child: icon,
    );
    return AFormTileLabel.large(
      title: 'Description',
      trailing: gestureDetector,
    );
  }

  Widget _buildGenerateButton() {
    var textStyle = TextStyle(
      color: Color(0xFF161616),
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );
    return APrimaryButton(
      onTap: generateSentinel,
      child: Center(child: Text('Generate', style: textStyle)),
    );
  }

  Widget _buildNameLabel() {
    const icon = Icon(
      HugeIcons.strokeRoundedAiBeautify,
      color: Colors.white,
      size: 16,
    );
    var gestureDetector = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: generateSentinelName,
      child: icon,
    );
    return AFormTileLabel.large(title: 'Name', trailing: gestureDetector);
  }

  Widget _buildStoreButton() {
    var textStyle = TextStyle(
      color: Color(0xFF161616),
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );
    return APrimaryButton(
      onTap: storeSentinel,
      child: Center(child: Text('Store', style: textStyle)),
    );
  }

  Future<void> _store() async {
    var container = ProviderScope.containerOf(context);
    var provider = sentinelsNotifierProvider;
    var notifier = container.read(provider.notifier);
    var sentinel = Sentinel()
      ..name = nameController.text
      ..description = descriptionController.text
      ..prompt = promptController.text;
    await notifier.store(sentinel);
    if (!mounted) return;
    AutoRouter.of(context).maybePop();
  }

  Future<void> _update() async {
    var container = ProviderScope.containerOf(context);
    var provider = sentinelsNotifierProvider;
    var notifier = container.read(provider.notifier);
    var sentinel = widget.sentinel!.copyWith(
      name: nameController.text,
      description: descriptionController.text,
      prompt: promptController.text,
    );
    await notifier.updateSentinel(sentinel);
    if (!mounted) return;
    AutoRouter.of(context).maybePop();
  }

  String? _validate() {
    if (nameController.text.isEmpty) return 'Name is required';
    if (descriptionController.text.isEmpty) return 'Description is required';
    if (promptController.text.isEmpty) return 'Prompt is required';
    return null;
  }
}
