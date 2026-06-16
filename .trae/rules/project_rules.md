# Project Rules

## Flutter dialogs with text input

When adding or modifying a Flutter `showDialog` that contains `TextField`, `TextFormField` with a controller, or any `TextEditingController`, the controller must be owned and disposed by a widget inside the dialog route lifecycle.

Use the existing pattern from `home_screen.dart` (`_WirelessAdbDialog` as a `StatefulWidget`) or the local `_SafeDialog` wrapper pattern used in screens such as `test_session_screen.dart` and `test_config_screen.dart`.

Do not create `TextEditingController`s before `showDialog` and dispose them immediately after `await showDialog(...)` returns. Also do not dispose controllers inside dialog button handlers before calling `Navigator.pop`. On desktop, when an input has focus and Esc closes the dialog, disposing controllers outside the dialog route lifecycle can trigger focus cleanup crashes.

For readonly values in dialogs, prefer `TextFormField(initialValue: ..., enabled: false)` when a controller is not needed.

## Flutter dialogs in small windows

When adding or modifying Flutter dialogs, they must be safe when the desktop app window is short. Use `AlertDialog(scrollable: true, ...)` for normal Material dialogs, and wrap large custom dialog bodies in viewport-based constraints plus a scrollable body. Dialog content must not rely on an unconstrained `Column` that can overflow vertically.

For forms, long lists, logs, previews, or any dialog content that may exceed the available height, constrain the dialog to a fraction of the current viewport with `LayoutBuilder`/`MediaQuery` and put the variable-height content in `SingleChildScrollView`, `ListView`, or a constrained scrollable area. Avoid fixed-height dialog bodies that can exceed the current window height.
