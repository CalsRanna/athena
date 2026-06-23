import 'package:athena/entity/chat_entity.dart';
import 'package:athena/entity/message_entity.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:athena/entity/provider_entity.dart';
import 'package:athena/entity/sentinel_entity.dart';
import 'package:athena/service/chat_support_service.dart';

/// 当前会话配置参数的委托。
///
/// 不持有 Signal，纯业务逻辑。调用方获取返回值后自行写入 Signal。
class ChatConfigDelegate {
  final ChatSupportService _supportService;

  ChatConfigDelegate({
    required ChatSupportService supportService,
  }) : _supportService = supportService;

  Future<ChatEntity> updateModel({
    required ModelEntity model,
    required ChatEntity chat,
  }) async {
    return _supportService.updateModel(chat, model.id!);
  }

  Future<ChatEntity> updateSentinel({
    required SentinelEntity sentinel,
    required ChatEntity chat,
  }) async {
    return _supportService.updateSentinel(chat, sentinel.id!);
  }

  Future<ChatEntity> updateRetention({
    required int retention,
    required ChatEntity chat,
  }) async {
    return _supportService.updateRetention(chat, retention);
  }

  Future<ChatEntity> updateTemperature({
    required double temperature,
    required ChatEntity chat,
  }) async {
    return _supportService.updateTemperature(chat, temperature);
  }

  Future<MessageEntity> updateExpanded({
    required MessageEntity message,
  }) async {
    return _supportService.updateExpanded(message);
  }

  Future<ProviderEntity?> resolveProvider({
    required ModelEntity model,
  }) async {
    return _supportService.getProviderForModel(model.providerId);
  }
}
