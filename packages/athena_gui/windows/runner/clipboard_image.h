#ifndef RUNNER_CLIPBOARD_IMAGE_H_
#define RUNNER_CLIPBOARD_IMAGE_H_

#include <flutter/binary_messenger.h>

namespace clipboard_image {

// 注册 "athena/clipboard_image" channel，读取系统剪贴板中的图片。
// 返回协议见 Dart 侧 ClipboardImageService：
// - {"path": <图片文件路径>}：剪贴板中是图片文件（如资源管理器复制）
// - {"base64": <PNG 字节>}：剪贴板中是图片数据（如截图工具），转为 PNG
// - null：剪贴板中没有图片
void Register(flutter::BinaryMessenger* messenger);

}  // namespace clipboard_image

#endif  // RUNNER_CLIPBOARD_IMAGE_H_
