import 'package:athena/page/desktop/home/component/sentinel_placeholder.dart';
import 'package:athena/provider/sentinel.dart';
import 'package:athena/schema/sentinel.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/sentinel.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/form_tile_label.dart';
import 'package:athena/widget/input.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@RoutePage()
class DesktopSentinelFormPage extends ConsumerStatefulWidget {
  final Sentinel? sentinel;

  const DesktopSentinelFormPage({super.key, this.sentinel});

  @override
  ConsumerState<DesktopSentinelFormPage> createState() =>
      _DesktopSentinelFormPageState();
}

class _DesktopSentinelFormPageState
    extends ConsumerState<DesktopSentinelFormPage> {
  final avatarController = TextEditingController();
  final promptController = TextEditingController();
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  bool loading = false;

  late final viewModel = SentinelViewModel(ref);
  late Sentinel sentinel = widget.sentinel ?? Sentinel();

  @override
  Widget build(BuildContext context) {
    var children = [
      Expanded(child: _buildLeftForm()),
      const SizedBox(width: 32),
      Expanded(child: _buildRightPreview()),
    ];
    var padding = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      child: Row(children: children),
    );
    return AthenaScaffold(body: padding);
  }

  @override
  void dispose() {
    avatarController.dispose();
    nameController.dispose();
    descriptionController.dispose();
    promptController.dispose();
    super.dispose();
  }

  void generate() async {
    if (loading) return;
    if (promptController.text.trim().isEmpty) {
      AthenaDialog.message('Prompt is required');
      return;
    }
    setState(() {
      loading = true;
    });
    try {
      final generatedSentinel =
          await viewModel.generateSentinel(promptController.text);
      avatarController.text = generatedSentinel.avatar;
      nameController.text = generatedSentinel.name;
      descriptionController.text = generatedSentinel.description;
      setState(() {
        loading = false;
        sentinel = generatedSentinel;
      });
    } catch (error) {
      setState(() {
        loading = false;
      });
      AthenaDialog.message(error.toString());
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.sentinel != null) {
      avatarController.addListener(_listenControllers);
      nameController.addListener(_listenControllers);
      descriptionController.addListener(_listenControllers);

      avatarController.text = widget.sentinel!.avatar;
      promptController.text = widget.sentinel!.prompt;
      nameController.text = widget.sentinel!.name;
      descriptionController.text = widget.sentinel!.description;
    }
  }

  void popPage() async {
    AutoRouter.of(context).maybePop();
  }

  void storeSentinel() async {
    if (promptController.text.isEmpty) return;
    var container = ProviderScope.containerOf(context);
    final notifier = container.read(sentinelsNotifierProvider.notifier);
    if (widget.sentinel != null) {
      sentinel.id = widget.sentinel!.id;
    }
    notifier.store(sentinel);
    AutoRouter.of(context).maybePop();
  }

  Widget _buildButtons() {
    var indicator = CircularProgressIndicator(
      color: ColorUtil.FFFFFFFF,
      strokeWidth: 2,
    );
    var generateChildren = [
      if (loading) SizedBox(height: 16, width: 16, child: indicator),
      AthenaTextButton(text: 'Generate', onTap: generate),
    ];
    var generateButton = Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: generateChildren,
    );
    const edgeInsets = EdgeInsets.symmetric(horizontal: 16);
    final cancelButton = AthenaSecondaryButton(
      onTap: popPage,
      child: Padding(padding: edgeInsets, child: const Text('Cancel')),
    );
    final storeButton = AthenaPrimaryButton(
      onTap: storeSentinel,
      child: Padding(padding: edgeInsets, child: const Text('Store')),
    );
    final children = [
      generateButton,
      const SizedBox(height: 12),
      cancelButton,
      const SizedBox(width: 12),
      storeButton,
    ];
    return Row(mainAxisAlignment: MainAxisAlignment.end, children: children);
  }

  Widget _buildLeftForm() {
    var titleTextStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      fontSize: 20,
      fontWeight: FontWeight.w500,
    );
    var avatarChildren = [
      const SizedBox(width: 120, child: AthenaFormTileLabel(title: 'Avatar')),
      Expanded(child: AthenaInput(controller: avatarController))
    ];
    var nameChildren = [
      const SizedBox(width: 120, child: AthenaFormTileLabel(title: 'Name')),
      Expanded(child: AthenaInput(controller: nameController))
    ];
    var descriptionChildren = [
      const SizedBox(
          width: 120, child: AthenaFormTileLabel(title: 'Description')),
      Expanded(child: AthenaInput(controller: descriptionController))
    ];
    const promptLabel = SizedBox(
      width: 120,
      child: AthenaFormTileLabel(title: 'Prompt'),
    );
    const promptEdgeInsets = EdgeInsets.symmetric(vertical: 16);
    var promptChildren = [
      Padding(padding: promptEdgeInsets, child: promptLabel),
      Expanded(child: _PromptInput(controller: promptController))
    ];
    var promptRow = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: promptChildren,
    );
    var leftColumnChildren = [
      Text('Form', style: titleTextStyle),
      const SizedBox(height: 12),
      Row(children: avatarChildren),
      const SizedBox(height: 12),
      Row(children: nameChildren),
      const SizedBox(height: 12),
      Row(children: descriptionChildren),
      const SizedBox(height: 12),
      Expanded(child: promptRow),
      const SizedBox(height: 12),
      _buildButtons(),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: leftColumnChildren,
    );
  }

  Widget _buildRightPreview() {
    var titleTextStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      fontSize: 20,
      fontWeight: FontWeight.w500,
    );
    var preview = Center(
      child: DesktopSentinelPlaceholder(sentinel: sentinel),
    );
    var children = [
      Text('Preview', style: titleTextStyle),
      const SizedBox(height: 12),
      Expanded(child: preview)
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  void _listenControllers() {
    var copiedSentinel = sentinel.copyWith(
      avatar: avatarController.text,
      description: descriptionController.text,
      name: nameController.text,
      prompt: promptController.text,
    );
    setState(() {
      sentinel = copiedSentinel;
    });
  }
}

class _PromptInput extends StatelessWidget {
  final TextEditingController controller;
  const _PromptInput({required this.controller});

  @override
  Widget build(BuildContext context) {
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      color: ColorUtil.FFADADAD.withValues(alpha: 0.6),
    );
    var hintTextStyle = TextStyle(
      color: ColorUtil.FFC2C2C2,
      fontSize: 14,
      height: 1.75,
    );
    var inputDecoration = InputDecoration.collapsed(
      hintStyle: hintTextStyle,
      hintText: 'Input Prompt Here',
    );
    const inputTextStyle = TextStyle(
      color: ColorUtil.FFF5F5F5,
      fontSize: 14,
      height: 1.7,
    );
    final textField = TextField(
      controller: controller,
      cursorColor: ColorUtil.FFF5F5F5,
      cursorHeight: 16,
      decoration: inputDecoration,
      maxLines: null,
      style: inputTextStyle,
    );
    return Container(
      decoration: boxDecoration,
      height: double.infinity,
      padding: EdgeInsets.all(16),
      child: textField,
    );
  }
}
