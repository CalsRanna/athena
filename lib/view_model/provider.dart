import 'package:athena/main.dart';
import 'package:athena/provider/provider.dart';
import 'package:athena/schema/isar.dart';
import 'package:athena/schema/provider.dart' as schema;
import 'package:athena/view_model/view_model.dart';
import 'package:athena/widget/dialog.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

class ProviderViewModel extends ViewModel {
  final WidgetRef ref;
  ProviderViewModel(this.ref);

  Future<void> storeProvider(schema.Provider provider) async {
    await isar.writeTxn(() async {
      await isar.providers.put(provider);
    });
    ref.invalidate(providersNotifierProvider);
  }

  Future<void> deleteProvider(schema.Provider provider) async {
    await isar.writeTxn(() async {
      await isar.providers.delete(provider.id);
    });
    ref.invalidate(providersNotifierProvider);
  }

  Future<void> updateProvider(schema.Provider provider) async {
    await isar.writeTxn(() async {
      await isar.providers.put(provider);
    });
    ref.invalidate(providersNotifierProvider);
    ADialog.message('Provider updated');
  }
}
