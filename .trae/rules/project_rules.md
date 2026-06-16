# Project Rules

## Flutter dialogs with text input

When adding or modifying a Flutter `showDialog` that contains `TextField`, `TextFormField` with a controller, or any `TextEditingController`, the controller must be owned and disposed by a widget inside the dialog route lifecycle.

Use the existing pattern from `home_screen.dart` (`_WirelessAdbDialog` as a `StatefulWidget`) or the local `_SafeDialog` wrapper pattern used in screens such as `test_session_screen.dart` and `test_config_screen.dart`.

Do not create `TextEditingController`s before `showDialog` and dispose them immediately after `await showDialog(...)` returns. Also do not dispose controllers inside dialog button handlers before calling `Navigator.pop`. On desktop, when an input has focus and Esc closes the dialog, disposing controllers outside the dialog route lifecycle can trigger focus cleanup crashes.

For readonly values in dialogs, prefer `TextFormField(initialValue: ..., enabled: false)` when a controller is not needed.
