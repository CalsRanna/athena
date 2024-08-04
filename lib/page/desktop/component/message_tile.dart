import 'package:athena/schema/chat.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:markdown/markdown.dart' as md;

class CodeElementBuilder extends MarkdownElementBuilder {
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
          const Positioned(
            right: 12,
            top: 12,
            child: Icon(Icons.copy, size: 12),
          ),
      ],
    );
  }
}

class MessageTile extends StatefulWidget {
  final Message message;

  final bool showToolbar;
  final void Function()? onDeleted;
  final void Function()? onEdited;
  final void Function()? onRegenerated;
  const MessageTile({
    super.key,
    required this.message,
    this.showToolbar = true,
    this.onDeleted,
    this.onEdited,
    this.onRegenerated,
  });

  @override
  State<MessageTile> createState() => _MessageTileState();
}

class _MessageTileState extends State<MessageTile> {
  double opacity = 0.0;
  @override
  Widget build(BuildContext context) {
    Widget child;
    if (widget.message.role == 'user') {
      child = _UserMessage(content: widget.message.content, opacity: opacity);
    } else {
      child = _AssistantMessage(
        content: widget.message.content,
        opacity: opacity,
      );
    }
    return MouseRegion(
      onEnter: handleEnter,
      onExit: handleExit,
      child: child,
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
}

class _AssistantMessage extends StatelessWidget {
  final String content;
  final double opacity;
  const _AssistantMessage({required this.content, this.opacity = 0.0});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final onSurface = colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipOval(
              child: Image.asset(
                'asset/image/launcher_icon_ios_512x512.jpg',
                height: 32,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SelectionArea(
                child: MarkdownBody(
                  builders: {'code': CodeElementBuilder()},
                  data: content,
                ),
              ),
            ),
          ],
        ),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: opacity,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 40, top: 4.0),
            child: Row(
              children: [
                Icon(Icons.copy, size: 12, color: onSurface.withOpacity(0.2)),
                const SizedBox(width: 8),
                Icon(Icons.edit, size: 12, color: onSurface.withOpacity(0.2)),
                const SizedBox(width: 8),
                Icon(Icons.refresh,
                    size: 12, color: onSurface.withOpacity(0.2)),
                const SizedBox(width: 8),
                Icon(Icons.auto_awesome_outlined,
                    size: 12, color: onSurface.withOpacity(0.2)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _UserMessage extends StatelessWidget {
  final String content;
  final double opacity;
  const _UserMessage({required this.content, this.opacity = 0.0});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final surfaceContainer = colorScheme.surfaceContainer;
    final onSurface = colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: surfaceContainer,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: SelectableText(content),
        ),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: opacity,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 12, top: 4.0),
            child: Row(
              children: [
                Icon(Icons.edit, size: 12, color: onSurface.withOpacity(0.2)),
                const SizedBox(width: 8),
                Icon(Icons.refresh,
                    size: 12, color: onSurface.withOpacity(0.2)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
