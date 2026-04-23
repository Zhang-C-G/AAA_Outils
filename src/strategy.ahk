; Auto-refresh strategy for default Top list

GetBehaviorDefaults() {
    return Map(
        "auto_refresh_enabled", 1,
        "refresh_every_uses", 3,
        "refresh_every_minutes", 5
    )
}

NormalizeBehavior(behavior) {
    if !behavior.Has("auto_refresh_enabled") {
        behavior["auto_refresh_enabled"] := 1
    }
    behavior["auto_refresh_enabled"] := behavior["auto_refresh_enabled"] ? 1 : 0

    if !behavior.Has("refresh_every_uses") || behavior["refresh_every_uses"] < 1 {
        behavior["refresh_every_uses"] := 3
    }

    if !behavior.Has("refresh_every_minutes") || behavior["refresh_every_minutes"] < 1 {
        behavior["refresh_every_minutes"] := 5
    }
}

RestartAutoRefreshTimer() {
    global gBehavior, gUsesSinceAutoRefresh
    SetTimer(AutoRefreshTick, 0)
    gUsesSinceAutoRefresh := 0

    if !gBehavior["auto_refresh_enabled"] {
        return
    }

    intervalMs := gBehavior["refresh_every_minutes"] * 60 * 1000
    SetTimer(AutoRefreshTick, intervalMs)
}

AutoRefreshTick(*) {
    global gBehavior
    if !gBehavior["auto_refresh_enabled"] {
        return
    }
    MaybeRefreshDefaultMatches("timer")
}

MaybeRefreshDefaultMatches(source := "manual") {
    global gPanelVisible, gCurrentQuery

    if !gPanelVisible {
        return false
    }

    if (Trim(gCurrentQuery) != "") {
        return false
    }

    RefreshMatches("")
    WriteLog("default_refresh", "source=" source)
    return true
}
