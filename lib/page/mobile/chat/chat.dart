import 'dart:async';

import 'package:athena/provider/chat.dart';
import 'package:athena/provider/setting.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_markdown_latex/flutter_markdown_latex.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:markdown/markdown.dart' as md;

@RoutePage()
class ChatPage extends StatefulWidget {
  final int? id;
  const ChatPage({super.key, this.id});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ActionButton extends ConsumerWidget {
  final void Function(WidgetRef)? onTap;
  const _ActionButton({this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const hugeIcon = HugeIcon(
      icon: HugeIcons.strokeRoundedMoreHorizontal,
      color: Color(0xff000000),
    );
    const boxDecoration = BoxDecoration(
      color: Color(0xffffffff),
      shape: BoxShape.circle,
    );
    final button = Container(
      decoration: boxDecoration,
      padding: const EdgeInsets.all(8),
      child: hugeIcon,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => handleTap(ref),
      child: button,
    );
  }

  void handleTap(WidgetRef ref) {
    onTap?.call(ref);
  }
}

class _ChatPageState extends State<ChatPage> {
  final controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final children = [
      Expanded(child: _Input(controller: controller, onSubmitted: sendMessage)),
      const SizedBox(width: 16),
      _SendButton(onTap: sendMessage),
    ];
    final mediaQuery = MediaQuery.of(context);
    final input = Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, mediaQuery.padding.bottom),
      child: Row(children: children),
    );
    final actionButton = _ActionButton(onTap: destroyChat);
    final appBar = AAppBar(action: actionButton, title: const _Title());
    final body = Column(children: [const Expanded(child: _Messages()), input]);
    return AScaffold(appBar: appBar, body: body);
  }

  Future<void> destroyChat(WidgetRef ref) async {
    if (widget.id == null) return;
    final notifier = ref.read(chatsNotifierProvider.notifier);
    await notifier.destroy(widget.id!);
    if (!mounted) return;
    AutoRouter.of(context).maybePop();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> sendMessage(WidgetRef ref) async {
    final text = controller.text;
    if (text.isEmpty) return;
    controller.clear();
    final notifier = ref.read(chatNotifierProvider.notifier);
    notifier.send(text);
  }
}

class _CodeElementBuilder extends MarkdownElementBuilder {
  void handleTap(String text) {
    final data = ClipboardData(text: text);
    Clipboard.setData(data);
  }

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final multipleLines = element.textContent.split('\n').length > 1;
    var padding = const EdgeInsets.symmetric(horizontal: 4, vertical: 2);
    if (multipleLines) {
      padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
    }
    final width = multipleLines ? double.infinity : null;
    var text = Text(
      element.textContent.trim(),
      style: GoogleFonts.firaCode(fontSize: 12),
    );
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(4),
      color: const Color(0xffeeeeee),
    );
    return Container(
      decoration: boxDecoration,
      padding: padding,
      width: width,
      child: text,
    );
  }
}

class _CopyButton extends StatefulWidget {
  final void Function()? onTap;
  const _CopyButton({this.onTap});

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool copied = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = colorScheme.onSurface.withOpacity(0.4);
    Widget child = HugeIcon(
      color: color,
      icon: HugeIcons.strokeRoundedCopy01,
      size: 14.0,
    );
    if (copied) {
      final hugeIcon = HugeIcon(
        color: color,
        icon: HugeIcons.strokeRoundedTick01,
        size: 14.0,
      );
      final children = [
        hugeIcon,
        const SizedBox(width: 4),
        const Text('Copied!', style: TextStyle(fontSize: 12))
      ];
      child = Row(children: children);
    }
    final animatedSwitcher = AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: child,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: handleTap,
      child: animatedSwitcher,
    );
  }

  void handleTap() async {
    if (copied) return;
    widget.onTap?.call();
    setState(() {
      copied = true;
    });
    await Future.delayed(const Duration(seconds: 3));
    setState(() {
      copied = false;
    });
  }
}

class _Input extends ConsumerWidget {
  final TextEditingController controller;
  final void Function(WidgetRef)? onSubmitted;
  const _Input({required this.controller, this.onSubmitted});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textField = TextField(
      controller: controller,
      decoration: const InputDecoration.collapsed(hintText: 'Send a message'),
      onSubmitted: (_) => handleSubmitted(ref),
      style: const TextStyle(color: Color(0xffffffff)),
      textInputAction: TextInputAction.send,
    );
    const innerDecoration = ShapeDecoration(
      color: Color(0xff000000),
      shape: StadiumBorder(),
    );
    final body = Container(
      decoration: innerDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: textField,
    );
    final colors = [
      const Color(0xffffffff).withOpacity(0.2),
      const Color(0xff333333),
    ];
    final linearGradient = LinearGradient(
      colors: colors,
      stops: const [0, 0.4],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final shapeDecoration = ShapeDecoration(
      gradient: linearGradient,
      shape: const StadiumBorder(),
    );
    return Container(
      decoration: shapeDecoration,
      padding: const EdgeInsets.all(1),
      child: body,
    );
  }

  void handleSubmitted(WidgetRef ref) {
    final streaming = ref.read(streamingNotifierProvider);
    if (streaming) return;
    onSubmitted?.call(ref);
  }
}

class _Markdown extends StatelessWidget {
  final Message message;

  const _Markdown({required this.message});

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, child) {
      final setting = ref.watch(settingNotifierProvider).value;
      final latex = setting?.latex ?? false;
      Map<String, MarkdownElementBuilder> builders = {
        'code': _CodeElementBuilder()
      };
      if (latex) builders['latex'] = LatexElementBuilder();
      List<md.BlockSyntax> blockSyntaxes = [LatexBlockSyntax()];
      blockSyntaxes.addAll(md.ExtensionSet.gitHubFlavored.blockSyntaxes);
      final inlineSyntaxes = [LatexInlineSyntax()];
      final extensions = md.ExtensionSet(blockSyntaxes, inlineSyntaxes);
      final markdownBody = MarkdownBody(
        key: ValueKey('markdown-${latex.toString()}'),
        builders: builders,
        data: message.content,
        extensionSet: latex ? extensions : null,
      );
      return SizedBox(width: double.infinity, child: markdownBody);
    });
  }
}

class _Messages extends ConsumerWidget {
  const _Messages();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(messagesNotifierProvider);
    return state.when(
      data: data,
      error: error,
      loading: loading,
      skipLoadingOnReload: true,
    );
  }

  Widget data(List<Message> chats) {
    if (chats.isEmpty) return const SizedBox();
    final reversedChats = chats.reversed.toList();
    return ListView.separated(
      controller: ScrollController(),
      itemBuilder: (_, index) => _MessageTile(message: reversedChats[index]),
      itemCount: chats.length,
      padding: EdgeInsets.zero,
      reverse: true,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
    );
  }

  Widget error(Object error, StackTrace stackTrace) {
    return Center(child: Text(error.toString()));
  }

  Widget loading() {
    return const Center(child: CircularProgressIndicator());
  }
}

class _MessageTile extends StatelessWidget {
  final Message message;
  const _MessageTile({required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.role == 'user') {
      const color = Color(0xffffffff);
      const textStyle = TextStyle(color: color);
      final text = Text(message.content, style: textStyle);
      const edgeInsets = EdgeInsets.symmetric(horizontal: 16, vertical: 2);
      return Padding(padding: edgeInsets, child: text);
    }
    final boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      color: const Color(0xffffffff),
    );
    final button = [
      _CopyButton(onTap: copy),
      const SizedBox(width: 8),
      _RefreshButton(onTap: refresh),
    ];
    final children = [
      _Markdown(message: message),
      const SizedBox(height: 8),
      Row(children: button)
    ];
    final container = Container(
      decoration: boxDecoration,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Sentinel(),
          Expanded(child: Column(children: children)),
        ],
      ),
    );
    const edgeInsets = EdgeInsets.symmetric(horizontal: 16, vertical: 2);
    return Padding(padding: edgeInsets, child: container);
  }

  void copy() {
    Clipboard.setData(ClipboardData(text: message.content));
  }

  void refresh(WidgetRef ref) {
    final notifier = ref.read(chatNotifierProvider.notifier);
    notifier.regenerate(message);
  }
}

class _RefreshButton extends ConsumerWidget {
  final void Function(WidgetRef)? onTap;
  const _RefreshButton({this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const hugeIcon = HugeIcon(
      icon: HugeIcons.strokeRoundedRepeat,
      color: Color(0xff999999),
      size: 14,
    );
    return GestureDetector(onTap: () => handleTap(ref), child: hugeIcon);
  }

  void handleTap(WidgetRef ref) {
    onTap?.call(ref);
  }
}

class _SendButton extends ConsumerWidget {
  final void Function(WidgetRef)? onTap;
  const _SendButton({this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const sendIcon = HugeIcon(
      icon: HugeIcons.strokeRoundedSent,
      color: Color(0xffffffff),
    );
    const loading = CircularProgressIndicator.adaptive(
      backgroundColor: Color(0xffffffff),
    );
    const innerDecoration = ShapeDecoration(
      color: Color(0xff000000),
      shape: StadiumBorder(),
    );
    final streaming = ref.watch(streamingNotifierProvider);
    final body = Container(
      decoration: innerDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: streaming ? loading : sendIcon,
    );
    final colors = [
      const Color(0xffffffff).withOpacity(0.2),
      const Color(0xff333333),
    ];
    final linearGradient = LinearGradient(
      colors: colors,
      stops: const [0, 0.4],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final shapeDecoration = ShapeDecoration(
      gradient: linearGradient,
      shape: const StadiumBorder(),
    );
    final button = Container(
      decoration: shapeDecoration,
      padding: const EdgeInsets.all(1),
      child: body,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => handleTap(context, ref),
      child: button,
    );
  }

  void handleTap(BuildContext context, WidgetRef ref) {
    FocusScope.of(context).unfocus();
    final streaming = ref.read(streamingNotifierProvider);
    if (streaming) return;
    onTap?.call(ref);
  }
}

class _Sentinel extends ConsumerWidget {
  const _Sentinel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = Image.asset(
      'asset/image/launcher_icon_ios_512x512.jpg',
      height: 32,
      width: 32,
      fit: BoxFit.cover,
    );
    Widget defaultAvatar = ClipOval(child: image);
    const edgeInsets = EdgeInsets.only(right: 8);
    final sentinel = ref.watch(sentinelNotifierProvider).valueOrNull;
    if (sentinel == null) {
      return Padding(padding: edgeInsets, child: defaultAvatar);
    }
    if (sentinel.avatar.isEmpty) {
      return Padding(padding: edgeInsets, child: defaultAvatar);
    }
    final avatar = SizedBox(
      width: 32,
      height: 32,
      child: Text(sentinel.avatar),
    );
    return Padding(padding: edgeInsets, child: avatar);
  }
}

class _Title extends ConsumerWidget {
  const _Title();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(chatNotifierProvider).valueOrNull;
    return Text(chat?.title ?? '');
  }
}
