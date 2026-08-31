import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationDidFinishLaunching(_ notification: Notification) {
    registerClipboardImageChannel()
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationShouldHandleReopen(
    _ sender: NSApplication,
    hasVisibleWindows flag: Bool
  ) -> Bool {
    if !flag {
      sender.setActivationPolicy(.regular)
      for window in sender.windows {
        window.setIsVisible(true)
        window.makeKeyAndOrderFront(self)
      }
      sender.activate(ignoringOtherApps: true)
    }
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  /// 注册 "athena/clipboard_image" channel：读取系统剪贴板中的图片。
  private func registerClipboardImageChannel() {
    guard let controller = mainFlutterWindow?.contentViewController
      as? FlutterViewController
    else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "athena/clipboard_image",
      binaryMessenger: controller.engine.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "readClipboardImage" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(self.readClipboardImage())
    }
  }

  /// 读取剪贴板中的图片：
  /// - ["path": ...]：剪贴板中是 png/gif/webp 图片文件（如 Finder 复制图片）
  /// - ["base64": ...]：剪贴板中是图片数据（如 Cmd+Shift+4 截图），转为 PNG base64
  /// - nil：剪贴板中没有图片
  private func readClipboardImage() -> [String: String]? {
    let pasteboard = NSPasteboard.general
    // 文件优先：Finder 复制文件时剪贴板会同时携带文件图标预览数据，
    // 此时应以文件本身为准，否则发送的是图标而不是图片内容。
    let urls = pasteboard.readObjects(
      forClasses: [NSURL.self],
      options: [.urlReadingFileURLsOnly: true]
    ) as? [URL]
    if let urls, !urls.isEmpty {
      guard
        let url = urls.first(where: { AppDelegate.isImageFilePath($0.pathExtension) })
      else {
        // 非图片文件：图标预览数据不作为图片内容
        return nil
      }
      // API 只接受 png/gif/webp；其他格式（jpg/heic/tiff 等）转成 PNG
      if AppDelegate.apiCompatibleExtensions.contains(url.pathExtension.lowercased()) {
        return ["path": url.path]
      }
      guard let png = AppDelegate.loadImageAsPng(url: url) else { return nil }
      return ["base64": png]
    }
    if let data = pasteboard.data(forType: .png) {
      return ["base64": data.base64EncodedString()]
    }
    if let data = pasteboard.data(forType: .tiff),
      let rep = NSBitmapImageRep(data: data),
      let png = rep.representation(using: .png, properties: [:])
    {
      return ["base64": png.base64EncodedString()]
    }
    return nil
  }

  /// 解码常见图片文件并转成 PNG base64。
  private static func loadImageAsPng(url: URL) -> String? {
    guard let image = NSImage(contentsOfFile: url.path),
      let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:])
    else {
      return nil
    }
    return png.base64EncodedString()
  }

  /// 图片文件扩展名白名单（用于识别剪贴板中的图片文件）。
  private static let imageExtensions: Set<String> = [
    "png", "jpg", "jpeg", "gif", "webp", "bmp", "tif", "tiff", "heic", "heif",
  ]

  /// API 原生支持、无需转换即可直接发送的格式。
  private static let apiCompatibleExtensions: Set<String> = [
    "png", "gif", "webp",
  ]

  private static func isImageFilePath(_ ext: String) -> Bool {
    return imageExtensions.contains(ext.lowercased())
  }
}
