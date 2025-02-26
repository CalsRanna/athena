import 'package:athena/api/sentinel.dart';
import 'package:athena/provider/model.dart';
import 'package:athena/provider/sentinel.dart';
import 'package:athena/schema/isar.dart';
import 'package:athena/schema/provider.dart';
import 'package:athena/schema/sentinel.dart';
import 'package:athena/view_model/view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

class SentinelViewModel extends ViewModel {
  final WidgetRef ref;
  SentinelViewModel(this.ref);

  Future<void> destroySentinel(Sentinel sentinel) async {
    await isar.writeTxn(() async {
      await isar.sentinels.delete(sentinel.id);
    });
    ref.invalidate(sentinelsNotifierProvider);
  }

  Future<Sentinel> generateSentinel(String prompt) async {
    var provider = sentinelMetaGenerationModelNotifierProvider;
    var model = await ref.read(provider.future);
    var builder = isar.providers.where().idEqualTo(model.providerId);
    var aiProvider = await builder.findFirst();
    if (aiProvider == null) throw Exception('Model is not available');
    return await SentinelApi().generate(
      prompt,
      provider: aiProvider,
      model: model,
    );
  }
}
