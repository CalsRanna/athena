import 'package:athena/component/button.dart';
import 'package:athena/page/desktop/home/component/placeholder.dart';
import 'package:athena/provider/chat.dart';
import 'package:athena/provider/sentinel.dart';
import 'package:athena/provider/setting.dart';
import 'package:athena/schema/chat.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_markdown_latex/flutter_markdown_latex.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:markdown/markdown.dart' as md;

class MessageList extends StatelessWidget {
  const MessageList({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, child) {
      final messages = ref.watch(messagesNotifierProvider(0)).value;
      if (messages == null) return const DesktopSentinelPlaceholder();
      if (messages.isEmpty == true) return const DesktopSentinelPlaceholder();
      return ListView.separated(
        itemBuilder: (context, index) {
          final message = messages.reversed.elementAt(index);
          return _MessageTile(message: message);
        },
        itemCount: messages.length,
        reverse: true,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        separatorBuilder: (context, index) => const SizedBox(height: 12),
      );
    });
  }
}

class _AssistantMessage extends StatelessWidget {
  final Message message;
  final double opacity;
  const _AssistantMessage({required this.message, this.opacity = 0.0});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withValues(alpha: 0.95),
      ),
      padding: EdgeInsets.fromLTRB(12, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipOval(
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF282F32),
                  ),
                  height: 36,
                  width: 36,
                  child: Consumer(builder: (context, ref, child) {
                    final sentinel =
                        ref.watch(sentinelNotifierProvider(0)).valueOrNull;
                    if (sentinel?.avatar.isNotEmpty == true) {
                      return Text(
                        sentinel!.avatar,
                        style: const TextStyle(
                            fontSize: 24, height: 1, color: Colors.white),
                      );
                    }
                    return Image.asset(
                      'asset/image/launcher_icon_ios_512x512.jpg',
                      filterQuality: FilterQuality.medium,
                      height: 36,
                    );
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  alignment: Alignment.centerLeft,
                  constraints: const BoxConstraints(minHeight: 36),
                  child: _Markdown(message: message),
                ),
              ),
              const SizedBox(width: 12),
              _Copy(onTap: handleCopy),
            ],
          ),
        ],
      ),
    );
  }

  void handleCopy() {
    Clipboard.setData(ClipboardData(text: message.content));
  }

  void handleRefresh(WidgetRef ref) {
    final notifier = ref.read(chatNotifierProvider(0).notifier);
    notifier.regenerate(message);
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
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: Theme.of(context).colorScheme.surfaceContainer,
          ),
          padding: padding,
          width: width,
          child: Text(
            element.textContent.trim(),
            style: GoogleFonts.firaCode(fontSize: 12),
          ),
        ),
        if (multipleLines)
          Positioned(
            right: 12,
            top: 12,
            child: CopyButton(onTap: () => handleTap(element.textContent)),
          ),
      ],
    );
  }
}

class _Copy extends StatefulWidget {
  final void Function()? onTap;
  const _Copy({this.onTap});

  @override
  State<_Copy> createState() => _CopyState();
}

class _CopyState extends State<_Copy> {
  bool copied = false;
  @override
  Widget build(BuildContext context) {
    final color = Colors.black.withValues(alpha: 0.25);
    Widget icon = HugeIcon(
      color: color,
      icon: HugeIcons.strokeRoundedCopy01,
      size: 16.0,
    );
    if (copied) {
      icon = HugeIcon(
        color: color,
        icon: HugeIcons.strokeRoundedTick01,
        size: 16.0,
      );
    }
    const duration = Duration(milliseconds: 200);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: handleTap,
      child: AnimatedSwitcher(duration: duration, child: icon),
    );
  }

  void handleTap() async {
    if (copied) return;
    widget.onTap?.call();
    setState(() {
      copied = true;
    });
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    setState(() {
      copied = false;
    });
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
      return MarkdownBody(
        key: ValueKey('markdown-${latex.toString()}'),
        builders: builders,
        data: message.content,
        extensionSet: latex ? extensions : null,
      );
    });
  }
}

class _MessageTile extends StatefulWidget {
  final Message message;

  const _MessageTile({required this.message});

  @override
  State<_MessageTile> createState() => _MessageTileState();
}

class _MessageTileState extends State<_MessageTile> {
  double opacity = 0.0;
  @override
  Widget build(BuildContext context) {
    Widget child;
    if (widget.message.role == 'user') {
      child = _UserMessage(content: widget.message.content, opacity: opacity);
    } else {
      child = _AssistantMessage(message: widget.message, opacity: opacity);
    }
    return MouseRegion(
      onEnter: handleEnter,
      onExit: handleExit,
      child: child,
    );
  }

  void copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primaryContainer = colorScheme.primaryContainer;
    final onPrimaryContainer = colorScheme.onPrimaryContainer;
    await Clipboard.setData(ClipboardData(text: widget.message.content));
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: primaryContainer,
        behavior: SnackBarBehavior.floating,
        content: Text('已复制', style: TextStyle(color: onPrimaryContainer)),
        width: 75,
      ),
    );
  }

  void handleEnter(PointerEnterEvent event) {
    setState(() {
      opacity = 1.0;
    });
  }

  void handleExit(PointerExitEvent event) {
    setState(() {
      opacity = 0.0;
    });
  }
}

class _UserMessage extends StatelessWidget {
  final String content;
  final double opacity;
  const _UserMessage({required this.content, this.opacity = 0.0});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipOval(
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.95),
              ),
              height: 36,
              width: 36,
              child: Text(
                'CA',
                style: const TextStyle(fontSize: 14, height: 1),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              alignment: Alignment.centerLeft,
              constraints: BoxConstraints(minHeight: 36),
              child: Text(
                content,
                style: TextStyle(color: Color(0xFFCACACA)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            height: 24,
            width: 24,
            padding: const EdgeInsets.all(6),
            child: Icon(HugeIcons.strokeRoundedRefresh, size: 12),
          ),
        ],
      ),
    );
  }

  void handleTap() {
    Clipboard.setData(ClipboardData(text: content));
  }
}
