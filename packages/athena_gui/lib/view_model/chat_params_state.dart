import 'package:athena_core/entity/approval_mode.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/service/chat_update_service.dart';
import 'package:athena_gui/view_model/model_view_model.dart';
import 'package:athena_gui/view_model/sentinel_view_model.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:signals/signals.dart';

/// 当前 composer 指向的那条对话（或草稿）的参数视图。
///
/// 这几个值有两副面孔：选中已落盘的对话时它们是**那条对话的字段**，处于草稿态时它们
/// 是**下一条对话的起点**。差别全在写入口径上，也是这块最容易出错的地方：
///
/// - **切换对话时要八个值一起换**，漏一个就会让上一条的模型/角色串到这一条。
///   所以入口是 [setFromChat] 而不是八个散落的赋值；
/// - **角色要过 [displaySentinel]**：显式选择「不用角色」（[ChatEntity.noSentinelId]）
///   得显示成 directChatSentinel，而不是当成「没选」去回退默认角色；
/// - **草稿起点只从两处取**：设置里的默认模型与审批档位，加上会话默认（保留策略、
///   温度、推理强度）。只有工作文件夹与角色会从来源对话继承——审批档位刻意不继承
///   （见 [resetToDraftDefaults]）。
class ChatParamsState {
  ChatParamsState({
    required SettingViewModel settingViewModel,
    required ModelViewModel modelViewModel,
    required SentinelViewModel sentinelViewModel,
    required ChatUpdateService supportService,
  }) : _settingViewModel = settingViewModel,
       _modelViewModel = modelViewModel,
       _sentinelViewModel = sentinelViewModel,
       _supportService = supportService;

  /// 新对话的默认上下文保留策略。-1 = 自动管理（compact）。
  static const int defaultDraftRetention = -1;

  /// 新对话的默认温度。
  static const double defaultDraftTemperature = 1.0;

  final SettingViewModel _settingViewModel;
  final ModelViewModel _modelViewModel;
  final SentinelViewModel _sentinelViewModel;
  final ChatUpdateService _supportService;

  final currentModel = signal<ModelEntity?>(null);
  final currentProvider = signal<ProviderEntity?>(null);
  final currentSentinel = signal<SentinelEntity?>(null);
  final currentRetention = signal(defaultDraftRetention);
  final currentTemperature = signal(defaultDraftTemperature);
  final currentReasoningEffort = signal<String>(
    ChatEntity.defaultReasoningEffort,
  );
  final currentWorkspacePath = signal<String?>(null);
  final currentApprovalMode = signal(ApprovalMode.defaultMode);

  /// 会话里存的角色 id 在该会话上的显示形态。
  ///
  /// 显式「不用角色」与「解析不到角色」是两件事：前者要显示成 directChatSentinel
  /// （用户选的），后者才回退默认。
  static SentinelEntity? displaySentinel(
    ChatEntity chat,
    SentinelEntity? sentinel,
  ) => chat.hasSentinel ? sentinel : SentinelViewModel.directChatSentinel;

  /// 切到某条已落盘的对话：八个值一次换齐。
  void setFromChat(
    ChatEntity chat, {
    required ModelEntity? model,
    required ProviderEntity? provider,
    required SentinelEntity? sentinel,
  }) {
    currentModel.value = model;
    currentProvider.value = provider;
    currentSentinel.value = displaySentinel(chat, sentinel);
    currentRetention.value = chat.retention;
    currentTemperature.value = chat.temperature;
    currentReasoningEffort.value = chat.reasoningEffort;
    currentWorkspacePath.value = chat.workspacePath;
    currentApprovalMode.value = chat.approvalMode;
  }

  /// 只换模型与它对应的 provider（用户改档、或草稿初值）。
  Future<void> setModel(ModelEntity model) async {
    currentModel.value = model;
    currentProvider.value = await _supportService.getProviderForModel(
      model.providerId,
    );
  }

  void setSentinel(SentinelEntity sentinel) => currentSentinel.value = sentinel;

  void setRetention(int retention) => currentRetention.value = retention;

  void setTemperature(double temperature) =>
      currentTemperature.value = temperature;

  void setReasoningEffort(String effort) =>
      currentReasoningEffort.value = effort;

  void setWorkspacePath(String? path) => currentWorkspacePath.value = path;

  void setApprovalMode(ApprovalMode mode) => currentApprovalMode.value = mode;

  /// 进入草稿态：把八个值重置成「下一条对话的起点」。
  ///
  /// [inheritFrom] 是点「新对话」时所在的那条对话（可以没有）。
  Future<void> resetToDraftDefaults(
    ChatEntity? inheritFrom, {
    bool inheritWorkspace = true,
  }) async {
    currentModel.value = _settingViewModel.chatModel.value;
    currentProvider.value = _settingViewModel.chatModelProvider.value;

    if (currentModel.value == null) {
      await _modelViewModel.loadEnabledModels();
      currentModel.value = _modelViewModel.enabledModels.value.firstOrNull;
      if (currentModel.value != null) {
        currentProvider.value = await _supportService.getProviderForModel(
          currentModel.value!.providerId,
        );
      }
    }

    if (_sentinelViewModel.sentinels.value.isEmpty) {
      await _sentinelViewModel.getSentinels();
    }
    // 来源对话的角色已被删/解析不到时退回默认角色，与选中该对话时的显示口径
    // 一致（[displaySentinel] 也是这么兜底的）。
    final inherited = inheritFrom == null
        ? null
        : await _inheritedSentinel(inheritFrom);
    currentSentinel.value =
        inherited ?? _sentinelViewModel.defaultSentinel.value;
    currentRetention.value = defaultDraftRetention;
    currentTemperature.value = defaultDraftTemperature;
    currentReasoningEffort.value = ChatEntity.defaultReasoningEffort;
    currentWorkspacePath.value = inheritWorkspace
        ? inheritFrom?.workspacePath
        : null;
    // 审批档位不继承来源会话：它是「这条会话里我打算放行到什么程度」，从一条
    // bypass 的会话点新建对话时，用户多半正要开始改动别的项目。起点是启动时从
    // 旧全局设置播种的那一档。
    currentApprovalMode.value = _settingViewModel.newChatApprovalMode.value;
  }

  Future<SentinelEntity?> _inheritedSentinel(ChatEntity chat) async {
    if (!chat.hasSentinel) return SentinelViewModel.directChatSentinel;
    final listed = _sentinelViewModel.sentinels.value
        .where((s) => s.id == chat.sentinelId)
        .firstOrNull;
    return listed ?? await _sentinelViewModel.getSentinelById(chat.sentinelId!);
  }
}
