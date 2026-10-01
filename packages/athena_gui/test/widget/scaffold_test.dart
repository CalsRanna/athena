import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_theme.dart';
import 'package:athena_gui/widget/scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final platform in TargetPlatform.values) {
    testWidgets('页面骨架按主题平台 $platform 应用移动端安全区', (tester) async {
      const appBarKey = Key('app-bar');
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAthenaThemeData(
            AthenaColorMode.light,
          ).copyWith(platform: platform),
          home: const MediaQuery(
            data: MediaQueryData(padding: EdgeInsets.only(top: 24)),
            child: AthenaScaffold(
              appBar: SizedBox(key: appBarKey, height: 20),
              body: SizedBox.expand(),
            ),
          ),
        ),
      );
      final isDesktop = {
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      }.contains(platform);
      expect(tester.getTopLeft(find.byKey(appBarKey)).dy, isDesktop ? 0 : 24);
      expect(tester.takeException(), isNull);
    });
  }
}
