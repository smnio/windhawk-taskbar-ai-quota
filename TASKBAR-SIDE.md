# Taskbar side setting — 2026-10-02

Version 1.6.7 adds a Taskbar side dropdown on Layout, immediately after Specific
display. Left is the default for new settings and upgraded settings with no
side preference. Right retains the placement before the tray and clock.

Left placement selects the TaskbarFrameRepeater's ancestor RootGrid and inserts
an auto-sized leading column. Existing children move one column to the right,
reserving space for the quota UI. Right placement uses SystemTrayFrameGrid as
before, including its StackPanel variant. Removal restores the existing columns;
an originally implicit single star column is removed again when still owned
alone. Each taskbar instance tracks its own inserted definitions and releases
them on its owner UI thread.

The setting is stored in settings_v1 JSON as taskbarSide, normalizes unknown
values to left, participates in default Settings equality/autosave, and resets
with the Layout page. Account identity hashes and encrypted token storage are
unchanged. The Right tray gap label is now Right gap since it also separates
the left-positioned quota UI from taskbar content.

Verification:

- Bundled-clang syntax check and full production DLL compilation/link passed.
- Native settings tests passed for both side round-trips, legacy settings with
  non-default display/account configuration, credential identity stability, and
  invalid stored/enum values. The harness keeps a process MTA alive, matching
  the mod's WinRT factory lifetime requirement.
- Existing synthetic network redirect regression tests passed.
- Elevated upgrade preserved the existing mod-owned storage, confirmed the old
  DLL unloaded, and loaded local@taskbar-ai-quota_1.6.7_790070.dll into ten
  Explorer processes. The catalog copy remains disabled.
- No Explorer crash event was found in the observed upgrade window.

Desktop inspection remained unavailable (missing computer-use native pipe).
Pixel placement, switching sides interactively, preview rendering, and live
credential refresh after this upgrade have not been visually verified here.
Open Settings -> Layout to select the side or enable Preview test data.

The previous production DLL and source backup remain available locally for
rollback. No scheduled tasks were created.
