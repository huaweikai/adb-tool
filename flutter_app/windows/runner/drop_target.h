#pragma once
#include <windows.h>
#include <ole2.h>
#include <flutter/binary_messenger.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <atomic>
#include <memory>
#include <string>
#include <vector>

class DropTarget : public IDropTarget {
 public:
  DropTarget(HWND hwnd, flutter::BinaryMessenger* messenger);
  ~DropTarget();

  void SetActive(bool active);

  // IUnknown
  STDMETHODIMP QueryInterface(REFIID riid, void** ppvObject) override;
  STDMETHODIMP_(ULONG) AddRef() override;
  STDMETHODIMP_(ULONG) Release() override;

  // IDropTarget
  STDMETHODIMP DragEnter(IDataObject* pDataObj, DWORD grfKeyState, POINTL pt,
                         DWORD* pdwEffect) override;
  STDMETHODIMP DragOver(DWORD grfKeyState, POINTL pt,
                        DWORD* pdwEffect) override;
  STDMETHODIMP DragLeave() override;
  STDMETHODIMP Drop(IDataObject* pDataObj, DWORD grfKeyState, POINTL pt,
                    DWORD* pdwEffect) override;

 private:
  std::vector<std::string> GetFilePaths(IDataObject* pDataObj);
  void InvokeMethod(const std::string& method,
                    std::unique_ptr<flutter::EncodableValue> arguments);
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  HWND hwnd_ = nullptr;
  std::atomic<ULONG> ref_count_{1};
  bool active_ = false;
  bool drag_inside_ = false;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};
