/// 会话列宽。
///
/// 消息列与 composer 共用这条定宽列并居中，宽度相同，左右自然对齐。
///
/// 取值来自 **Claude 窗口实测**（窗口 1296 逻辑宽）：正文列左缘 404.5，
/// 铺满整行的右缘到过 1164.5 → 列宽 ≈ 760-768；两条独立截图都落在这一带。
/// 早先按"右缘 1088 + text-stop 56"推过 736，那是取到了一行没铺满的样本，
/// 已回退。
const double kChatColumnWidth = 768;

/// 定宽列之外的最小水平留白。
const double kChatColumnMinPadding = 32;

/// 定宽列**内部**的水平留白，取 4。
/// Codex 的对话容器是 `max-w-3xl` 再加 `px-toolbar`，所以内容宽 768 - 8。
const double kChatColumnInnerPadding = 4;

/// 画布可用宽度 [width] 下，定宽列两侧应留的水平留白。
///
/// 画布不够宽时退回 [kChatColumnMinPadding]，不挤压内容。
double chatColumnPadding(double width) =>
    width > kChatColumnWidth + kChatColumnMinPadding * 2
    ? (width - kChatColumnWidth) / 2
    : kChatColumnMinPadding;
