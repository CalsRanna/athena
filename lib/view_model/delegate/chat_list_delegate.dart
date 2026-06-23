import 'package:athena/entity/chat_entity.dart';
import 'package:athena/entity/chat_history_entity.dart';
import 'package:athena/entity/message_entity.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:athena/entity/provider_entity.dart';
import 'package:athena/entity/sentinel_entity.dart';
import 'package:athena/service/chat_manage_service.dart';
import 'package:athena/service/chat_support_service.dart';
import 'package:athena/view_model/model_view_model.dart';
import 'package:athena/view_model/sentinel_view_model.dart';
import 'package:athena/view_model/setting_view_model.dart';

/// 会话列表 CRUD 的委托。
///
/// 不持有 Signal，纯业务逻辑。调用方获取返回值后自行写入 Signal。
class ChatListDelegate {
  static const int defaultDraftRetention = -1;
  static const double defaultDraftTemperature = 1.0;

  final ChatManageService _manageService;
  final ChatSupportService _supportService;

  ChatListDelegate({
    required ChatManageService manageService,
    required ChatSupportService supportService,
  })  : _manageService = manageService,
        _supportService = supportService;

  /// 加载所有会话及其最后一条消息
  Future<({
    List<ChatEntity> chats,
    List<ChatHistoryEntity> histories,
  })> load() async {
    final (chats, histories) = await _manageService.getChats();
    return (chats: chats, histories: histories);
  }

  /// 创建新会话
  Future<({
    ChatEntity chat,
    ModelEntity model,
    ProviderEntity provider,
    SentinelEntity sentinel,
  })?> create({
    required ModelViewModel modelViewModel,
    required SentinelViewModel sentinelViewModel,
    required SettingViewModel settingViewModel,
  }) async {
    final model = await modelViewModel.resolveDefaultModel(
      settingViewModel.chatModelId.value,
    );
    if (model == null) return null;

    final provider = await _supportService.getProviderForModel(
      model.providerId,
    );
    if (provider == null) return null;

    if (sentinelViewModel.sentinels.value.isEmpty) {
      await sentinelViewModel.getSentinels();
    }
    final sentinel = sentinelViewModel.defaultSentinel.value;

    final chat = await _manageService.createChat(
      model: model,
      sentinel: sentinel,
      retention: defaultDraftRetention,
      temperature: defaultDraftTemperature,
    );

    return (
      chat: chat,
      model: model,
      provider: provider,
      sentinel: sentinel,
    );
  }

  /// 删除单个会话
  Future<void> remove({required ChatEntity chat}) async {
    await _manageService.deleteChat(chat.id!);
  }

  /// 批量删除会话
  Future<void> removeAll({required List<ChatEntity> chats}) async {
    await _manageService.deleteChats(chats.map((c) => c.id!).toSet());
  }

  /// 选中一个会话，返回其消息和关联数据
  Future<({
    List<MessageEntity> messages,
    ModelEntity? model,
    ProviderEntity? provider,
    SentinelEntity? sentinel,
  })> select({required ChatEntity chat}) async {
    return _manageService.selectChat(chat);
  }

  /// 切换置顶
  Future<void> togglePin({required ChatEntity chat}) async {
    await _manageService.togglePin(chat);
  }
}
