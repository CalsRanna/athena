import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/message_entity.dart';

/// The committed rewind and the original input to restore in the composer.
class RewindResult {
  final ChatEntity chat;

  final MessageEntity input;
  final String snapshotPath;
  final List<String> turnStartIds;
  const RewindResult({
    required this.chat,
    required this.input,
    required this.snapshotPath,
    required this.turnStartIds,
  });
}
