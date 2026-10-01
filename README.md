# SiriEdge ⚡

> **Native macOS Full-Screen Animated Edge-Glow Overlay**  
> Inspired by the fluid, continuous perimeter light field of modern Siri and Apple Intelligence edge effects.

---

## 🌟 Visual Refinements & Characteristics

* 🪶 **Ultra-Thin & Transparent Luminous Energy Line**: 
  - **Core energy line**: ~2.2 pt hugging the physical display bezel.
  - **Inner glow**: ~5.5 pt with smooth exponential falloff.
  - **Ambient bloom**: ~14.0 pt soft diffused transparent glow around active pulses.
  - **Cutoff threshold**: ~24 pt from the physical bezel. Beyond 24 pt, alpha drops strictly to `0.00`, ensuring the **macOS Menu Bar and Dock are 100% crystal-clear and unobstructed**.
* 🌊 **3 Elongated Flowing Light Streaks**: Concentrates energy into flowing, elongated light streams with soft asymmetric trailing tails rather than an artificial static glowing box.
* 🕊️ **Whisper-Quiet Base Illumination**: `baseIntensity` is reduced to 0.05, eliminating solid rectangular borders and letting dynamic flowing movement create the visual delight.
* 🌈 **Curated Siri Spectrum**: Smooth harmonious blending of Electric Cyan-Blue, Deep Blue, Violet, Purple, Magenta, and Radiant Pink.
* 🖥️ **Full Physical Display Coverage**: Locked to `NSScreen.frame` across all spaces, displays, and resolutions.

---

## 🎬 5-Stage Interactive Animation Flow

| Stage | Trigger / State | Visual Characteristics | Motion & Dynamics |
| :--- | :--- | :--- | :--- |
| **1. ACTIVATION** | App launch / `⌘⇧Space` | Rapid, smooth fade-in of the gradient border | **Light streaks shoot rapidly from all 4 corners** outward with luminous leading wavefront flares to fill the perimeter. |
| **2. LISTENING** | Waiting for user input (`⌘1`) | Gentle, rhythmic pulsing (breathing) of glow width and ambient bloom | Slow, calming, continuous fluid gradient flow around the edges. |
| **3. THINKING / PROCESSING** | Processing request (`⌘2`) | Colors become **hyper-vibrant** with elevated saturation and luminance | Flow speed accelerates (2.4×), creating a **dynamic multi-pulse "chasing" orbital flow** around the screen. |
| **4. SPEAKING / RESPONDING** | Delivering answer (`⌘3`) | Border expands with audio-energy waveforms | **Harmonic wave-like undulations along the screen perimeter**, synchronized with speech rhythm and vocal cadence. |
| **5. DISMISSAL** | Interaction ends (`⌘⇧Space` / Hide) | Smooth fade-out of the entire border overlay | **The light recedes back into the 4 corners** before disappearing completely. |

---

## 🎛️ Tunable Parameters

All visual constants are centralized in [`EdgeConstants.swift`](file:///Users/benadict/Documents/antigravity%20projects/animation/SiriEdge/Rendering/EdgeConstants.swift):

* `coreWidth` (default: `2.2 pt`): Width of the thin bright energy core line.
* `innerGlowWidth` (default: `5.5 pt`): Width of the soft inner glow.
* `bloomRadius` (default: `14.0 pt`): Extent of the diffused ambient bloom.
* `maxGlowExtent` (default: `24.0 pt`): Distance from the edge before fragment discard.
* `baseIntensity` (default: `0.05`): Ambient perimeter illumination.
* `coreIntensity` (default: `0.95`): Energy core peak brightness.
* `pulseIntensity` (default: `1.05`): Moving light pulse peak intensity.
* `bloomIntensity` (default: `0.18`): Soft bloom brightness.
* `secondaryIntensity` (default: `0.32`): Trailing light tail intensity.
* `overallOpacity` (default: `0.88`): Master alpha multiplier.
* `animationSpeed` (default: `0.65`): Time scale for smooth, unhurried flow.

---

## ⌨️ Controls & Shortcuts

* **`⌘ + ⇧ + Space`**: Toggle Edge Overlay (Activation $\leftrightarrow$ Dismissal)
* **`⌘ + 1`**: Switch to **Listening Mode** (Gentle Rhythmic Pulsing Glow)
* **`⌘ + 2`**: Switch to **Thinking / Processing Mode** (Hyper-Vibrant Chasing Flow)
* **`⌘ + 3`**: Switch to **Speaking / Responding Mode** (Audio-Wave Undulations)
* **`⌘ + R`** (or Menu Bar item): **Run Interactive Demo** (Automated 5-stage lifecycle demonstration)
* **`⌥ + ⌘ + D`**: Toggle Real-time Debug HUD + 1.5pt Physical Edge Indicator
* **`⌘ + Q`**: Quit SiriEdge

---

## 🛠️ Building & Running

```bash
# Run with Swift
swift run

# Or launch the macOS App Bundle
open SiriEdge.app
```
# mac-os-animation
