import 'package:athena/provider/model.dart';
import 'package:athena/view_model/view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ModelViewModel extends ViewModel {
  final WidgetRef ref;

  ModelViewModel(this.ref);

  Future<bool> hasModel() async {
    var models = await ref.read(groupedEnabledModelsNotifierProvider.future);
    return models.isNotEmpty;
  }
}
