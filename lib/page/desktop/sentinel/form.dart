import 'package:athena/api/sentinel.dart';
import 'package:athena/provider/chat.dart';
import 'package:athena/provider/setting.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/widget/card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

class SentinelFormPage extends StatefulWidget {
  final Sentinel? sentinel;

  const SentinelFormPage({super.key, this.sentinel});

  @override
  State<SentinelFormPage> createState() => _SentinelFormPageState();
}

class _ActionButtons extends ConsumerWidget {
  final Sentinel? sentinel;
  final void Function(WidgetRef)? onDelete;
  final void Function(WidgetRef)? onStore;

  const _ActionButtons({this.onDelete, this.sentinel, this.onStore});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final error = colorScheme.error;
    final style = ElevatedButton.styleFrom(foregroundColor: error);
    final delete = ElevatedButton(
      onPressed: () => handleDelete(ref),
      style: style,
      child: const Text('Delete'),
    );
    final store = ElevatedButton(
      onPressed: () => handleStore(ref),
      child: const Text('Save'),
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

class _Input extends StatelessWidget {
  final TextEditingController controller;
  final Future<void> Function()? onRefresh;

  const _Input({required this.controller, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final onSurface = colorScheme.onSurface;
    final borderColor = onSurface.withValues(alpha: 0.2);
    final decoration = BoxDecoration(
      border: Border.all(color: borderColor),
      borderRadius: BorderRadius.circular(8),
    );
    const inputDecoration = InputDecoration.collapsed(
      hintText: 'Will generate after submit',
    );
    final textField = TextField(
      controller: controller,
      decoration: inputDecoration,
    );
    final refreshIcon = _RefreshIcon(onTap: onRefresh);
    final children = [
      Expanded(child: textField),
      const SizedBox(width: 8),
      refreshIcon,
    ];
    final row = Row(children: children);
    return Container(
      decoration: decoration,
      padding: const EdgeInsets.all(12),
      child: row,
    );
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

class _SentinelFormPageState extends State<SentinelFormPage> {
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
    final colorScheme = Theme.of(context).colorScheme;
    final onSurface = colorScheme.onSurface;
    final consumer = Consumer(builder: (context, ref, child) {
      return _Avatar(
        avatar: avatar,
        onRefresh: () => refresh(ref, key: 'avatar'),
      );
    });
    final boxDecoration2 = BoxDecoration(
      border: Border.all(color: onSurface.withValues(alpha: 0.2)),
      borderRadius: BorderRadius.circular(8),
    );
    const inputDecoration = InputDecoration.collapsed(
      hintText: 'Input Prompt Here',
    );
    final textField = TextField(
      controller: promptController,
      decoration: inputDecoration,
      maxLines: 6,
    );
    final consumer2 = Consumer(builder: (context, ref, child) {
      var children = [
        if (loading)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: _Loading(),
          ),
        const Text('Generate'),
      ];
      return TextButton(
        onPressed: () => generate(ref),
        child: Row(children: children),
      );
    });
    var actionButtons = _ActionButtons(
      onDelete: delete,
      sentinel: widget.sentinel,
      onStore: store,
    );
    var row = Row(
      children: [
        const Expanded(child: Text('Description')),
        const SizedBox(width: 24),
        Expanded(
          flex: 2,
          child: Consumer(builder: (context, ref, child) {
            return _Input(
              controller: descriptionController,
              onRefresh: () => refresh(ref, key: 'description'),
            );
          }),
        )
      ],
    );
    var row2 = Row(
      children: [
        const Expanded(child: Text('Name')),
        const SizedBox(width: 24),
        Expanded(
          flex: 2,
          child: Consumer(builder: (context, ref, child) {
            return _Input(
              controller: nameController,
              onRefresh: () => refresh(ref, key: 'name'),
            );
          }),
        )
      ],
    );
    var container = Container(
      decoration: boxDecoration2,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          textField,
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [consumer2],
          ),
        ],
      ),
    );
    var children2 = [
      consumer,
      container,
      const SizedBox(height: 12),
      row2,
      const SizedBox(height: 12),
      row,
      const SizedBox(height: 12),
      Consumer(builder: (context, ref, child) {
        return _Tags(tags, onRefresh: () => refresh(ref, key: 'tags'));
      }),
      const SizedBox(height: 12),
      actionButtons
    ];
    var container2 = Column(children: children2);
    final mediaQuery = MediaQuery.of(context);
    final width = mediaQuery.size.width * 0.6;
    return Dialog(child: ACard(width: width, child: container2));
  }

  void delete(WidgetRef ref) async {
    final notifier = ref.read(sentinelsNotifierProvider.notifier);
    notifier.destroy(widget.sentinel!);
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    promptController.dispose();
    super.dispose();
  }

  void generate(WidgetRef ref) async {
    if (promptController.text.isEmpty) return;
    setState(() {
      loading = true;
    });
    try {
      final setting = await ref.read(settingNotifierProvider.future);
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

class _Tag extends StatelessWidget {
  final String text;

  const _Tag(this.text);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final onSurface = colorScheme.onSurface;
    final boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(2),
      color: onSurface.withValues(alpha: 0.05),
    );
    final textStyle = TextStyle(
      color: onSurface.withValues(alpha: 0.15),
      fontSize: 12,
      fontWeight: FontWeight.w400,
    );
    final hugeIcon = HugeIcon(
      icon: HugeIcons.strokeRoundedCancel01,
      color: onSurface.withValues(alpha: 0.25),
      size: 12,
    );
    final children = [
      Text(text, style: textStyle),
      const SizedBox(width: 4),
      hugeIcon
    ];
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
    return Container(
      decoration: boxDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: row,
    );
  }
}

class _Tags extends StatelessWidget {
  final Future<void> Function()? onRefresh;
  final List<String> tags;

  const _Tags(this.tags, {required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final onSurface = colorScheme.onSurface.withValues(alpha: 0.2);
    final boxDecoration = BoxDecoration(
      border: Border.all(color: onSurface),
      borderRadius: BorderRadius.circular(8),
    );
    final wrap = Wrap(
      runSpacing: 8,
      spacing: 8,
      children: tags.map((tag) => _Tag(tag)).toList(),
    );
    final innerChildren = [
      Expanded(child: wrap),
      const SizedBox(width: 8),
      _RefreshIcon(onTap: onRefresh),
    ];
    final row = Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: innerChildren,
    );
    final container = Container(
      decoration: boxDecoration,
      padding: const EdgeInsets.all(12),
      child: row,
    );
    final children = [
      const Expanded(child: Text('Tags')),
      const SizedBox(width: 24),
      Expanded(flex: 2, child: container),
    ];
    return Row(children: children);
  }
}
