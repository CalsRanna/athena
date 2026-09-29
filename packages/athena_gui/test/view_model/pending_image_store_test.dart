import 'dart:io';
import 'dart:typed_data';

import 'package:athena_gui/view_model/pending_image.dart';
import 'package:athena_gui/view_model/pending_image_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// 待发图片暂存单元的契约。
///
/// 它此前长在 ChatViewModel 里，只能靠 widget 测试间接覆盖（`clipboard_image_input_test`
/// 走的是整条粘贴链路）。切出来之后这里直接测生命周期与槽位语义——尤其是
/// `claimFor` 与 `retargetToCurrentChat` 的差别，用错会让草稿里刚贴的图当场消失。
void main() {
  late Directory temp;
  late Uint8List png;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('athena_pending_image_');
    png = File('asset/image/launcher_icon_macos_512x512.png').readAsBytesSync();
  });

  tearDown(() => temp.deleteSync(recursive: true));

  String writePng(String name) {
    final file = File('${temp.path}/$name')..writeAsBytesSync(png);
    return file.path;
  }

  String writeJunk(String name) {
    final file = File('${temp.path}/$name')
      ..writeAsBytesSync(List<int>.filled(64, 7));
    return file.path;
  }

  /// 与 ViewModel 一致：进入某条对话时会先切一次槽，把内部槽键对齐到当前对话。
  /// 少了这一步，`_key` 仍是初值 null，之后的切槽会把图片存进 null 槽。
  PendingImageStore store(String? Function() currentChatId) {
    final subject = PendingImageStore(currentChatId: currentChatId);
    subject.retargetToCurrentChat();
    return subject;
  }

  group('添加与解码', () {
    test('合法图片先占位再变成 ready，并带上字节', () async {
      final subject = store(() => null);

      final adding = subject.addPaths([writePng('a.png')]);
      expect(
        subject.pendingImages.value.single.stage,
        PendingImageStage.preparing,
        reason: '先占位，别让输入框在读取期间空着',
      );

      await adding;

      expect(subject.pendingImages.value, hasLength(1));
      expect(subject.pendingImages.value.single.stage, PendingImageStage.ready);
      expect(subject.pendingImages.value.single.bytes, png);
    });

    test('解不开的图片落到 failed，不抛异常', () async {
      final subject = store(() => null);

      await subject.addPaths([writeJunk('bad.png')]);

      expect(
        subject.pendingImages.value.single.stage,
        PendingImageStage.failed,
      );
    });

    test('多张按顺序追加', () async {
      final subject = store(() => null);

      await subject.addPaths([writePng('a.png'), writePng('b.png')]);

      expect(subject.pendingImages.value, hasLength(2));
      expect(subject.pendingImages.value.every((i) => i.isReady), isTrue);
    });
  });

  group('增删', () {
    test('clear 清空当前槽', () async {
      final subject = store(() => null);
      await subject.addPaths([writePng('a.png')]);

      subject.clear();

      expect(subject.pendingImages.value, isEmpty);
    });

    test('removeAt 只删指定下标，越界是 no-op', () async {
      final subject = store(() => null);
      await subject.addPaths([writePng('a.png'), writePng('b.png')]);
      final first = subject.pendingImages.value.first.id;

      subject.removeAt(0);
      expect(subject.pendingImages.value, hasLength(1));

      subject.removeAt(5);
      expect(subject.pendingImages.value, hasLength(1), reason: '越界不该删掉别的');
      expect(subject.pendingImages.value.single.id, isNot(first));
    });
  });

  group('按对话分槽', () {
    test('切到别的对话：旧槽存回、新槽取回各自的内容', () async {
      var current = 'A';
      final subject = store(() => current);
      await subject.addPaths([writePng('a.png')]);

      current = 'B';
      subject.retargetToCurrentChat();
      expect(subject.pendingImages.value, isEmpty, reason: 'B 还没有图');

      await subject.addPaths([writePng('b.png')]);
      expect(subject.pendingImages.value, hasLength(1));

      current = 'A';
      subject.retargetToCurrentChat();
      expect(subject.pendingImages.value, hasLength(1), reason: 'A 的那张要回来');
      expect(subject.pendingImages.value.single.bytes, png);
    });

    test('槽位没变时切槽是 no-op', () async {
      final subject = store(() => 'A');
      await subject.addPaths([writePng('a.png')]);

      subject.retargetToCurrentChat();

      expect(subject.pendingImages.value, hasLength(1));
    });

    test('claimFor 只改归属，图片留在原处', () async {
      // 这条是这次拆分最容易写错的地方：草稿落盘时 ViewModel 已经先把
      // currentChat 指向新对话，如果 claimFor 实现成 retargetToCurrentChat，
      // 就会把图存进 null 槽、再取回新对话的空槽——用户刚贴好的图当场消失。
      var current = 'draft';
      final subject = store(() => current);
      await subject.addPaths([writePng('a.png')]);

      current = 'new-chat'; // ViewModel 先切 currentChat
      subject.claimFor('new-chat');

      expect(subject.pendingImages.value, hasLength(1), reason: '图不能消失');

      // 归属确实改了：切走再切回来，图在新的归属下
      current = 'other';
      subject.retargetToCurrentChat();
      expect(subject.pendingImages.value, isEmpty);

      current = 'new-chat';
      subject.retargetToCurrentChat();
      expect(subject.pendingImages.value, hasLength(1));
    });

    test('dropSlot 丢掉被删对话的槽', () async {
      var current = 'A';
      final subject = store(() => current);
      await subject.addPaths([writePng('a.png')]);

      current = 'B';
      subject.retargetToCurrentChat();
      await subject.addPaths([writePng('b.png')]);

      subject.dropSlot('A');

      current = 'A';
      subject.retargetToCurrentChat();
      expect(subject.pendingImages.value, isEmpty);
    });

    test('discardAllSlots 清掉其余槽，当前槽由 clear 负责', () async {
      var current = 'A';
      final subject = store(() => current);
      await subject.addPaths([writePng('a.png')]);

      current = 'B';
      subject.retargetToCurrentChat();
      await subject.addPaths([writePng('b.png')]);

      subject.discardAllSlots();
      subject.clear();

      current = 'A';
      subject.retargetToCurrentChat();
      expect(subject.pendingImages.value, isEmpty);
    });
  });
}
