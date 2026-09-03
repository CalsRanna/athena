import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/repository/model_repository.dart';
import 'package:athena_core/repository/provider_repository.dart';
import 'package:athena_core/repository/sentinel_repository.dart';
import 'package:athena_core/service/llm_client.dart';
import 'package:athena_gui/service/sentinel_service.dart';
import 'package:athena_gui/view_model/sentinel_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSentinelRepository implements SentinelRepository {
  List<SentinelEntity> all = [];
  int _nextId = 1;

  @override
  Future<List<SentinelEntity>> getAllSentinels() async => List.of(all);

  @override
  Future<int> createSentinel(SentinelEntity sentinel) async {
    final id = _nextId++;
    all.add(sentinel.copyWith(id: id));
    return id;
  }

  @override
  Future<SentinelEntity?> getSentinelById(int id) async {
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }

  @override
  Future<SentinelEntity?> getSentinelByName(String name) async {
    for (final s in all) {
      if (s.name == name) return s;
    }
    return null;
  }

  @override
  Future<int> getSentinelsCount() async => all.length;

  @override
  Future<void> updateSentinel(SentinelEntity sentinel) async {}

  @override
  Future<void> deleteSentinel(int id) async {
    all.removeWhere((s) => s.id == id);
  }

  @override
  Future<void> batchCreateSentinels(List<SentinelEntity> sentinels) async {}

  @override
  Future<void> importSentinels(List<SentinelEntity> sentinels) async {}
}

class _FakeProviderRepository implements ProviderRepository {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeModelRepository implements ModelRepository {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeSentinelRepository repo;
  late SentinelViewModel viewModel;

  setUp(() {
    repo = _FakeSentinelRepository();
    viewModel = SentinelViewModel(
      sentinelRepository: repo,
      providerRepository: _FakeProviderRepository(),
      modelRepository: _FakeModelRepository(),
      sentinelService: SentinelService(llmClient: LlmClient()),
    );
  });

  group('getSentinels 可见性过滤', () {
    test('预设角色仅 Athena 展示,其余隐藏', () async {
      repo.all = [
        SentinelEntity(id: 1, name: 'Athena', isPreset: true),
        SentinelEntity(id: 2, name: '内置角色B', isPreset: true),
        SentinelEntity(id: 3, name: '自定义角色'),
      ];
      await viewModel.getSentinels();
      expect(
        viewModel.sentinels.value.map((s) => s.name).toList(),
        ['Athena', '自定义角色'],
      );
    });

    test('库为空时创建默认 Athena', () async {
      await viewModel.getSentinels();
      expect(viewModel.sentinels.value.single.name, 'Athena');
      expect(await repo.getSentinelsCount(), 1);
    });

    test('全部为隐藏预设时兜底默认实体', () async {
      repo.all = [
        SentinelEntity(id: 1, name: '内置角色B', isPreset: true),
      ];
      await viewModel.getSentinels();
      expect(viewModel.sentinels.value.single.name, 'Athena');
    });

    test('隐藏预设的数据仍在库中,按名可解析', () async {
      repo.all = [
        SentinelEntity(id: 1, name: 'Athena', isPreset: true),
        SentinelEntity(id: 2, name: '内置角色B', isPreset: true),
      ];
      await viewModel.getSentinels();
      expect(viewModel.sentinels.value, hasLength(1));
      // 已存聊天引用隐藏预设时,按名查找不受列表过滤影响
      final resolved = await viewModel.getSentinelByName('内置角色B');
      expect(resolved?.name, '内置角色B');
    });
  });
}
