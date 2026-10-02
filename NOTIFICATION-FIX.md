# Duplicate notifications — 2026-10-02

Version 1.6.11 corrects two notification behaviors and prevents duplicate polling.

The mod was injected into 20 Explorer processes, but only PID 13292 owned the
primary taskbar. The old lifecycle started fetch workers in every injected
process. Mod-owned settings are process-local after loading, so changing the
notification preference in the taskbar settings window did not update the
cached preference in folder-only Explorer processes. Those processes could
continue requesting quotas and sending independent threshold warnings.

The new lifecycle starts workers only in the primary-taskbar owner when it is
known. A fetch worker created during shell startup waits for that taskbar and
exits if another process owns it. Notification dispatch also checks ownership
and checks the current enabled setting while holding the settings lock through
dispatch. Folder-only instances remain loaded but do not run quota workers.

Threshold warnings use an identity-keyed ledger per account and quota bar.
An initial observation primes the state silently. A crossing can send only if
that bar has not already warned for the same reset timestamp. The timestamp is
stored in Windhawk storage before dispatch, preventing a repeated warning
after reload. A storage failure suppresses the warning. Lower usage does not
re-arm within the same window. Quotas without a reset timestamp can warn only
once per stored account/bar. Disabled notifications and enabling them while
already above the threshold do not replay old warnings.

Validation:

- Source syntax and full production DLL compilation/link passed.
- Native notification tests passed: disabled state, 100 repeated polls,
  below/above fluctuations in the same window, a new reset window, persisted
  deduplication after reload, startup at high usage, missing usage, and
  independent account/bar keys. Existing placement/settings tests also passed.
- Installed local@taskbar-ai-quota 1.6.11 using the checked DLL hash. Upgrade
  confirmed old DLL unload and new DLL activation.
- Queried actual Win32 thread start addresses using NtQueryInformationThread:
  the primary-taskbar owner had two mod threads (fetch and taskbar discovery);
  all 19 other Explorer processes had zero. All thread queries succeeded.
  Ignored build/notification-workers-after.json contains the local probe output.
- Persisted notifications remained false after installation. No real account
  tokens were inspected and no test notifications were intentionally sent.

Live notification appearance and an actual future threshold crossing have not
been exercised visually. Existing Windows notification-center history is not
deleted by this update. The fix prevents new duplicate warnings.
