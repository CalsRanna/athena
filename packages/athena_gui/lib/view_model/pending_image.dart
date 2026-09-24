import 'dart:typed_data';

enum PendingImageStage { reading, preparing, decoding, ready, failed }

/// 图片在读取完成前就有稳定标识，异步结果只能回填原来的附件槽位。
class PendingImage {
  final Object id;
  final String? path;
  final Uint8List? bytes;
  final PendingImageStage stage;

  PendingImage({
    Object? id,
    this.path,
    this.bytes,
    this.stage = PendingImageStage.reading,
  }) : id = id ?? Object();

  bool get isReady => stage == PendingImageStage.ready;

  PendingImage withStage(PendingImageStage stage, {Uint8List? bytes}) =>
      PendingImage(
        id: id,
        path: path,
        bytes: bytes ?? this.bytes,
        stage: stage,
      );
}
