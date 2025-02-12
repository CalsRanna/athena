import 'package:athena/api/sentinel.dart';
import 'package:athena/schema/isar.dart';
import 'package:athena/schema/model.dart';
import 'package:athena/schema/provider.dart';
import 'package:athena/schema/sentinel.dart';
import 'package:athena/view_model/view_model.dart';
import 'package:isar/isar.dart';

class SentinelViewModel extends ViewModel {
  SentinelViewModel(super.ref);

  Future<Sentinel?> generateSentinel(
    String prompt, {
    required Model model,
  }) async {
    var builder = isar.providers.where().idEqualTo(model.providerId);
    var provider = await builder.findFirst();
    if (provider == null) return null;
    return await SentinelApi().generate(
      prompt,
      provider: provider,
      model: model,
    );
  }
}
