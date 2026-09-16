# 10m Olympic Shooting Simulator

An authentic, physics-inspired 10m Air Pistol and 10m Air Rifle shooting simulator built entirely in SwiftUI for iOS, iPadOS, and macOS. The simulator replicates ISSF (International Shooting Sport Federation) target specifications, real-time decimal scoring, human physiological aiming sway, and optical sighting mechanics.

---

## Overview

The simulator reproduces the precision and discipline required in Olympic 10-meter shooting events. Every target ring, pellet caliber, optical sight aperture, and scoring threshold is mathematically calibrated against official ISSF regulations.

### Key Highlights
- Strict adherence to ISSF target dimensions and millimeter-to-screen scaling.
- Realistic physiological breath-holding dynamics, micro-tremor, and post-shot recoil kinetics.
- Weapon-specific optical sighting systems (Pistol W-notch post sight and Rifle concentric ring peep sight).
- Decimal scoring engine (10.0 to 10.9) modeled after electronic scoring systems (ISSF / SIUS).
- Real-time HUD magnifier lens for millimeter-level shot verification.
- Match score tracking across 60 competition shots formatted in an Olympic 3x2 series matrix.
- Native bilingual interface (Traditional Chinese and English).

---

## Disciplines and Target Specifications

The application models the two primary Olympic 10-meter shooting disciplines:

### 10m Air Pistol
- Target Card Dimensions: 170 mm x 170 mm
- Ring 1 Diameter: 155.5 mm
- Black Aiming Mark (Rings 7 to 10): 59.5 mm diameter
- 10-Ring Diameter: 11.5 mm
- Inner 10-Ring (X-Ring) Diameter: 5.0 mm
- Ammunition Caliber: 4.5 mm (.177 in)
- Scoring Logic:
  - 10.9 Maximum Score: The 4.5 mm pellet imprint must remain completely within the 5.0 mm inner 10-ring without breaching the boundary line.
  - Decimal scores from 10.0 to 10.8 scale progressively between the 10-ring and the inner 10-ring.

### 10m Air Rifle
- Target Scoring Face (Ring 1): 45.5 mm diameter
- Black Aiming Mark (Rings 4 to 9): 30.5 mm diameter (Rings 1 to 3 sit on outer card)
- 9-Ring Diameter: 5.5 mm
- 10-Ring Center Dot: 0.5 mm diameter (white dot)
- Ammunition Caliber: 4.5 mm (.177 in)
- Scoring Logic:
  - 10.0 Score Threshold: Achieved when the edge of the bullet imprint touches the 0.5 mm center dot (the center of the pellet lies directly on the 9-ring boundary).
  - 10.9 Maximum Score: Achieved when the 4.5 mm bullet sits completely inside the 5.5 mm 9-ring without touching the 9-ring boundary line.
  - Sub-millimeter decimal gradation based on radial offset from the center.

---

## Mechanics and Controls

### Breath Control and Sway Simulation
- **Resting Sway**: When not holding breath, the sight sways naturally with multi-harmonic sinusoidal curves representing pulse and micro-postural oscillation.
- **Hold-to-Aim**: Touching and holding the target triggers breath-hold stabilization, smoothly dampening sight drift over a 3.5-second optimal stability window.
- **Fatigue Degradation**: Prolonged breath-holding beyond the peak window introduces progressive tremors, mimicking physiological oxygen depletion.
- **Release-to-Fire**: Lifting the finger releases the trigger instantly, computing the projectile impact vector at the precise moment of release.
- **Recoil Vector**: Fires with directional kinetic recoil and plays metallic target impact audio.

### Sighting Systems
- **Pistol (Three-Point Alignment)**:
  - Extra-large W-notch rear sight blade paired with a squared front sight post.
  - Zeroed for sub-six aiming (settling between Ring 5 and Ring 6 beneath the black bullseye).
- **Rifle (Concentric Rings)**:
  - Rear diopter peep hole aligned with front annular tunnel sight.
  - Sighted by nesting the front aperture concentrically over the target's outer ring and centering the black bullseye.

### Heads-Up Display (HUD)
- **Real-Time Magnifier Lens**:
  - Automatically isolates and enlarges the central target area up to Ring 8.
  - Displays instantaneous radial offset, shot quadrant, and exact decimal score.
- **Olympic Series Matrix**:
  - Live 3x2 series scoreboard tracking Series 1 through Series 6 (10 shots per series, 60 shots total).
- **Target Imprint Filter**:
  - Selectable pellet imprint retention: 1 shot, 5 shots, or 10 shots.

---

## Technical Architecture

```
ShootingGame/
├── ShootingGame/
│   ├── MyApp.swift            # Application entry point and runtime font registration
│   ├── ContentView.swift      # Core application logic, vector rendering, and simulation engine
│   ├── Assets.xcassets        # Vector target references, emblems, and app icon assets
│   ├── Fonts/                 # Embedded typography (Dela Gothic One, Orbitron)
│   ├── metal_hit.wav          # Acoustic sample for metallic pellet impact
│   └── metal_hit.m4a          # Compressed audio fallback
└── ShootingGame.xcodeproj     # Xcode project and multiplatform deployment configurations
```

### Technologies Used
- **SwiftUI**: Pure declarative vector rendering for targets, rings, apertures, and dynamic HUD components without external bitmap dependencies.
- **AVFoundation**: Low-latency audio playback for firearm release and metallic impact acoustics.
- **CoreText**: Dynamic font registration enabling custom typographic hierarchy.
- **Combine / Timers**: High-frequency physics loop running at 60 FPS for smooth sway rendering.

---

## System Requirements

- **iOS / iPadOS**: 17.0 or later
- **macOS**: 14.0 or later
- **Xcode**: 16.0 or later
- **Swift**: 5.9 or later

---

## Building and Running

1. Clone the repository:
   ```bash
   git clone https://github.com/DDan32/ShootingGame.git
   cd ShootingGame
   ```
2. Open the project in Xcode:
   ```bash
   open ShootingGame.xcodeproj
   ```
3. Select your target device (iPhone, iPad, or Mac Designed for iPad) and run (`Cmd + R`).

---

## License

This project is developed for educational and sports simulation purposes. All target specifications are based on public International Shooting Sport Federation (ISSF) rules and technical guidelines.
