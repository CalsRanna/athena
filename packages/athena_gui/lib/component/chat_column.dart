/// 会话列宽。
///
/// Codex 把对话内容与输入框放在同一条定宽列里并居中，宽度取自它的
/// `--container-3xl`（48rem = 768）。实测 Codex 的 composer 宽 1474 设备像素，
/// 按窗口缩放换算同样落在 768 附近，两处互相印证。
///
/// 这里放一个共享常量，让消息列与 composer 用同一个值，左右自然对齐。
const double kChatColumnWidth = 768;

/// 定宽列之外的最小水平留白。
const double kChatColumnMinPadding = 32;

/// 定宽列**内部**的水平留白，取 Codex 的 `--padding-toolbar`（spacing × 4 = 16）。
/// Codex 的对话容器是 `max-w-3xl` 再加 `px-toolbar`，所以内容宽 768 - 32。
const double kChatColumnInnerPadding = 16;

/// 画布可用宽度 [width] 下，定宽列两侧应留的水平留白。
///
/// 画布不够宽时退回 [kChatColumnMinPadding]，不挤压内容。
double chatColumnPadding(double width) =>
    width > kChatColumnWidth + kChatColumnMinPadding * 2
    ? (width - kChatColumnWidth) / 2
    : kChatColumnMinPadding;
