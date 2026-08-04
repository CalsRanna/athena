import 'package:athena_core/storage/key_value_store.dart';
import 'package:signals/signals.dart';

/// Agent 运行相关的设置项，由核心协调层消费。
///
/// 持久化走注入的 [KeyValueStore]（GUI=SharedPreferences，TUI=JSON 文件）。
class AgentSettings {
  AgentSettings({KeyValueStore? store}) : _store = store;

  static const _keyMaxAgentIterations = 'max_agent_iterations';

  final KeyValueStore? _store;

  final maxAgentIterations = signal(100);

  /// 从存储加载设置（启动时调用）。
  Future<void> init() async {
    final store = _store;
    if (store == null) return;
    final v = await store.getInt(_keyMaxAgentIterations);
    if (v != null) {
      maxAgentIterations.value = v;
    }
  }

  /// 更新最大 Agent 迭代次数。
  Future<void> updateMaxAgentIterations(int max) async {
    maxAgentIterations.value = max;
    await _store?.setInt(_keyMaxAgentIterations, max);
  }
}
