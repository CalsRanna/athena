import 'package:athena/entity/model_entity.dart';
import 'package:athena/entity/provider_entity.dart';
import 'package:athena/repository/model_repository.dart';
import 'package:athena/repository/provider_repository.dart';
import 'package:athena/repository/sentinel_repository.dart';
import 'package:athena/service/summary_service.dart';
import 'package:athena/view_model/setting_view_model.dart';
import 'package:athena/view_model/summary_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

// 这些测试针对审计 C7：createSummary 之前使用 DateTime.now().millisecondsSinceEpoch
// 作为 int id，同毫秒创建会碰撞，导致流式写回写错记录。修复后 id 改为 String UUID。

ModelEntity _model() => ModelEntity(
      id: 1,
      name: 'm',
      modelId: 'm',
      providerId: 1,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

ProviderEntity _provider() => ProviderEntity(
      id: 1,
      name: 'p',
      baseUrl: 'http://localhost',
      apiKey: 'k',
      enabled: true,
      createdAt: DateTime(2024),
    );

class _FakeProviderRepository extends ProviderRepository {
  @override
  Future<List<ProviderEntity>> getEnabledProviders() async => [_provider()];

  @override
  Future<ProviderEntity?> getProviderById(int id) async => _provider();
}

class _FakeModelRepository extends ModelRepository {
  @override
  Future<ModelEntity?> getModelById(int id) async => _model();

  @override
  Future<List<ModelEntity>> getModelsByProviderId(int providerId) async =>
      [_model()];
}

void main() {
  setUp(() {
    final getIt = GetIt.instance;
    getIt.registerSingleton<SettingViewModel>(
      SettingViewModel(
        modelRepository: _FakeModelRepository(),
        providerRepository: _FakeProviderRepository(),
        sentinelRepository: SentinelRepository(),
      ),
    );
  });

  tearDown(() async {
    await GetIt.instance.reset();
  });

  SummaryViewModel buildViewModel() => SummaryViewModel(
        service: SummaryService(),
        modelRepository: _FakeModelRepository(),
        providerRepository: _FakeProviderRepository(),
      );

  test('C7: createSummary 生成的 id 为唯一 String（同毫秒不碰撞）', () async {
    final vm = buildViewModel();

    final ids = <String>[];
    for (var i = 0; i < 50; i++) {
      final id = await vm.createSummary('https://example.com/$i');
      expect(id, isA<String>());
      expect(id, isNotEmpty);
      ids.add(id);
    }

    expect(ids.toSet().length, ids.length, reason: 'id 必须全部唯一');
  });
}
