#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "app_links/app_links_plugin_c_api.h"
#include "flutter_window.h"
#include "utils.h"

// Forward a dhqclash://... activation to the already-running instance and return
// true, instead of starting a second process (the Dart-side SingleInstanceLock
// would just kill it and drop the link).
//
// app_links 7.1.2 exports only SendAppLink(HWND) — the no-arg
// SendAppLinkToInstance() helper landed in a later release — so we locate the
// running window ourselves. Matching is by window class + full exe path (not
// window title): FlClash uses a hidden/custom title bar, so a FindWindow-by-title
// lookup is unreliable. This mirrors what newer app_links does internally.
static bool ForwardAppLinkToRunningInstance() {
  struct State { HWND found; wchar_t ourExe[MAX_PATH]; } state = {};
  ::GetModuleFileNameW(nullptr, state.ourExe, MAX_PATH);

  ::EnumWindows(
      [](HWND hwnd, LPARAM lp) -> BOOL {
        auto* s = reinterpret_cast<State*>(lp);
        wchar_t cls[64] = {};
        ::GetClassNameW(hwnd, cls, 64);
        if (_wcsicmp(cls, L"FLUTTER_RUNNER_WIN32_WINDOW") != 0) return TRUE;

        DWORD pid = 0;
        ::GetWindowThreadProcessId(hwnd, &pid);
        HANDLE h = ::OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
        if (!h) return TRUE;
        wchar_t exe[MAX_PATH] = {};
        DWORD len = MAX_PATH;
        ::QueryFullProcessImageNameW(h, 0, exe, &len);
        ::CloseHandle(h);
        if (_wcsicmp(exe, s->ourExe) == 0) {
          s->found = hwnd;
          return FALSE;
        }
        return TRUE;
      },
      reinterpret_cast<LPARAM>(&state));

  if (!state.found) return false;

  ::SendAppLink(state.found);

  WINDOWPLACEMENT place = {sizeof(WINDOWPLACEMENT)};
  ::GetWindowPlacement(state.found, &place);
  ::ShowWindow(state.found,
               place.showCmd == SW_SHOWMINIMIZED ? SW_RESTORE : SW_NORMAL);
  ::SetForegroundWindow(state.found);
  return true;
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  if (ForwardAppLinkToRunningInstance()) {
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"DHQClash", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
