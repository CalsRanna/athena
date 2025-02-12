import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class ViewModel {
  final WidgetRef ref;

  ViewModel(this.ref);
}
