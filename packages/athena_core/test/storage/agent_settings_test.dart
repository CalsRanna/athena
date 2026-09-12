import 'package:athena_core/storage/agent_settings.dart';
import 'package:athena_core/storage/key_value_store.dart';
import 'package:test/test.dart';

class _Store implements KeyValueStore {
  final values = <String, Object>{};
  @override
  Future<int?> getInt(String key) async => values[key] as int?;
  @override
  Future<String?> getString(String key) async => values[key] as String?;
  @override
  Future<void> setInt(String key, int value) async {
    values[key] = value;
  }

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }

  @override
  Future<Set<String>> getKeys() async => values.keys.toSet();
}

void main() {
  test(
    'AI approval defaults on, persists disabling and restores after reset',
    () async {
      final store = _Store();
      final settings = AgentSettings(store: store);
      await settings.init();
      expect(settings.aiApprovalEnabled.value, isTrue);
      await settings.updateAiApprovalEnabled(false);
      final reloaded = AgentSettings(store: store);
      await reloaded.init();
      expect(reloaded.aiApprovalEnabled.value, isFalse);
      await reloaded.updateAiApprovalEnabled(true);
      await settings.init();
      expect(settings.aiApprovalEnabled.value, isTrue);
      await settings.updateAiApprovalEnabled(false);
      store.values.clear();
      await settings.init();
      expect(settings.aiApprovalEnabled.value, isTrue);
    },
  );
}
