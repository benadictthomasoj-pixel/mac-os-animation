# SIRIEDGE STABILIZATION CHECKPOINT

**Date:** 2026-09-29  
**Status:** Pre-Stabilization & Optimization Audit Baseline  

---

## 1. Executive Summary

This checkpoint captures the complete architecture, settings schema, build state, energy baseline, and identified stabilization requirements before beginning the stabilization and optimization pass. In accordance with master instructions, the visual identity, perimeter geometry, and Think Processing animation will NOT be redesigned or replaced. The objective is stability, persistent settings across macOS updates, low battery drain, display refresh synchronization, charging reactivity, and codebase cleanup.

---

## 2. Current Architecture

```
[System Events: ScreenCaptureKit Audio, IOKit Power, Distributed Notifications]
                                  │
                                  ▼
                     AutoTriggerMonitor (Background)
                                  │
                                  ▼
                      AudioReactiveEngine (SCStream)
                                  │
                                  ▼
                         AudioAnalyzer (vDSP)
                                  │
                                  ▼
                      SiriEdgeTriggerController
                                  │
                                  ▼
                        OverlayWindowManager
                                  │
                                  ▼
                   OverlayPanel (Physical NSScreen)
                                  │
                                  ▼
                         EdgeGlowView (MTKView)
                                  │
                                  ▼
                       EdgeRenderer & Metal Shader
```

---

## 3. Current User Settings (Source of Truth)

Inspected live from `com.antigravity.SiriEdge`:
- `siri_edge_control_mode`: `"force_on"`
- `siri_edge_default_animation`: `"thinking"` (Think Processing)
- `siri_edge_animation_speed`: `0.65`
- `siri_edge_transparency`: `0.25`
- `siri_edge_brightness`: `1.0`
- `siri_edge_fps_mode`: `"30"`
- `siri_edge_custom_fps`: `60`
- `siri_edge_power_mode`: `"battery_saver"`
- `siri_edge_battery_saver_enabled`: `true`
- `siri_edge_music_reactive_enabled`: `true`
- `siri_edge_music_reaction_strength`: `0.5`
- `siri_edge_audio_source`: `"System Audio"`
- `siri_edge_per_display_fps`: `{"Built-in Retina Display": "30"}`
- `siri_edge_perf_monitor_enabled`: `false`

> [!IMPORTANT]
> These settings represent the user's intentional configuration and MUST NOT be reset or replaced with initial defaults.

---

## 4. Current Build & Bundle State

- **App Bundle:** `SiriEdge.app` (2.0 MB)
- **Screen Saver Bundle:** `SiriEdge.saver` (1.4 MB)
- **Compilation Toolchain:** CommandLineTools (`DEVELOPER_DIR="/Library/Developer/CommandLineTools"`)
- **Metal Shader:** `EdgeGlow.metal` (both embedded source in `EdgeRenderer.swift` and standalone resource in `Resources/Shaders/EdgeGlow.metal`)
- **Supported Architectures:** Apple Silicon (`arm64-apple-macos13.0`)

---

## 5. Battery & Energy Baseline (Measured)

From `SiriEdge_5Min_Idle_Battery_Report.json`:
- **AUTO Idle on Battery (No Music):**
  - CPU Usage: `0.12%`
  - Idle Wakeups/s: `41.2`
  - macOS Power Score: `0.14`
  - Render Callbacks/s: `0.0`
  - Presented FPS: `0.0`
  - Metal Command Buffers/s: `0.0`
  - GPU Activity: `0.0%`
  - Window State: Hidden / Ordered Out
  - MTKView State: `isPaused = true`

---

## 6. Identified Deficiencies & Optimization Tasks

1. **Versioned Settings Schema & Persistence:**
   - Need a formal `SiriEdgeSettingsSchema` with `version: Int` (e.g. Version 2), `Codable` support, atomic persistence to both standard `UserDefaults` and `ScreenSaverDefaults`, and robust schema migration so macOS updates never reset settings.
   - Separate physical display capabilities (resolution, refresh rate, scaling, notch) from user preferences.
   - Add explicit persistent fields: `glowStrength`, `colorPalette`, `activityTimeoutDuration`, `isChargingReactivityEnabled`.
   - Never overwrite existing keys with defaults; load existing keys and migrate gracefully.

2. **5-Minute Activity Timeout:**
   - In manual mode or when manually triggered, provide an auto-off activity timer (default: 5 minutes; configurable: Never, 1m, 5m, 10m, 30m) without terminating background AUTO monitoring.

3. **Menu Bar Branding Cleanup:**
   - Remove `" SiriEdge"` / `"Siri"` text from the menu bar button. Display strictly the crisp circular icon (`SiriEdgeMenuBarIcon`).

4. **Settings UI Rewrite:**
   - Reorganize sections into:
     - GENERAL
     - ANIMATION
     - DISPLAY
     - AUDIO REACTIVE
     - POWER & BATTERY
     - AUTOMATION
     - ADVANCED
     - ABOUT
   - Clarify all terminology: "Frame Rate", "Border Transparency", "Glow Brightness", "Glow Intensity", etc.
   - Display real live runtime values for Current Display, Refresh Rate, Effective Frame Rate, Power Source, Power Mode, Audio State, System Audio, Glow State, and Metal Renderer.

5. **Charging Animation / Reactivity:**
   - Subtle charging response upon AC adapter connection (brief smooth perimeter energy pulse) while respecting the rule that charger connection alone never keeps the glow continuously active.

6. **Color Configuration Persistence:**
   - Maintain color palette persistence so macOS updates, theme changes, or display re-attachments never alter user colors.

7. **Code & Resource Cleanup:**
   - Remove redundant SPM bundle copy in `build_app.sh` (`Contents/MacOS/SiriEdge_SiriEdge.bundle`).
   - Clean up old temporary files (`build_err.txt`, `sample_out.txt`).
   - Clean and optimize codebase without breaking references.
