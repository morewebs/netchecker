#include "flutter_window.h"
#include <algorithm>

#include <optional>

#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  RegisterWindowChannel();
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::RegisterWindowChannel() {
  HWND hwnd = GetHandle();
  window_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "netchecker/window",
          &flutter::StandardMethodCodec::GetInstance());
  window_channel_->SetMethodCallHandler(
      [this, hwnd](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        const auto& method = call.method_name();
        if (method == "setAlwaysOnTop") {
          bool on = false;
          if (const auto* value = std::get_if<bool>(call.arguments())) {
            on = *value;
          }
          SetWindowPos(hwnd, on ? HWND_TOPMOST : HWND_NOTOPMOST, 0, 0, 0, 0,
                       SWP_NOMOVE | SWP_NOSIZE);
          result->Success();
          return;
        }
        if (method == "setCompact") {
          bool on = false;
          if (const auto* value = std::get_if<bool>(call.arguments())) {
            on = *value;
          }
          if (on != compact_) {
            RECT rect;
            GetWindowRect(hwnd, &rect);
            if (on) restore_bounds_ = rect;
            const UINT dpi = GetDpiForWindow(hwnd);
            int w = on ? MulDiv(420, dpi, 96) : restore_bounds_.right - restore_bounds_.left;
            int h = on ? MulDiv(640, dpi, 96) : restore_bounds_.bottom - restore_bounds_.top;
            int x = on ? rect.right - w : restore_bounds_.left;
            int y = on ? rect.top : restore_bounds_.top;
            MONITORINFO info{sizeof(MONITORINFO)};
            if (GetMonitorInfo(MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST), &info)) {
              w = std::min<int>(w, info.rcWork.right - info.rcWork.left);
              h = std::min<int>(h, info.rcWork.bottom - info.rcWork.top);
              x = std::max<int>(info.rcWork.left, std::min<int>(x, info.rcWork.right - w));
              y = std::max<int>(info.rcWork.top, std::min<int>(y, info.rcWork.bottom - h));
            }
            SetWindowPos(hwnd, nullptr, x, y, w, h, SWP_NOZORDER | SWP_NOACTIVATE);
            compact_ = on;
          }
          result->Success();
          return;
        }
        result->NotImplemented();
      });
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
