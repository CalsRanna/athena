import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// Unsent messages waiting above the composer, separate from chat history.
class QueuedMessages extends StatelessWidget {
  final List<MessageEntity> messages;

  const QueuedMessages({super.key, required this.messages});

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.inputBackground.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderFaint.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                HugeIcons.strokeRoundedClock01,
                size: 14,
                color: colors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                'Queued (${messages.length})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
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
                  style: TextStyle(fontSize: 12, color: colors.textWeak),
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
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
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
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.5,
                                  color: colors.textInput,
                                ),
                              ),
                            ),
                          if (imageCount > 0)
                            Row(
                              children: [
                                Icon(
                                  HugeIcons.strokeRoundedImage01,
                                  size: 13,
                                  color: colors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$imageCount ${imageCount == 1 ? 'image' : 'images'}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.5,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                        ],
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
