import 'package:athena/provider/provider.dart';
import 'package:athena/provider/setting.dart';
import 'package:athena/schema/isar.dart';
import 'package:athena/schema/model.dart';
import 'package:isar/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'model.g.dart';

@riverpod
class ChatModelNotifier extends _$ChatModelNotifier {
  @override
  Future<Model> build() async {
    var setting = await ref.watch(settingNotifierProvider.future);
    var id = setting.chatModelId;
    var builder = isar.models.filter().idEqualTo(id);
    var model = await builder.findFirst();
    return model ?? Model();
  }
}

@riverpod
class ChatNamingModelNotifier extends _$ChatNamingModelNotifier {
  @override
  Future<Model> build() async {
    var setting = await ref.watch(settingNotifierProvider.future);
    var id = setting.chatNamingModelId;
    var builder = isar.models.filter().idEqualTo(id);
    var model = await builder.findFirst();
    return model ?? Model();
  }
}

@riverpod
class ChatSearchDecisionModelNotifier
    extends _$ChatSearchDecisionModelNotifier {
  @override
  Future<Model> build() async {
    var setting = await ref.watch(settingNotifierProvider.future);
    var id = setting.chatSearchDecisionModelId;
    var builder = isar.models.filter().idEqualTo(id);
    var model = await builder.findFirst();
    return model ?? Model();
  }
}

@riverpod
class EnabledModelsForNotifier extends _$EnabledModelsForNotifier {
  @override
  //不能使用Provider作为参数，有冲突
  Future<List<Model>> build(int providerId) async {
    var builder = isar.models.filter().providerIdEqualTo(providerId);
    final models = await builder.findAll();
    models.sort((a, b) => a.name.compareTo(b.name));
    return models;
  }
}

@riverpod
class GroupedEnabledModelsNotifier extends _$GroupedEnabledModelsNotifier {
  @override
  Future<Map<String, List<Model>>> build() async {
    var providers = await ref.watch(enabledProvidersNotifierProvider.future);
    Map<String, List<Model>> result = {};
    for (var provider in providers) {
      var models =
          await ref.watch(enabledModelsForNotifierProvider(provider.id).future);
      if (models.isEmpty) continue;
      result[provider.name] = models;
    }
    return result;
  }
}

@riverpod
class ModelNotifier extends _$ModelNotifier {
  @override
  Future<Model> build(int id) async {
    var model = await isar.models.filter().idEqualTo(id).findFirst();
    if (model != null) return model;
    return Model();
  }
}

@riverpod
class ModelsForNotifier extends _$ModelsForNotifier {
  @override
  //不能使用Provider作为参数，有冲突
  Future<List<Model>> build(int providerId) async {
    var builder = isar.models.filter().providerIdEqualTo(providerId);
    final models = await builder.findAll();
    models.sort((a, b) => a.name.compareTo(b.name));
    return models;
  }
}

@riverpod
class SentinelMetaGenerationModelNotifier
    extends _$SentinelMetaGenerationModelNotifier {
  @override
  Future<Model> build() async {
    var setting = await ref.watch(settingNotifierProvider.future);
    var id = setting.sentinelMetadataGenerationModelId;
    var builder = isar.models.filter().idEqualTo(id);
    var model = await builder.findFirst();
    return model ?? Model();
  }
}

@riverpod
class ShortcutModelNotifier extends _$ShortcutModelNotifier {
  @override
  Future<Model> build() async {
    var setting = await ref.watch(settingNotifierProvider.future);
    var id = setting.shortModelId;
    var builder = isar.models.filter().idEqualTo(id);
    var model = await builder.findFirst();
    return model ?? Model();
  }
}
