import 'package:athena/entity/chat_entity.dart';
import 'package:athena/repository/chat_repository.dart';

/// Token 用量追踪服务。
///
/// 负责原子累加 chat 的 token_total 并覆盖写 context_tokens / cached_tokens 快照。
class TokenUsageService {
  final ChatRepository _chatRepo;

  TokenUsageService({required ChatRepository chatRepo}) : _chatRepo = chatRepo;

  /// 原子累加 [tokenDelta] 并覆盖写 context_tokens/cached_tokens 快照。
  /// 不触碰 updatedAt。返回 DB 最新行（跨并发写者一致）。
  Future<ChatEntity?> recordUsage(
    ChatEntity chat, {
    required int tokenDelta,
    required int contextTokens,
    required int cachedTokens,
  }) async {
    if (chat.id == null) return chat;
    await _chatRepo.recordUsage(
      chat.id!,
      tokenDelta,
      contextTokens,
      cachedTokens,
    );
    return _chatRepo.getChatById(chat.id!);
  }
}
