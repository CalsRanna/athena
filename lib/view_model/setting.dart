import 'package:athena/provider/setting.dart';
import 'package:athena/schema/isar.dart';
import 'package:athena/schema/model.dart';
import 'package:athena/schema/setting.dart';
import 'package:athena/view_model/view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

class SettingViewModel extends ViewModel {
  final WidgetRef ref;
  SettingViewModel(this.ref);

  Future<void> updateChatModel(Model model) async {
    var setting = await isar.settings.where().findFirst();
    setting ??= Setting();
    setting.chatModelId = model.id;
    await isar.writeTxn(() async {
      await isar.settings.put(setting!);
    });
    ref.invalidate(settingNotifierProvider);
  }

  Future<void> updateChatNamingModel(Model model) async {
    var setting = await isar.settings.where().findFirst();
    setting ??= Setting();
    setting.chatNamingModelId = model.id;
    await isar.writeTxn(() async {
      await isar.settings.put(setting!);
    });
    ref.invalidate(settingNotifierProvider);
  }

  Future<void> updateChatSearchDecisionModel(Model model) async {
    var setting = await isar.settings.where().findFirst();
    setting ??= Setting();
    setting.chatSearchDecisionModelId = model.id;
    await isar.writeTxn(() async {
      await isar.settings.put(setting!);
    });
    ref.invalidate(settingNotifierProvider);
  }

  Future<void> updateSentinelMetaGenerationModel(Model model) async {
    var setting = await isar.settings.where().findFirst();
    setting ??= Setting();
    setting.sentinelMetadataGenerationModelId = model.id;
    await isar.writeTxn(() async {
      await isar.settings.put(setting!);
    });
    ref.invalidate(settingNotifierProvider);
  }
}
