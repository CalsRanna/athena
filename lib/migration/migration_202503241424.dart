import 'package:athena/preset/provider.dart';
import 'package:athena/schema/isar.dart';
import 'package:athena/schema/migration.dart';
import 'package:athena/schema/model.dart';
import 'package:athena/schema/provider.dart';

class Migration202503241424 {
  static Future<void> migrate() async {
    await isar.writeTxn(() async {
      await isar.providers.clear();
      await isar.models.clear();
    });
    for (var preset in PresetProvider.providers) {
      var provider = Provider.fromJson(preset);
      await isar.writeTxn(() async {
        provider.id = await isar.providers.put(provider);
      });
      var modelPresets = preset['models'] as List<Map<String, dynamic>>;
      for (var modelPreset in modelPresets) {
        var model = Model.fromJson(modelPreset);
        model.providerId = provider.id;
        await isar.writeTxn(() async {
          await isar.models.put(model);
        });
      }
    }
    var migration = Migration()..migration = '202503241424';
    await isar.writeTxn(() async {
      await isar.migrations.put(migration);
    });
  }
}
