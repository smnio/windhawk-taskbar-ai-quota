# Specific monitor selection (1.6.13)

Previously, the specific-display dropdown showed primary-first taskbar list positions.
Disconnecting another monitor could change that position and move the widget.

Version 1.6.12 saved the correct monitor interface, but labelled it with the GDI
source number (`\\.\DISPLAYn`). Those numbers can differ from Windows Settings'
Identify numbers. For example, on this system GDI DISPLAY1 uses DisplayPort
connector instance 2 and Windows identifies it as display 3.

Version 1.6.13 queries `QueryDisplayConfig(QDC_ALL_PATHS)`, keeps each connected
target once (including connected targets disabled in the desktop), and orders
those targets by adapter, connector technology, and connector instance. It maps
the resulting number back to the saved monitor interface. Active-path order and
primary-first taskbar order do not determine the label. API failure shows the
number as unavailable rather than reverting to an incorrect GDI number.

The connector ordering matches the supplied Identify screenshots. Microsoft's
public display APIs do not document the Settings numbering algorithm; unusual
multi-adapter or connector configurations may need further verification. This
affects labels only: the saved monitor interface determines placement.

The saved selection uses the monitor interface returned by `EnumDisplayDevicesW`
with `EDD_GET_DEVICE_INTERFACE_NAME`, rather than a display number, HMONITOR,
HWND, or list position.

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
selection tests, connector-order numbering and renumbering regression tests, and
discovery of current live Windows taskbars. Installed and loaded v1.6.13 in Explorer. The selected Dell monitor label changed
from GDI display 1 to Identify display 3, preserving the exact saved monitor
interface and every other saved setting. Physical
cable removal/reconnection requires a user check after installation.

API references:
- https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-enumdisplaydevicesw
- https://learn.microsoft.com/en-us/windows/win32/api/winuser/ns-winuser-monitorinfoexw

- https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-querydisplayconfig
- https://learn.microsoft.com/en-us/windows/win32/api/wingdi/ns-wingdi-displayconfig_target_device_name
- https://github.com/MartinGC94/DisplayConfig/blob/main/src/DisplayConfig/API/DisplayConfig.cs
