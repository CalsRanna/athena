import 'package:athena/provider/tool.dart';
import 'package:athena/schema/isar.dart';
import 'package:athena/schema/tool.dart';
import 'package:athena/view_model/view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ToolViewModel extends ViewModel {
  final WidgetRef ref;

  ToolViewModel(this.ref);

  Future<void> updateKey(Tool tool) async {
    await isar.writeTxn(() async {
      await isar.tools.put(tool);
    });
    ref.invalidate(toolsNotifierProvider);
  }
}
