import 'package:athena_core/entity/approval_mode.dart';
import 'package:athena_core/storage/key_value_store.dart';
import 'package:signals/signals.dart';

/// Agent 运行相关的设置项，由核心协调层消费。
///
/// 持久化走注入的 [KeyValueStore]（GUI=SharedPreferences，TUI=JSON 文件）。
class AgentSettings {
  AgentSettings({KeyValueStore? store}) : _store = store;

  static const _keyMaxAgentIterations = 'max_agent_iterations';
  static const _keyBackgroundTaskReports = 'background_task_reports';

  /// 审批模式改为会话级之前的两个旧键，只在启动时读一次做播种（见 [init]）。
  static const _keyLegacyApprovalMode = 'approval_mode';

  /// 更早的布尔开关（0 关 / 1 开），在 [_keyLegacyApprovalMode] 还没写过时读。
  static const _keyLegacyAiApprovalEnabled = 'ai_approval_enabled';

  final KeyValueStore? _store;

  final maxAgentIterations = signal(100);

  /// 新建会话的审批档位起点（会话本身的值在 `ChatEntity.approvalMode`）。
  ///
  /// 不作为设置项暴露：用户在界面上改的永远是会话，这里只是「新会话从哪档
  /// 起步」。启动时由 [init] 从改为会话级之前的全局设置播种一次，之后不再
  /// 变化——因此它是进程级只读值，没有 update 方法。
  final newChatApprovalMode = signal(ApprovalMode.defaultMode);

  /// 后台任务结束后是否通知运行中的 Agent，或在空闲时自动起汇报回合。
  ///
  /// 默认开：任务跑完不回来，用户就得自己去问。但它是花钱的——汇报回合用
  /// 当前会话的模型，所以在 UI 上必须能看到这个开关的后果（默认开启）。
  final backgroundTaskReports = signal(true);

  /// 从存储加载设置（启动时调用）。
  Future<void> init() async {
    final store = _store;
    if (store == null) return;
    final v = await store.getInt(_keyMaxAgentIterations);
    if (v != null) {
      maxAgentIterations.value = v;
    }
    await _seedNewChatApprovalMode(store);
    final reports = await store.getInt(_keyBackgroundTaskReports);
    if (reports != null) {
      backgroundTaskReports.value = reports != 0;
    }
  }

  /// 用旧的全局审批设置给 [newChatApprovalMode] 播种一次，然后删掉旧键。
  ///
  /// 播种而非忽略，是为了让升级后的第一次新建会话仍落在用户设过的档位
  /// （改会话级之前，那个值是全局的，等价于「所有新会话的起点」）。两个键
  /// 都读过之后删除，避免它们以无主状态长期留在存储里。
  ///
  /// 已有会话不受影响：它们的档位在各自的会话文件里，缺列的回落默认档。
  Future<void> _seedNewChatApprovalMode(KeyValueStore store) async {
    final mode = ApprovalMode.fromKey(
      await store.getString(_keyLegacyApprovalMode),
    );
    if (mode != null) {
      newChatApprovalMode.value = mode;
    } else {
      // 更早的布尔开关：显式关过才是手动，否则沿用默认的 AI 审核。
      // 值为 null（从没写过）时同样落到默认档。
      final enabled = await store.getInt(_keyLegacyAiApprovalEnabled);
      newChatApprovalMode.value = enabled == 0
          ? ApprovalMode.manual
          : ApprovalMode.defaultMode;
    }
    await store.remove(_keyLegacyApprovalMode);
    await store.remove(_keyLegacyAiApprovalEnabled);
  }

  /// 开关后台任务完成后的自动汇报。
  Future<void> updateBackgroundTaskReports(bool enabled) async {
    backgroundTaskReports.value = enabled;
    await _store?.setInt(_keyBackgroundTaskReports, enabled ? 1 : 0);
  }

  /// 更新最大 Agent 迭代次数。
  Future<void> updateMaxAgentIterations(int max) async {
    maxAgentIterations.value = max;
    await _store?.setInt(_keyMaxAgentIterations, max);
  }
}
