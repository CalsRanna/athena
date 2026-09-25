import 'package:athena_core/entity/api_format.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_gui/page/desktop/setting/provider/component/api_format_menu.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_theme.dart';
import 'package:athena_gui/widget/context_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// API 格式选择：自动同步时显示 `Auto · <推断出的格式>`，手动指定时只显示格式名；
/// 选中后必须把「交还给目录同步」与「手动指定某种协议」区分开交给上层——
/// 两者的落库语义不同（`apiFormatAuto` 的取值）。
void main() {
  ProviderEntity probe({
    ApiFormat apiFormat = ApiFormat.chatCompletions,
    bool apiFormatAuto = true,
  }) => ProviderEntity(
    name: 'probe',
    baseUrl: 'https://example.com',
    apiKey: 'test-key',
    apiFormat: apiFormat,
    apiFormatAuto: apiFormatAuto,
    createdAt: DateTime(2026, 1, 1),
  );

  Future<void> pumpSelect(
    WidgetTester tester,
    ProviderEntity entity,
    void Function({required bool auto, ApiFormat? format}) onSelected,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAthenaThemeData(AthenaColorMode.light),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: DesktopSettingApiFormatSelect(
                provider: entity,
                onSelected: onSelected,
              ),
            ),
          ),
        ),
      ),
    );
  }

  tearDown(() {
    // 断言失败时清掉残留菜单，避免污染下一个用例
    DesktopContextMenuManager.instance.dismiss();
  });

  testWidgets('自动同步：标注 Auto 与推断出的格式', (tester) async {
    await pumpSelect(
      tester,
      probe(apiFormat: ApiFormat.responses),
      ({required bool auto, ApiFormat? format}) {},
    );

    expect(find.text('Auto · Responses'), findsOneWidget);
  });

  testWidgets('手动指定：只显示格式名', (tester) async {
    await pumpSelect(
      tester,
      probe(apiFormat: ApiFormat.chatCompletions, apiFormatAuto: false),
      ({required bool auto, ApiFormat? format}) {},
    );

    expect(find.text('Chat Completions'), findsOneWidget);
    expect(find.textContaining('Auto'), findsNothing);
  });

  testWidgets('选 Auto：回调 auto=true 且不带格式', (tester) async {
    bool? pickedAuto;
    ApiFormat? pickedFormat;
    var called = false;
    await pumpSelect(
      tester,
      probe(apiFormat: ApiFormat.responses, apiFormatAuto: false),
      ({required bool auto, ApiFormat? format}) {
        called = true;
        pickedAuto = auto;
        pickedFormat = format;
      },
    );

    await tester.tap(find.text('Responses'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Auto (models.dev)'));
    await tester.pumpAndSettle();

    expect(called, isTrue);
    expect(pickedAuto, isTrue);
    expect(pickedFormat, isNull);
  });

  testWidgets('选某种协议：回调 auto=false 并带上该协议', (tester) async {
    bool? pickedAuto;
    ApiFormat? pickedFormat;
    var called = false;
    await pumpSelect(
      tester,
      probe(apiFormat: ApiFormat.chatCompletions),
      ({required bool auto, ApiFormat? format}) {
        called = true;
        pickedAuto = auto;
        pickedFormat = format;
      },
    );

    await tester.tap(find.text('Auto · Chat Completions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Messages'));
    await tester.pumpAndSettle();

    expect(called, isTrue);
    expect(pickedAuto, isFalse);
    expect(pickedFormat, ApiFormat.messages);
  });
}
