import 'dart:io';

import 'package:athena_gui/page/desktop/home/component/home_shortcuts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 新建对话快捷键的生效范围：首页持焦（含输入框失焦回到页面）时触发；
/// 设置页 / 对话框这类压在首页之上的路由打开时不触发，关掉后恢复。
void main() {
  // 激活键按宿主平台只注册一个（macOS ⌘，其余 Ctrl），测试按同一规则按键。
  final modifier = Platform.isMacOS
      ? LogicalKeyboardKey.metaLeft
      : LogicalKeyboardKey.controlLeft;

  Future<void> pressNewChat(WidgetTester tester) async {
    await tester.sendKeyDownEvent(modifier);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(modifier);
    await tester.pump();
  }

  Widget buildHome({required VoidCallback onNewChat, Key? canvasKey}) {
    return MaterialApp(
      home: Scaffold(
        body: DesktopHomeShortcuts(
          onNewChat: onNewChat,
          child: Column(
            children: [
              const TextField(),
              // 画布要能被命中测试到（空 SizedBox 不算），用带底色的盒子
              Expanded(
                child: ColoredBox(
                  key: canvasKey,
                  color: Colors.transparent,
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('首页刚建出来、输入框持焦、点画布让输入框失焦后都能触发', (tester) async {
    var fired = 0;
    final canvasKey = UniqueKey();
    await tester.pumpWidget(
      buildHome(onNewChat: () => fired++, canvasKey: canvasKey),
    );
    // autofocus 在帧末生效
    await tester.pump();
    await pressNewChat(tester);
    expect(fired, 1, reason: '还没有任何控件持焦时页面自己的 scope 应当持焦');

    await tester.tap(find.byType(TextField));
    await tester.pump();
    await pressNewChat(tester);
    expect(fired, 2, reason: '输入框持焦时按键沿祖先冒泡到页级快捷键');

    // 桌面端点画布会让输入框失焦；焦点应落回页面自己的 scope 而不是路由 scope
    await tester.tap(find.byKey(canvasKey));
    await tester.pump();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isFalse,
      reason: '桌面端点画布应让输入框失焦（否则这条测试没测到失焦路径）',
    );
    await pressNewChat(tester);
    expect(fired, 3, reason: '输入框失焦后快捷键仍然可用');
  }, variant: TargetPlatformVariant.desktop());

  testWidgets('压在首页之上的路由打开时不触发，关掉后恢复', (tester) async {
    var fired = 0;
    await tester.pumpWidget(buildHome(onNewChat: () => fired++));
    await tester.pump();

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    // 与设置页同构：非透明路由，首页仍在树里、只是不再是当前路由
    navigator.push(
      PageRouteBuilder<void>(
        opaque: false,
        pageBuilder: (_, _, _) => const Center(child: Text('settings')),
      ),
    );
    await tester.pumpAndSettle();
    await pressNewChat(tester);
    expect(fired, 0, reason: '焦点在上层路由的 scope，走不到首页子树');

    navigator.pop();
    await tester.pumpAndSettle();
    await pressNewChat(tester);
    expect(fired, 1, reason: '回到首页后焦点还给首页，快捷键恢复');
  });
}
