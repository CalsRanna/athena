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
      // 剪贴板中的非兼容格式（jpg 等）需要转成 PNG base64，
      // 可能耗时上百毫秒甚至更久，放到后台队列避免阻塞主线程（UI 卡顿）
      DispatchQueue.global(qos: .userInitiated).async {
        let value = self.readClipboardImage()
        DispatchQueue.main.async {
          result(value)
        }
      }
    }
  }

  /// 读取剪贴板中的图片：
  /// - ["paths": [...] ]：剪贴板中是多个 png/gif/webp 图片文件（如 Finder 多选复制）
  /// - ["base64s": [...]]：上述场景中非兼容格式（jpg/heic/tiff 等）转为 PNG base64
  /// - ["base64": ...]：剪贴板中是图片数据（如 Cmd+Shift+4 截图），转为 PNG base64
  /// - nil：剪贴板中没有图片
  private func readClipboardImage() -> [String: Any]? {
    let pasteboard = NSPasteboard.general
    // 文件优先：Finder 复制文件时剪贴板会同时携带文件图标预览数据，
    // 此时应以文件本身为准，否则发送的是图标而不是图片内容。
    let urls = pasteboard.readObjects(
      forClasses: [NSURL.self],
      options: [.urlReadingFileURLsOnly: true]
    ) as? [URL]
    if let urls, !urls.isEmpty {
      let imageUrls = urls.filter { AppDelegate.isImageFilePath($0.pathExtension) }
      if imageUrls.isEmpty {
        // 非图片文件：图标预览数据不作为图片内容
        return nil
      }
      // 多选复制时收集全部图片；API 只接受 png/gif/webp，
      // 其他格式（jpg/heic/tiff 等）转成 PNG
      var paths: [String] = []
      var base64s: [String] = []
      for url in imageUrls {
        if AppDelegate.apiCompatibleExtensions.contains(url.pathExtension.lowercased()) {
          paths.append(url.path)
        } else if let png = AppDelegate.loadImageAsPng(url: url) {
          base64s.append(png)
        }
      }
      var result: [String: Any] = [:]
      if !paths.isEmpty { result["paths"] = paths }
      if !base64s.isEmpty { result["base64s"] = base64s }
      return result.isEmpty ? nil : result
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
