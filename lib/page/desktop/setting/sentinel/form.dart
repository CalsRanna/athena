import 'package:athena/provider/sentinel.dart';
import 'package:athena/schema/sentinel.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/sentinel.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/form_tile_label.dart';
import 'package:athena/widget/input.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:athena/widget/tag.dart';
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
  String avatar = '';
  List<String> tags = [];

  final promptController = TextEditingController();
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  bool loading = false;

  late final viewModel = SentinelViewModel(ref);

  @override
  Widget build(BuildContext context) {
    var children = [
      Expanded(child: _buildPromptInput()),
      const SizedBox(width: 32),
      Expanded(child: _buildInformationInput()),
    ];
    var padding = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      child: Row(children: children),
    );
    return AScaffold(body: padding);
  }

  @override
  void dispose() {
    promptController.dispose();
    super.dispose();
  }

  void generate() async {
    if (loading) return;
    if (promptController.text.isEmpty) return;
    setState(() {
      loading = true;
    });
    try {
      final sentinel = await viewModel.generateSentinel(promptController.text);
      if (sentinel == null) {
        loading = false;
        return;
      }
      nameController.text = sentinel.name;
      descriptionController.text = sentinel.description;
      avatar = sentinel.avatar;
      tags = sentinel.tags;
      loading = false;
      setState(() {});
    } catch (error) {
      loading = false;
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.sentinel != null) {
      avatar = widget.sentinel!.avatar;
      tags = widget.sentinel!.tags;

      promptController.text = widget.sentinel!.prompt;
      nameController.text = widget.sentinel!.name;
      descriptionController.text = widget.sentinel!.description;
    }
  }

  void popPage() async {
    AutoRouter.of(context).maybePop();
  }

  void store() async {
    if (promptController.text.isEmpty) return;
    var container = ProviderScope.containerOf(context);
    final notifier = container.read(sentinelsNotifierProvider.notifier);
    var sentinel = Sentinel()
      ..avatar = avatar
      ..description = descriptionController.text
      ..name = nameController.text
      ..prompt = promptController.text
      ..tags = tags;
    if (widget.sentinel != null) {
      sentinel.id = widget.sentinel!.id;
    }
    notifier.store(sentinel);
    AutoRouter.of(context).maybePop();
  }

  Widget _buildAvatarInput() {
    return Text(
      avatar.isEmpty ? '🤖' : avatar,
      style: const TextStyle(fontSize: 64, height: 1),
    );
  }

  Widget _buildButtons() {
    const edgeInsets = EdgeInsets.symmetric(horizontal: 16);
    final cancelButton = ASecondaryButton(
      onTap: popPage,
      child: Padding(padding: edgeInsets, child: const Text('Cancel')),
    );
    final storeButton = APrimaryButton(
      onTap: store,
      child: Padding(padding: edgeInsets, child: const Text('Store')),
    );
    final children = [
      cancelButton,
      const SizedBox(width: 12),
      storeButton,
    ];
    return Row(mainAxisAlignment: MainAxisAlignment.end, children: children);
  }

  Widget _buildDescriptionInput() {
    var children = [
      const SizedBox(width: 100, child: AFormTileLabel(title: 'Description')),
      const SizedBox(width: 24),
      Expanded(child: AInput(controller: descriptionController, minLines: 4))
    ];
    return Row(children: children);
  }

  Widget _buildInformationInput() {
    var children = [
      _buildAvatarInput(),
      const SizedBox(height: 12),
      Expanded(child: _buildTagsInput()),
      const SizedBox(height: 12),
      _buildNameInput(),
      const SizedBox(height: 12),
      _buildDescriptionInput(),
      const SizedBox(height: 12),
      _buildButtons(),
    ];
    return Column(children: children);
  }

  Widget _buildNameInput() {
    var children = [
      const SizedBox(width: 100, child: AFormTileLabel(title: 'Name')),
      const SizedBox(width: 24),
      Expanded(child: AInput(controller: nameController))
    ];
    return Row(children: children);
  }

  Widget _buildPromptInput() {
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      color: ColorUtil.FFADADAD.withValues(alpha: 0.6),
    );
    const inputDecoration = InputDecoration.collapsed(
      hintText: 'Input Prompt Here',
    );
    final promptTextField = TextField(
      controller: promptController,
      decoration: inputDecoration,
      maxLines: null,
      style: const TextStyle(color: ColorUtil.FFFFFFFF),
    );
    var sizedBox = SizedBox(
      height: 16,
      width: 16,
      child:
          CircularProgressIndicator(color: ColorUtil.FFFFFFFF, strokeWidth: 2),
    );
    var generateChildren = [
      if (loading) sizedBox,
      ATextButton(text: 'Generate', onTap: generate),
    ];
    var generateButton = Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: generateChildren,
    );
    var children = [
      Expanded(child: promptTextField),
      const SizedBox(height: 16),
      generateButton,
    ];
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: children,
    );
    return Container(
      decoration: boxDecoration,
      height: double.infinity,
      padding: EdgeInsets.all(16),
      child: column,
    );
  }

  Widget _buildTagsInput() {
    var border = Border.all(color: ColorUtil.FFFFFFFF.withValues(alpha: 0.2));
    var boxDecoration = BoxDecoration(
      border: border,
      borderRadius: BorderRadius.circular(24),
    );
    var wrap = Wrap(
      alignment: WrapAlignment.center,
      runSpacing: 8,
      spacing: 8,
      children: tags.map((tag) => ATag(text: tag)).toList(),
    );
    var placeholder = Text(
      'Tags will be generated here',
      style: TextStyle(color: ColorUtil.FFFFFFFF),
    );
    return Container(
      alignment: Alignment.center,
      decoration: boxDecoration,
      width: double.infinity,
      child: tags.isEmpty ? Center(child: placeholder) : wrap,
    );
  }
}
