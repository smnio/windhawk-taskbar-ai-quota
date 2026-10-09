# Specific monitor selection (1.6.12)

Previously, the specific-display dropdown showed primary-first taskbar list positions.
Disconnecting another monitor could change that position and move the widget.

The dropdown now uses the current Windows GDI display number (`\\.\\DISPLAYn`)
and resolution. The saved selection uses the monitor interface returned by
`EnumDisplayDevicesW` with `EDD_GET_DEVICE_INTERFACE_NAME`, rather than a display
number, HMONITOR, HWND, or list position.

`WM_DISPLAYCHANGE` schedules a rebuild after the existing two-second topology
settling period. Discovery reads the current monitor mapping again for each retry,
updates the saved number, and refreshes the open settings dropdown. A disconnected
selection is retained and shown as unavailable; it does not select a different
monitor that inherited the old number. Reconnection restores the widget.

Older settings are bound once to the monitor selected by their old list position.
This preserves the current placement during upgrade; if that placement had already
shifted, select the intended monitor once in Settings. Accounts and authentication
identity keys are unchanged. Moving a monitor to a different port/dock or changing
drivers can change its Windows interface and require selecting it again.

Validation: bundled-clang syntax/metadata check, linked DLL build, settings JSON
round-trip and legacy import tests, simulated reorder/renumber/disconnect/reconnect
selection tests, and discovery of current live Windows taskbars. Installed and loaded v1.6.12 in Explorer; the prior specific selection was
bound to a monitor interface, with every other saved setting preserved. Physical
cable removal/reconnection requires a user check after installation.

API references:
- https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-enumdisplaydevicesw
- https://learn.microsoft.com/en-us/windows/win32/api/winuser/ns-winuser-monitorinfoexw
