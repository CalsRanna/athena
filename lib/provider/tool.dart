import 'package:athena/schema/isar.dart';
import 'package:athena/schema/tool.dart';
import 'package:isar/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'tool.g.dart';

@riverpod
class ToolsNotifier extends _$ToolsNotifier {
  @override
  Future<List<Tool>> build() async {
    return await isar.tools.where().findAll();
  }
}
