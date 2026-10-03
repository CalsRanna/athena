import 'dart:io';
import 'dart:ui' as ui;

import 'package:athena_core/util/logger_util.dart';
import 'package:athena_gui/util/clipboard_image_service.dart';
import 'package:athena_gui/view_model/pending_image.dart';
import 'package:signals/signals.dart';

/// 待发图片的暂存与预处理，按对话分槽。
///
/// 从 `ChatViewModel` 整块切出来：它有自己的状态（当前槽 + 其余槽的表）和一条完整
/// 生命周期（占位 → 读取 → 解码校验 → ready/failed），与消息、run、会话列表都不
/// 相干。唯一的对外依赖是「当前是哪条对话」——槽位切换要读它——所以由构造参数注入
/// 一个读取器，而不是把整个 ViewModel 递进来。
class PendingImageStore {
  PendingImageStore({required String? Function() currentChatId})
    : _currentChatId = currentChatId;

  final String? Function() _currentChatId;

  /// 当前对话的待发图片。
  final pendingImages = listSignal<PendingImage>([]);

  /// [pendingImages] 当前属于哪条对话的槽位；null 是还没落盘的"新对话"槽，也是
  /// 启动时的状态。它只是"当前这一槽"的实时值，其余槽位存在 [_byChat] 里。
  String? _key;

  /// 非当前对话的待发图片。当前槽的真相在 [pendingImages] 里，所以这张表里不会
  /// 出现当前槽。
  final Map<String?, List<PendingImage>> _byChat = {};

  Future<void> addPath(String path) => addPaths([path]);

  Future<void> addPaths(List<String> paths) async {
    final images = paths
        .map(
          (path) =>
              PendingImage(path: path, stage: PendingImageStage.preparing),
        )
        .toList();
    pendingImages.value = [...pendingImages.value, ...images];
    for (final image in images) {
      await _prepare(image);
    }
  }

  /// 先占位再读取；按附件标识回填，切换或删除对话后不会写进当前输入框。
  /// 返回 false 才表示没有图片，此时输入框继续粘贴纯文本。
  Future<bool> pasteClipboardImages() async {
    final placeholder = PendingImage();
    pendingImages.value = [...pendingImages.value, placeholder];
    try {
      final paths = await ClipboardImageService.readClipboardImages(
        onPreparing: () => _replace(placeholder.id, [
          placeholder.withStage(PendingImageStage.preparing),
        ]),
      );
      final images = paths
          .map(
            (path) =>
                PendingImage(path: path, stage: PendingImageStage.preparing),
          )
          .toList();
      if (!_replace(placeholder.id, images)) return true;
      for (final image in images) {
        await _prepare(image);
      }
      return paths.isNotEmpty;
    } catch (e) {
      LoggerUtil.e('Failed to read clipboard image: $e');
      _replace(placeholder.id, [
        placeholder.withStage(PendingImageStage.failed),
      ]);
      return true;
    }
  }

  Future<void> _prepare(PendingImage image) async {
    try {
      final bytes = await File(image.path!).readAsBytes();
      if (!_replace(image.id, [image.withStage(PendingImageStage.decoding)])) {
        return;
      }
      // 验证解码后才允许发送；预览与发送共用同一份字节，源文件变化不会串图。
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 96);
      try {
        final frame = await codec.getNextFrame();
        frame.image.dispose();
      } finally {
        codec.dispose();
      }
      _replace(image.id, [
        image.withStage(PendingImageStage.ready, bytes: bytes),
      ]);
    } catch (e) {
      LoggerUtil.e('Failed to prepare image: $e');
      _replace(image.id, [image.withStage(PendingImageStage.failed)]);
    }
  }

  bool _replace(Object id, List<PendingImage> replacements) {
    List<PendingImage>? replace(List<PendingImage> images) {
      final index = images.indexWhere((image) => identical(image.id, id));
      if (index < 0) return null;
      return [
        ...images.take(index),
        ...replacements,
        ...images.skip(index + 1),
      ];
    }

    final current = replace(pendingImages.value);
    if (current != null) {
      pendingImages.value = current;
      return true;
    }
    for (final entry in _byChat.entries) {
      final updated = replace(entry.value);
      if (updated == null) continue;
      if (updated.isEmpty) {
        _byChat.remove(entry.key);
      } else {
        _byChat[entry.key] = updated;
      }
      return true;
    }
    return false;
  }

  /// 历史附件已有字节，不再依赖原文件路径；非当前会话只写自己的槽。
  void restoreFor(String chatId, List<PendingImage> images) {
    if (_currentChatId() == chatId) {
      _key = chatId;
      pendingImages.value = images;
    } else {
      _byChat[chatId] = images;
    }
  }

  void clear() {
    pendingImages.value = [];
  }

  /// 清掉除当前槽以外的全部图片槽（重置数据时用）。当前槽由 [clear] 负责。
  void discardAllSlots() {
    _byChat.clear();
  }

  /// 丢掉某条对话的图片槽（对话被删掉了）。chat id 不复用，那个槽再也回不去，
  /// 留着只会在内存里越堆越多。
  void dropSlot(String chatId) {
    _byChat.remove(chatId);
  }

  void removeAt(int index) {
    final images = List<PendingImage>.from(pendingImages.value);
    if (index >= 0 && index < images.length) {
      images.removeAt(index);
      pendingImages.value = images;
    }
  }

  /// 把 [pendingImages] 切到当前对话那一槽：旧槽存回 [_byChat]、新槽取出。
  /// 必须在 `currentChat` 已更新之后调用，否则会把图片存到错的对话上。
  ///
  /// 进入一条对话时也要调一次：槽键初值是 null（"还没落盘的草稿"），不先对齐
  /// 的话，之后第一次切槽会把当前这批图存进 null 槽、再取回目标对话的空槽。
  ///
  /// 取出时把表里的那份删掉：取出来之后它的真相就在 [pendingImages] 里了，
  /// 留着会在"取回后编辑、再切走"之间产生一份过期的副本（切回旧对话时冒出一张
  /// 早就删掉的图）。
  void retargetToCurrentChat() {
    final next = _currentChatId();
    if (next == _key) return;
    final leaving = pendingImages.value;
    if (leaving.isEmpty) {
      _byChat.remove(_key);
    } else {
      _byChat[_key] = List<PendingImage>.of(leaving);
    }
    _key = next;
    pendingImages.value = List<PendingImage>.of(
      _byChat.remove(next) ?? const [],
    );
  }

  /// 草稿落盘成对话：当前这批图片改归 [chatId]，**列表内容原地不动**。
  ///
  /// 与 [retargetToCurrentChat] 的区别是实质性的：那个是「切到别的对话」，要把
  /// 当前槽存回去再取新槽；这个是「这批图就是这条新对话的」，只改归属。用错会让
  /// 草稿里刚贴好的图当场从输入框消失——存进了 null 槽，取回来的是新对话的空槽。
  ///
  /// 新对话的 id 是刚生成的，[_byChat] 里不可能有它的旧条目。
  void claimFor(String chatId) {
    _key = chatId;
  }
}
