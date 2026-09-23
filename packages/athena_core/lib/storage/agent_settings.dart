import 'package:athena_core/entity/approval_mode.dart';
import 'package:athena_core/storage/key_value_store.dart';
import 'package:signals/signals.dart';

/// Agent 运行相关的设置项，由核心协调层消费。
///
/// 持久化走注入的 [KeyValueStore]（GUI=SharedPreferences，TUI=JSON 文件）。
class AgentSettings {
  AgentSettings({KeyValueStore? store}) : _store = store;

  static const _keyMaxAgentIterations = 'max_agent_iterations';
  static const _keyApprovalMode = 'approval_mode';
  static const _keyBackgroundTaskReports = 'background_task_reports';

  /// 旧的布尔开关（0 关 / 1 开），只在还没写过 [_keyApprovalMode] 时读一次做迁移。
  static const _keyAiApprovalEnabled = 'ai_approval_enabled';

  final KeyValueStore? _store;

  final maxAgentIterations = signal(100);
  final approvalMode = signal(ApprovalMode.aiReview);

  /// 后台任务结束后是否自动起一个汇报回合。
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
    final mode = ApprovalMode.fromKey(await store.getString(_keyApprovalMode));
    if (mode != null) {
      approvalMode.value = mode;
    } else {
      // 迁移旧开关：显式关过才是手动，否则沿用默认的 AI 审核
      approvalMode.value = await store.getInt(_keyAiApprovalEnabled) == 0
          ? ApprovalMode.manual
          : ApprovalMode.aiReview;
    }
    final reports = await store.getInt(_keyBackgroundTaskReports);
    if (reports != null) {
      backgroundTaskReports.value = reports != 0;
    }
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

  Future<void> updateApprovalMode(ApprovalMode mode) async {
    await _store?.setString(_keyApprovalMode, mode.key);
    approvalMode.value = mode;
  }
}
