import 'package:athena/schema/model.dart';
import 'package:creator/creator.dart';

final modelsCreator = Creator<List<Model>>.value(
  [],
  name: 'modelsCreator',
  keepAlive: true,
);
