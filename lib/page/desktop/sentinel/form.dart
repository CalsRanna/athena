import 'package:athena/api/sentinel.dart';
import 'package:athena/provider/sentinel.dart';
import 'package:athena/provider/setting.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/form_tile_label.dart';
import 'package:athena/widget/input.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:athena/widget/tag.dart';
import 'package:athena/widget/window_button.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

@RoutePage()
class DesktopSentinelFormPage extends StatefulWidget {
  final Sentinel? sentinel;

  const DesktopSentinelFormPage({super.key, this.sentinel});

  @override
  State<DesktopSentinelFormPage> createState() =>
      _DesktopSentinelFormPageState();
}

class _ActionButtons extends ConsumerWidget {
  final Sentinel? sentinel;
  final void Function(WidgetRef)? onDelete;
  final void Function(WidgetRef)? onStore;

  const _ActionButtons({this.onDelete, this.sentinel, this.onStore});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const edgeInsets = EdgeInsets.symmetric(horizontal: 16);
    final delete = ASecondaryButton(
      onTap: () => handleDelete(ref),
      child: Padding(
        padding: edgeInsets,
        child: const Text('Cancel', style: TextStyle(color: Colors.white)),
      ),
    );
    final store = APrimaryButton(
      onTap: () => handleStore(ref),
      child: Padding(padding: edgeInsets, child: const Text('Save')),
    );
    final children = [
      if (sentinel != null) delete,
      const SizedBox(width: 12),
      store,
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: children,
    );
  }

  void handleDelete(WidgetRef ref) async {
    onDelete?.call(ref);
  }

  void handleStore(WidgetRef ref) async {
    onStore?.call(ref);
  }
}

class _Avatar extends StatelessWidget {
  final String avatar;
  final Future<void> Function()? onRefresh;

  const _Avatar({required this.avatar, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final text = Text(
      avatar.isEmpty ? '🤖' : avatar,
      style: const TextStyle(fontSize: 64, height: 1),
    );
    final container = Container(
      alignment: Alignment.center,
      height: 96,
      width: 96,
      child: text,
    );
    final icon = Positioned(
      right: 8,
      bottom: 8,
      child: _RefreshIcon(onTap: onRefresh),
    );
    return Stack(children: [container, icon]);
  }
}

class _Loading extends StatelessWidget {
  final double size;

  const _Loading({this.size = 16});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: const CircularProgressIndicator(strokeWidth: 2),
    );
  }
}

class _RefreshIcon extends StatefulWidget {
  final Future<void> Function()? onTap;

  const _RefreshIcon({this.onTap});

  @override
  State<_RefreshIcon> createState() => _RefreshIconState();
}

class _RefreshIconState extends State<_RefreshIcon> {
  bool hover = false;
  bool loading = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final onSurface = colorScheme.onSurface.withValues(alpha: 0.2);
    final primary = colorScheme.primary;
    const size = 16.0;
    const indicator = _Loading(size: size);
    final hugeIcon = HugeIcon(
      color: hover ? primary : onSurface,
      icon: HugeIcons.strokeRoundedRepeat,
      size: size,
    );
    final mouseRegion = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: handleEnter,
      onExit: handleExit,
      child: loading ? indicator : hugeIcon,
    );
    return GestureDetector(onTap: handleTap, child: mouseRegion);
  }

  void handleEnter(PointerEnterEvent event) {
    setState(() {
      hover = true;
    });
  }

  void handleExit(PointerExitEvent event) {
    setState(() {
      hover = false;
    });
  }

  Future<void> handleTap() async {
    if (loading) return;
    setState(() {
      loading = true;
    });
    await widget.onTap?.call();
    setState(() {
      loading = false;
    });
  }
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
    final consumer = Consumer(builder: (context, ref, child) {
      return _Avatar(
        avatar: avatar,
        onRefresh: () => refresh(ref, key: 'avatar'),
      );
    });
    const inputDecoration = InputDecoration.collapsed(
      hintText: 'Input Prompt Here',
    );
    final promptTextField = TextField(
      controller: promptController,
      decoration: inputDecoration,
      maxLines: null,
      style: const TextStyle(color: Colors.white),
    );
    var actionButtons = _ActionButtons(
      onDelete: (_) => popPage(),
      sentinel: widget.sentinel,
      onStore: store,
    );
    var row = Row(
      children: [
        const SizedBox(width: 160, child: AFormTileLabel(title: 'Description')),
        const SizedBox(width: 24),
        Expanded(
          child: Consumer(builder: (context, ref, child) {
            return AInput(
              controller: descriptionController,
              minLines: 4,
              // onRefresh: () => refresh(ref, key: 'description'),
            );
          }),
        )
      ],
    );
    var row2 = Row(
      children: [
        const SizedBox(width: 160, child: AFormTileLabel(title: 'Name')),
        const SizedBox(width: 24),
        Expanded(
          child: Consumer(builder: (context, ref, child) {
            return AInput(
              controller: nameController,
              // onRefresh: () => refresh(ref, key: 'name'),
            );
          }),
        )
      ],
    );
    var children2 = [
      consumer,
      const SizedBox(height: 12),
      Consumer(builder: (context, ref, child) {
        return _Tags(tags, onRefresh: () => refresh(ref, key: 'tags'));
      }),
      const SizedBox(height: 12),
      row2,
      const SizedBox(height: 12),
      row,
      const SizedBox(height: 12),
      actionButtons
    ];
    var container2 = Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(children: children2),
    );
    return AScaffold(
      body: Column(
        children: [
          _buildPageHeader(context),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: Color(0xFFADADAD).withValues(alpha: 0.6),
                      ),
                      height: double.infinity,
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(child: promptTextField),
                          const SizedBox(height: 16),
                          ATextButton(text: 'Generate', onTap: generate),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                      child: Stack(
                    children: [
                      container2,
                      if (loading)
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            color: Color(0xFFADADAD).withValues(alpha: 0.5),
                          ),
                          child: Center(
                            child:
                                CircularProgressIndicator(color: Colors.white),
                          ),
                        ),
                    ],
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageHeader(BuildContext context) {
    var icon = Icon(
      HugeIcons.strokeRoundedArrowTurnBackward,
      color: Colors.white,
      size: 24,
    );
    var gestureDetector = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: popPage,
      child: icon,
    );
    var container = Container(
      height: 50,
      width: 120,
      alignment: Alignment.centerRight,
      child: gestureDetector,
    );
    var stackChildren = [
      container,
      const Positioned(left: 16, top: 18, child: MacWindowButton())
    ];
    var title = widget.sentinel?.name ?? 'New Sentinel';
    var titleText = Text(title, style: TextStyle(color: Colors.white));
    var rowChildren = [
      Stack(children: stackChildren),
      const SizedBox(width: 16),
      Expanded(child: titleText),
    ];
    return Row(children: rowChildren);
  }

  void popPage() async {
    AutoRouter.of(context).maybePop();
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
    var container = ProviderScope.containerOf(context);
    try {
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

  Future<void> refresh(WidgetRef ref, {required String key}) async {
    if (promptController.text.isEmpty) return;
    final setting = await ref.read(settingNotifierProvider.future);
    final sentinel = await SentinelApi().generate(
      promptController.text,
      model: setting.model,
    );
    if (key == 'avatar') {
      avatar = sentinel.avatar;
      setState(() {});
    }
    if (key == 'name') {
      nameController.text = sentinel.name;
    }
    if (key == 'description') {
      descriptionController.text = sentinel.description;
    }
    if (key == 'tags') {
      tags = sentinel.tags;
      setState(() {});
    }
  }

  void store(WidgetRef ref) async {
    if (promptController.text.isEmpty) return;
    final notifier = ref.read(sentinelsNotifierProvider.notifier);
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
    Navigator.of(context).pop();
  }
}

class _Tags extends StatelessWidget {
  final Future<void> Function()? onRefresh;
  final List<String> tags;

  const _Tags(this.tags, {required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      runSpacing: 8,
      spacing: 8,
      children: tags.map((tag) => ATag(text: tag)).toList(),
    );
  }
}
