#include "clipboard_image.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <windows.h>

#include <gdiplus.h>

#include <cwctype>
#include <memory>
#include <string>
#include <vector>

namespace clipboard_image {
namespace {

// GDI+ 进程级初始化（C++11 magic static，线程安全，随进程退出自动释放）。
struct GdiplusSession {
  ULONG_PTR token = 0;
  Gdiplus::GdiplusStartupInput input;
  bool started = false;

  GdiplusSession() {
    started = Gdiplus::GdiplusStartup(&token, &input, nullptr) ==
              Gdiplus::Ok;
  }
  ~GdiplusSession() {
    if (started) {
      Gdiplus::GdiplusShutdown(token);
    }
  }
};

// 查找 image/png 编码器的 CLSID（MSDN 标准实现）。
bool GetPngEncoderClsid(CLSID* clsid) {
  UINT num_encoders = 0;
  UINT encoder_size = 0;
  Gdiplus::GetImageEncodersSize(&num_encoders, &encoder_size);
  if (num_encoders == 0 || encoder_size == 0) {
    return false;
  }
  std::vector<Gdiplus::ImageCodecInfo> encoders(num_encoders);
  if (Gdiplus::GetImageEncoders(num_encoders, encoder_size, encoders.data()) !=
      Gdiplus::Ok) {
    return false;
  }
  for (const auto& encoder : encoders) {
    if (encoder.MimeType != nullptr &&
        wcscmp(encoder.MimeType, L"image/png") == 0) {
      *clsid = encoder.Clsid;
      return true;
    }
  }
  return false;
}

// 将 GDI+ Bitmap 编码为 PNG 字节。
bool BitmapToPngBytes(Gdiplus::Bitmap* bitmap, std::vector<uint8_t>* out) {
  bool ok = false;
  IStream* stream = nullptr;
  if (SUCCEEDED(CreateStreamOnHGlobal(nullptr, TRUE, &stream))) {
    CLSID png_clsid = {};
    if (GetPngEncoderClsid(&png_clsid) &&
        bitmap->Save(stream, &png_clsid, nullptr) == Gdiplus::Ok) {
      HGLOBAL hglobal = nullptr;
      if (SUCCEEDED(GetHGlobalFromStream(stream, &hglobal))) {
        const SIZE_T size = GlobalSize(hglobal);
        const auto* data = static_cast<const uint8_t*>(GlobalLock(hglobal));
        if (data != nullptr && size > 0) {
          out->assign(data, data + size);
          ok = true;
        }
        GlobalUnlock(hglobal);
      }
    }
    stream->Release();
  }
  return ok;
}

// CF_DIB 位图数据 → PNG 字节。调用方须保证 dib 在返回后仍然有效之前
// 不要释放（FromBITMAPINFO 内部引用位图数据）。
bool DibToPng(const void* dib, size_t dib_size, std::vector<uint8_t>* out) {
  if (dib_size < sizeof(BITMAPINFOHEADER)) {
    return false;
  }
  const auto* header = static_cast<const BITMAPINFOHEADER*>(dib);
  if (header->biSize < sizeof(BITMAPINFOHEADER)) {
    return false;
  }
  const void* bits = static_cast<const uint8_t*>(dib) + header->biSize;
  Gdiplus::Bitmap* bitmap = Gdiplus::Bitmap::FromBITMAPINFO(
      static_cast<const BITMAPINFO*>(dib), const_cast<void*>(bits));
  if (bitmap == nullptr) {
    return false;
  }
  const bool ok = BitmapToPngBytes(bitmap, out);
  delete bitmap;
  return ok;
}

// 磁盘上的图片文件 → PNG 字节（用于 jpg/heic 等 API 不支持的格式）。
bool FileToPngBytes(const std::wstring& path, std::vector<uint8_t>* out) {
  Gdiplus::Bitmap* bitmap = Gdiplus::Bitmap::FromFile(path.c_str());
  if (bitmap == nullptr) {
    return false;
  }
  const bool ok = BitmapToPngBytes(bitmap, out);
  delete bitmap;
  return ok;
}

bool IsImageExtension(const std::wstring& extension) {
  std::wstring lower(extension);
  for (wchar_t& c : lower) {
    c = towlower(c);
  }
  return lower == L"png" || lower == L"jpg" || lower == L"jpeg" ||
         lower == L"gif" || lower == L"webp" || lower == L"bmp" ||
         lower == L"tif" || lower == L"tiff" || lower == L"heic" ||
         lower == L"heif";
}

// API 原生支持、无需转换即可直接发送的格式。
bool IsApiCompatibleExtension(const std::wstring& extension) {
  return extension == L"png" || extension == L"gif" || extension == L"webp";
}

// 剪贴板中的文件列表（CF_HDROP）里第一个图片文件的路径与扩展名。
bool HandleDroppedFiles(std::wstring* out_path, std::wstring* out_ext) {
  const HDROP drop = static_cast<HDROP>(GetClipboardData(CF_HDROP));
  if (drop == nullptr) {
    return false;
  }
  const UINT count = DragQueryFile(drop, 0xFFFFFFFF, nullptr, 0);
  for (UINT i = 0; i < count; ++i) {
    wchar_t path[MAX_PATH] = {};
    if (DragQueryFile(drop, i, path, MAX_PATH) == 0) {
      continue;
    }
    const std::wstring full_path(path);
    const size_t dot = full_path.find_last_of(L'.');
    const size_t sep = full_path.find_last_of(L"\\/");
    if (dot == std::wstring::npos ||
        (sep != std::wstring::npos && dot < sep)) {
      continue;
    }
    std::wstring ext = full_path.substr(dot + 1);
    for (wchar_t& c : ext) {
      c = towlower(c);
    }
    if (IsImageExtension(ext)) {
      *out_path = full_path;
      *out_ext = ext;
      return true;
    }
  }
  return false;
}

bool WideToUtf8(const std::wstring& wide, std::string* out) {
  if (wide.empty()) {
    return false;
  }
  const int size =
      WideCharToMultiByte(CP_UTF8, 0, wide.c_str(), -1, nullptr, 0, nullptr,
                          nullptr);
  if (size <= 0) {
    return false;
  }
  std::vector<char> buffer(size);
  WideCharToMultiByte(CP_UTF8, 0, wide.c_str(), -1, buffer.data(), size,
                      nullptr, nullptr);
  out->assign(buffer.data(), size - 1);  // 去掉结尾 NUL
  return true;
}

void HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (call.method_name() != "readClipboardImage") {
    result->NotImplemented();
    return;
  }
  flutter::EncodableMap response;
  if (OpenClipboard(nullptr)) {
    // 文件优先：文件管理器复制文件时剪贴板可能同时携带文件图标预览数据
    // （CF_DIB），此时应以文件本身为准，否则发送的是图标而不是图片内容。
    std::wstring path;
    std::wstring ext;
    if (HandleDroppedFiles(&path, &ext)) {
      if (IsApiCompatibleExtension(ext)) {
        std::string utf8;
        if (WideToUtf8(path, &utf8)) {
          response[flutter::EncodableValue("path")] =
              flutter::EncodableValue(utf8);
        }
      } else {
        // jpg/heic/tiff 等格式 API 不识别，统一转成 PNG
        std::vector<uint8_t> png;
        if (FileToPngBytes(path, &png)) {
          response[flutter::EncodableValue("base64")] =
              flutter::EncodableValue(png);
        }
      }
    }
    if (response.empty() && !IsClipboardFormatAvailable(CF_HDROP)) {
      // 无文件列表时读取位图数据（截图工具、浏览器复制图片）；
      // HDROP 存在但无图片时，图标预览数据不作为图片内容。
      const HANDLE dib = GetClipboardData(CF_DIB);
      if (dib != nullptr) {
        const void* data = GlobalLock(dib);
        if (data != nullptr) {
          std::vector<uint8_t> png;
          if (DibToPng(data, GlobalSize(dib), &png)) {
            response[flutter::EncodableValue("base64")] =
                flutter::EncodableValue(png);
          }
          GlobalUnlock(dib);
        }
      }
    }
    CloseClipboard();
  }
  if (response.empty()) {
    result->Success(flutter::EncodableValue());
    return;
  }
  result->Success(flutter::EncodableValue(response));
}

}  // namespace

void Register(flutter::BinaryMessenger* messenger) {
  // GDI+ 会话随进程存活；channel 对象由引擎的 handler 引用，无需释放。
  static GdiplusSession gdiplus_session = GdiplusSession();
  (void)gdiplus_session;  // 仅在注册时初始化 GDI+
  auto* channel = new flutter::MethodChannel<flutter::EncodableValue>(
      messenger, "athena/clipboard_image",
      &flutter::StandardMethodCodec::GetInstance());
  channel->SetMethodCallHandler(&HandleMethodCall);
}

}  // namespace clipboard_image
