# SiriEdge Pre-Rebuild Backup

**Date & Time**: 2026-10-01 21:21 IST  
**Backup Archive**: `SiriEdge_pre_rebuild_backup.tar.gz` (Source tree: `SiriEdge/`, `Tests/`, `Package.swift`, `build_app.sh`, `build_saver.sh`)  
**Status**: ARCHIVED & PRESERVED

---

## 1. Pre-Rebuild UserDefaults Snapshot (`com.antigravity.SiriEdge`)

Raw snapshot taken before clean rebuild:

```json
{
    "NSWindow Frame com_apple_SwiftUI_Settings_window" = "285 281 900 450 0 0 1470 923 ";
    "siri_edge_activity_timeout_minutes" = 5;
    "siri_edge_animation_speed" = "1.25";
    "siri_edge_audio_source" = "System Audio";
    "siri_edge_battery_saver_enabled" = 1;
    "siri_edge_brightness" = 1;
    "siri_edge_charging_reactivity_enabled" = 1;
    "siri_edge_color_palette" = "apple_intelligence";
    "siri_edge_control_mode" = auto;
    "siri_edge_custom_fps" = 60;
    "siri_edge_default_animation" = thinking;
    "siri_edge_fps_mode" = 30;
    "siri_edge_glow_strength" = "0.7";
    "siri_edge_max_performance" = 0;
    "siri_edge_music_reaction_strength" = "0.5";
    "siri_edge_music_reactive_enabled" = 1;
    "siri_edge_per_display_fps" = {
        "Built-in Retina Display" = 30;
    };
    "siri_edge_perf_monitor_enabled" = 0;
    "siri_edge_power_mode" = auto;
    "siri_edge_schema_version" = 2;
    "siri_edge_transparency" = "0.3";
}
```

---

## 2. Target Preserved Preferences (Per Phase 1 & Phase 27)

The clean rebuild preserves and establishes the user's explicit preference profile:

| Setting Key | Preserved Value | Type | Description |
|---|---|---|---|
| `siri_edge_control_mode` | `force_on` | String | Control Mode (Manual ON) |
| `siri_edge_default_animation` | `thinking` | String | Default Animation (Thinking / Chasing Flow) |
| `siri_edge_animation_speed` | `0.65` | Float/Double | Animation Speed multiplier |
| `siri_edge_transparency` | `0.25` | Float/Double | Edge border transparency / base opacity |
| `siri_edge_brightness` | `1.0` | Float/Double | Edge brightness |
| `siri_edge_fps_mode` | `30` | Int | Target FPS Mode |
| `siri_edge_custom_fps` | `60` | Int | Custom FPS fallback |
| `siri_edge_power_mode` | `battery_saver` | String | Power Mode |
| `siri_edge_battery_saver_enabled` | `1` (true) | Bool | Battery Saver flag |
| `siri_edge_music_reactive_enabled` | `1` (true) | Bool | Preserved music setting (unused in rebuild) |
| `siri_edge_music_reaction_strength` | `0.5` | Float/Double | Preserved reaction strength (unused in rebuild) |
| `siri_edge_audio_source` | `System Audio` | String | Preserved audio source (unused in rebuild) |
| `siri_edge_per_display_fps` | `{"Built-in Retina Display": 30}` | Dictionary | Display FPS mapping |
| `siri_edge_activity_timeout_minutes` | `5` | Int | Manual ON Activity Timeout |
| `siri_edge_schema_version` | `2` | Int | Settings Schema Version |

---

## 3. Preservation Guarantee

- This backup file and `SiriEdge_pre_rebuild_backup.tar.gz` will NOT be deleted.
- The rebuild will preserve these exact keys and schema in `EdgeSettings.swift`.
- `defaults read com.antigravity.SiriEdge` will output these preserved values.
