import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_icons.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Unsent messages waiting above the composer, separate from chat history.
class QueuedMessages extends StatelessWidget {
  final List<MessageEntity> messages;

  /// 停掉当前轮，让这条消息立即发出。
  final void Function(MessageEntity message) onSteer;

  /// 把这条消息从排队区丢弃。
  final void Function(MessageEntity message) onDelete;

  const QueuedMessages({
    super.key,
    required this.messages,
    required this.onSteer,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.inputBackground,
        borderRadius: BorderRadius.circular(AthenaRadius.container),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                AthenaIcons.time,
                size: AthenaIcon.inlineSize,
                color: colors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                'Queued (${messages.length})',
                style: AthenaTextStyle.label.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Sent in order',
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AthenaTextStyle.caption.copyWith(
                    color: colors.textWeak,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 120),
            child: ListView.separated(
              primary: false,
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: messages.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final message = messages[index];
                final text = message.content.trim();
                final imageCount = message.imageUrls.isEmpty
                    ? 0
                    : message.imageUrls.split(',').length;
                return Row(
                  key: ObjectKey(message),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text(
                        '${index + 1}',
                        style: AthenaTextStyle.body.copyWith(
                          color: colors.textWeak,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (text.isNotEmpty)
                            Tooltip(
                              message: text,
                              child: Text(
                                text,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AthenaTextStyle.body.copyWith(
                                  color: colors.textInput,
                                ),
                              ),
                            ),
                          if (imageCount > 0)
                            Row(
                              children: [
                                Icon(
                                  LucideIcons.image,
                                  size: AthenaIcon.inlineSize,
                                  color: colors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$imageCount ${imageCount == 1 ? 'image' : 'images'}',
                                  style: AthenaTextStyle.caption.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Steer (stops current turn)',
                      child: AthenaGhostIconButton(
                        icon: LucideIcons.send,
                        onTap: () => onSteer(message),
                      ),
                    ),
                    Tooltip(
                      message: 'Delete',
                      child: AthenaGhostIconButton(
                        icon: LucideIcons.x,
                        onTap: () => onDelete(message),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
