import 'package:athena/entity/sentinel_entity.dart';
import 'package:athena/view_model/chat_view_model.dart';
import 'package:athena/view_model/sentinel_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SentinelViewModel.defaultSentinel', () {
    test('falls back to Athena when no sentinels are loaded', () {
      final viewModel = SentinelViewModel();

      final sentinel = viewModel.defaultSentinel.value;

      expect(sentinel.name, 'Athena');
      expect(sentinel.prompt, isNotEmpty);
    });

    test('prefers the stored Athena sentinel when available', () {
      final viewModel = SentinelViewModel();
      final storedAthena = SentinelEntity(
        id: 2,
        name: 'Athena',
        prompt: 'stored prompt',
      );

      viewModel.sentinels.value = [
        SentinelEntity(id: 1, name: 'Custom'),
        storedAthena,
      ];

      expect(viewModel.defaultSentinel.value.id, storedAthena.id);
      expect(viewModel.defaultSentinel.value.prompt, 'stored prompt');
    });
  });

  group('ChatViewModel draft defaults', () {
    test('start from the shared new chat defaults', () {
      final viewModel = ChatViewModel();

      expect(viewModel.currentContext.value, ChatViewModel.defaultDraftContext);
      expect(
        viewModel.currentTemperature.value,
        ChatViewModel.defaultDraftTemperature,
      );
      expect(
        viewModel.currentEnableSearch.value,
        ChatViewModel.defaultDraftEnableSearch,
      );
    });
  });
}
