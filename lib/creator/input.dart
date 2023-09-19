import 'package:creator/creator.dart';
import 'package:flutter/material.dart';

final focusNodeCreator = Creator<FocusNode>.value(
  FocusNode(),
  name: 'focusNodeCreator',
);

final textEditingControllerCreator = Creator<TextEditingController>.value(
  TextEditingController(),
  name: 'textEditingControllerCreator',
);
