import 'package:athena/api/chat.dart';
import 'package:athena/provider/model.dart';
import 'package:athena/provider/provider.dart';
import 'package:athena/schema/model.dart';
import 'package:athena/view_model/view_model.dart';
import 'package:athena/widget/dialog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ModelViewModel extends ViewModel {
  final WidgetRef ref;

  ModelViewModel(this.ref);

  Future<bool> hasModel() async {
    var models = await ref.read(groupedEnabledModelsNotifierProvider.future);
    return models.isNotEmpty;
  }

  Future<String> checkConnection(Model model) async {
    ADialog.loading();
    try {
      var provider = providerNotifierProvider(model.providerId);
      var aiProvider = await ref.read(provider.future);
      var result = await ChatApi().connect(provider: aiProvider, model: model);
      ADialog.dismiss();
      return result;
    } catch (error) {
      ADialog.dismiss();
      return error.toString();
    }
  }
}
