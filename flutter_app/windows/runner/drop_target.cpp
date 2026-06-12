#include "drop_target.h"

#include <shellapi.h>
#include <shlobj.h>
#include <flutter/standard_method_codec.h>

namespace {

std::string WideToUtf8(const std::wstring& wstr) {
  if (wstr.empty()) return {};
  int size = WideCharToMultiByte(CP_UTF8, 0, wstr.c_str(),
                                 static_cast<int>(wstr.size()), nullptr, 0,
                                 nullptr, nullptr);
  std::string result(size, 0);
  WideCharToMultiByte(CP_UTF8, 0, wstr.c_str(), static_cast<int>(wstr.size()),
                      result.data(), size, nullptr, nullptr);
  return result;
}

}  // namespace

DropTarget::DropTarget(HWND hwnd, flutter::BinaryMessenger* messenger)
    : hwnd_(hwnd) {
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "win_drop",
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) { HandleMethodCall(call, std::move(result)); });
}

DropTarget::~DropTarget() {
  channel_->SetMethodCallHandler(nullptr);
}

void DropTarget::SetActive(bool active) {
  active_ = active;
}

void DropTarget::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (call.method_name() == "setActive") {
    const auto* args = std::get_if<bool>(call.arguments());
    if (args) {
      SetActive(*args);
      result->Success();
      return;
    }
  }
  result->NotImplemented();
}

void DropTarget::InvokeMethod(
    const std::string& method,
    std::unique_ptr<flutter::EncodableValue> arguments) {
  channel_->InvokeMethod(method, std::move(arguments));
}

std::vector<std::string> DropTarget::GetFilePaths(IDataObject* pDataObj) {
  std::vector<std::string> paths;
  FORMATETC fmt = {CF_HDROP, nullptr, DVASPECT_CONTENT, -1, TYMED_HGLOBAL};
  STGMEDIUM stg = {};

  if (SUCCEEDED(pDataObj->GetData(&fmt, &stg))) {
    HDROP hDrop = static_cast<HDROP>(stg.hGlobal);
    UINT fileCount = DragQueryFileW(hDrop, 0xFFFFFFFF, nullptr, 0);
    for (UINT i = 0; i < fileCount; i++) {
      wchar_t filePath[MAX_PATH];
      if (DragQueryFileW(hDrop, i, filePath, MAX_PATH) > 0) {
        paths.push_back(WideToUtf8(filePath));
      }
    }
    ReleaseStgMedium(&stg);
  }
  return paths;
}

STDMETHODIMP DropTarget::QueryInterface(REFIID riid, void** ppvObject) {
  if (riid == IID_IUnknown || riid == IID_IDropTarget) {
    *ppvObject = static_cast<IDropTarget*>(this);
    AddRef();
    return S_OK;
  }
  *ppvObject = nullptr;
  return E_NOINTERFACE;
}

STDMETHODIMP_(ULONG) DropTarget::AddRef() {
  return ++ref_count_;
}

STDMETHODIMP_(ULONG) DropTarget::Release() {
  ULONG count = --ref_count_;
  if (count == 0) {
    delete this;
  }
  return count;
}

STDMETHODIMP DropTarget::DragEnter(IDataObject* pDataObj, DWORD grfKeyState,
                                   POINTL pt, DWORD* pdwEffect) {
  if (!active_) {
    *pdwEffect = DROPEFFECT_NONE;
    return S_OK;
  }
  drag_inside_ = true;
  InvokeMethod("dragEntered", nullptr);
  *pdwEffect = DROPEFFECT_COPY;
  return S_OK;
}

STDMETHODIMP DropTarget::DragOver(DWORD grfKeyState, POINTL pt,
                                  DWORD* pdwEffect) {
  if (!active_) {
    *pdwEffect = DROPEFFECT_NONE;
    return S_OK;
  }
  *pdwEffect = DROPEFFECT_COPY;
  return S_OK;
}

STDMETHODIMP DropTarget::DragLeave() {
  if (!active_ || !drag_inside_) return S_OK;
  drag_inside_ = false;
  InvokeMethod("dragExited", nullptr);
  return S_OK;
}

STDMETHODIMP DropTarget::Drop(IDataObject* pDataObj, DWORD grfKeyState,
                              POINTL pt, DWORD* pdwEffect) {
  if (!active_) {
    *pdwEffect = DROPEFFECT_NONE;
    return S_OK;
  }
  drag_inside_ = false;

  auto paths = GetFilePaths(pDataObj);
  if (!paths.empty()) {
    auto list = std::make_unique<flutter::EncodableValue>(
        flutter::EncodableList(paths.begin(), paths.end()));
    InvokeMethod("dragDone", std::move(list));
  }

  *pdwEffect = DROPEFFECT_COPY;
  return S_OK;
}
