import 'package:athena/api/sentinel.dart';
import 'package:athena/provider/sentinel.dart';
import 'package:athena/provider/setting.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/form_tile_label.dart';
import 'package:athena/widget/input.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:athena/widget/tag.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@RoutePage()
class DesktopSentinelFormPage extends StatefulWidget {
  final Sentinel? sentinel;

  const DesktopSentinelFormPage({super.key, this.sentinel});

  @override
  State<DesktopSentinelFormPage> createState() =>
      _DesktopSentinelFormPageState();
}

class _DesktopSentinelFormPageState extends State<DesktopSentinelFormPage> {
  String avatar = '';
  String name = '';
  String description = '';
  List<String> tags = [];

  final promptController = TextEditingController();
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  bool loading = false;

  @override
  Widget build(BuildContext context) {
    var appBar = AAppBar(
      leading: DesktopPopButton(),
      title: _buildPageHeader(context),
    );
    var children = [
      Expanded(child: _buildPromptInput()),
      const SizedBox(width: 16),
      Expanded(child: _buildInformationInput()),
    ];
    var padding = Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(children: children),
    );
    return AScaffold(appBar: appBar, body: padding);
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
      var container = ProviderScope.containerOf(context);
      final setting = await container.read(settingNotifierProvider.future);
      var sentinelApi = SentinelApi();
      var text = promptController.text;
      var model = setting.model;
      final sentinel = await sentinelApi.generate(text, model: model);
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
      const SizedBox(width: 160, child: AFormTileLabel(title: 'Description')),
      const SizedBox(width: 24),
      Expanded(child: AInput(controller: descriptionController, minLines: 4))
    ];
    return Row(children: children);
  }

  Widget _buildInformationInput() {
    var children = [
      _buildAvatarInput(),
      const SizedBox(height: 12),
      _buildTagsInput(),
      const SizedBox(height: 12),
      _buildNameInput(),
      const SizedBox(height: 12),
      _buildDescriptionInput(),
      const SizedBox(height: 12),
      _buildButtons(),
      const SizedBox(height: 12),
      if (loading) _buildLoadingIndicator(),
    ];
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(children: children),
    );
  }

  Widget _buildLoadingIndicator() {
    var children = [
      CircularProgressIndicator(color: Colors.white),
      const SizedBox(width: 12),
      Text('Generating...', style: TextStyle(color: Colors.white)),
    ];
    return Row(children: children);
  }

  Widget _buildNameInput() {
    var children = [
      const SizedBox(width: 160, child: AFormTileLabel(title: 'Name')),
      const SizedBox(width: 24),
      Expanded(child: AInput(controller: nameController))
    ];
    return Row(children: children);
  }

  Widget _buildPageHeader(BuildContext context) {
    var title = widget.sentinel?.name ?? 'New Sentinel';
    var rowChildren = [
      const SizedBox(width: 16),
      Text(title, style: TextStyle(color: Colors.white)),
      const SizedBox(width: 16),
    ];
    return Row(children: rowChildren);
  }

  Widget _buildPromptInput() {
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      color: Color(0xFFADADAD).withValues(alpha: 0.6),
    );
    const inputDecoration = InputDecoration.collapsed(
      hintText: 'Input Prompt Here',
    );
    final promptTextField = TextField(
      controller: promptController,
      decoration: inputDecoration,
      maxLines: null,
      style: const TextStyle(color: Colors.white),
    );
    var children = [
      Expanded(child: promptTextField),
      const SizedBox(height: 16),
      ATextButton(text: 'Generate', onTap: generate),
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
    return Wrap(
      alignment: WrapAlignment.center,
      runSpacing: 8,
      spacing: 8,
      children: tags.map((tag) => ATag(text: tag)).toList(),
    );
  }
}
