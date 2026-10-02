#include "local@taskbar-ai-quota.wh.cpp"
#include <cstdio>

static void Require(bool condition, const char* message) {
    if (!condition) { std::fprintf(stderr, "FAIL: %s\n", message); std::exit(1); }
}

int main() {
    std::setvbuf(stdout, nullptr, _IONBF, 0);
    // Match the mod's process-wide MTA lifetime for cached WinRT factories.
    using IncrementMta = HRESULT(WINAPI*)(void**);
    auto increment = reinterpret_cast<IncrementMta>(GetProcAddress(
        LoadLibraryW(L"combase.dll"), "CoIncrementMTAUsage"));
    void* cookie = nullptr;
    Require(increment && SUCCEEDED(increment(&cookie)), "process MTA lifetime");
    winrt::init_apartment(winrt::apartment_type::multi_threaded);
    Settings settings;
    Require(settings.taskbarSide == TaskbarSide::Left, "new installations default left");
    Require(settings.verticalAlignment == WidgetVerticalAlignment::Center &&
            settings.verticalOffset == 0, "vertical default is centered without offset");
    settings.taskbarMonitorMode = TaskbarMonitorMode::Specific;
    settings.taskbarMonitorNumber = 2;
    settings.barLength = 60;
    settings.accounts = {{L"openai", L"Personal Codex"}, {L"anthropic", L"Personal Claude"}};
    auto codexIdentity = AccountIdentityHash(settings.accounts[0]);
    auto claudeIdentity = AccountIdentityHash(settings.accounts[1]);
    for (auto side : {TaskbarSide::Left, TaskbarSide::Right}) {
        settings.taskbarSide = side;
        Settings restored;
        Require(DeserializeSettings(SerializeSettings(settings), &restored), "settings parse");
        Require(restored == settings, "both placements round-trip with non-default settings");
        Require(AccountIdentityHash(restored.accounts[0]) == codexIdentity &&
                AccountIdentityHash(restored.accounts[1]) == claudeIdentity,
                "side changes preserve credential identity keys");
    }
    auto legacy = JsonObject::Parse(SerializeSettings(settings));
    legacy.Remove(L"taskbarSide");
    Settings migrated;
    Require(DeserializeSettings(legacy.Stringify().c_str(), &migrated), "old settings parse");
    settings.taskbarSide = TaskbarSide::Left;
    Require(migrated == settings, "upgrade defaults left and preserves accounts and configuration");
    legacy.SetNamedValue(L"taskbarSide", JsonValue::CreateStringValue(L"invalid"));
    Require(DeserializeSettings(legacy.Stringify().c_str(), &migrated) &&
                migrated.taskbarSide == TaskbarSide::Left, "invalid stored side defaults left");
    for (auto alignment : {WidgetVerticalAlignment::Top, WidgetVerticalAlignment::Center,
                           WidgetVerticalAlignment::Bottom}) {
        for (int offset : {-15, 0, 15}) {
            settings.verticalAlignment = alignment;
            settings.verticalOffset = offset;
            Require(DeserializeSettings(SerializeSettings(settings), &migrated) &&
                    migrated == settings, "vertical alignment and signed offsets round-trip");
        }
    }
    legacy.Remove(L"verticalAlignment");
    legacy.Remove(L"verticalOffset");
    Require(DeserializeSettings(legacy.Stringify().c_str(), &migrated) &&
            migrated.verticalAlignment == WidgetVerticalAlignment::Center &&
            migrated.verticalOffset == 0, "old settings migrate to center and zero offset");
    settings.verticalAlignment = static_cast<WidgetVerticalAlignment>(123);
    settings.verticalOffset = -1000;
    NormalizeSettings(&settings);
    Require(settings.verticalAlignment == WidgetVerticalAlignment::Center &&
            settings.verticalOffset == -100, "vertical alignment normalizes and offset clamps");
    settings.taskbarSide = static_cast<TaskbarSide>(123);
    NormalizeSettings(&settings);
    Require(settings.taskbarSide == TaskbarSide::Left, "invalid enum normalizes left");
    ThresholdNotificationState notification;
    Require(!UpdateThresholdNotification(notification, 20, 1000, 90, true), "initial observation is silent");
    Require(UpdateThresholdNotification(notification, 95, 1000, 90, true), "first threshold crossing notifies");
    for (int i = 0; i < 100; ++i) {
        Require(!UpdateThresholdNotification(notification, 100, 1000, 90, true), "repeated polls do not notify");
    }
    Require(!UpdateThresholdNotification(notification, 70, 1000, 90, true) &&
            !UpdateThresholdNotification(notification, 95, 1000, 90, true),
            "usage wobble does not re-arm within the same window");
    Require(!UpdateThresholdNotification(notification, 10, 2000, 90, true) &&
            UpdateThresholdNotification(notification, 95, 2000, 90, true),
            "next reset window can notify once");
    ThresholdNotificationState disabled;
    Require(!UpdateThresholdNotification(disabled, 10, 1000, 90, false) &&
            !UpdateThresholdNotification(disabled, 100, 1000, 90, false),
            "disabled notifications never fire");
    Require(!UpdateThresholdNotification(disabled, 100, 1000, 90, true),
            "enabling does not replay an existing high usage warning");
    ThresholdNotificationState restoredNotification;
    restoredNotification.notified = true;
    restoredNotification.notifiedReset = 1000;
    Require(!UpdateThresholdNotification(restoredNotification, 20, 1000, 90, true) &&
            !UpdateThresholdNotification(restoredNotification, 95, 1000, 90, true),
            "persisted window suppresses repeat after reload");
    ThresholdNotificationState startupHigh;
    Require(!UpdateThresholdNotification(startupHigh, 100, 1000, 90, true),
            "startup at an existing high quota does not spam");
    Require(!UpdateThresholdNotification(notification, -1, 2000, 90, true),
            "unavailable usage leaves warning state unchanged");
    Require(NotificationStorageKey(codexIdentity, 0) != NotificationStorageKey(claudeIdentity, 0) &&
            NotificationStorageKey(codexIdentity, 0) != NotificationStorageKey(codexIdentity, 1),
            "deduplication is independent per account and quota bar");
    std::puts("PASS: placement/settings preservation and notification disable, once-per-window, reload, startup, independent quota state");
    winrt::uninit_apartment();
}
