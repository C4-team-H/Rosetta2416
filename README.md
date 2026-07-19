# Drawing Space

*A 2D top-down adventure where you wake up alone on a broken starship. Draw to repair. Explore to survive. Piece together the scattered intelligence of a shattered AI.*

---

## The Premise

Your ship is dead in space. The AI — your only ally — has been splintered across the vessel. The engine is cold. The lights flicker. Your energy drains with every step.

You carry a sketchpad. The ship's repair stations respond to drawings: trace a radio to restore communications, sketch a lightbulb to reignite the ignition coil, draw a brain to reconnect the AI's memory. A Core ML model watches your strokes in real time, judging whether your doodle matches the schematic the ship expects.

**Twenty-three repair missions** stand between you and escape. The Kitchen offers the only relief — draw food, restore energy, keep going. Fail to manage your energy, and it's Game Over: rewind to the last checkpoint, try again.

Built for iPhone and iPad with Apple Pencil support. Control your astronaut with a joystick or tap-to-move with the Pencil — light pressure walks, heavy pressure runs.

---

## The Ship

Six interconnected rooms, each gated by story progress:

| Room | Purpose | Unlock condition |
|---|---|---|
| **Sleeping Room** | Your starting point. A sketchbook of object references hangs on the wall. | Always open |
| **Kitchen** | The only renewable energy source. Draw food to restore 40 Energy. | Always open |
| **Laboratory** | Reassemble the AI's core intelligence. Three drawing challenges. | Reach the lab from Sleeping Room |
| **Engine Room** | Restore propulsion in five escalating phases. Twenty missions total. | Intelligence 40, all Lab missions complete |
| **Storage** | Claim the advanced toolkit. Four missions, gated behind Engine progress. | Engine Progress 60 |
| **Cockpit** | The final three missions. Complete them to win. | Intelligence 100, Engine Progress 100 |

The ship's power state shifts as you progress — emergency darkness, basic power, a mid-game electrical disruption, and finally full restoration. Each state changes the lighting, the atmosphere, and the urgency.

---

## Architecture

The project follows a **systems-over-scenes** architecture. The game world is a SpriteKit scene; the HUD, tactical map, and drawing challenge are SwiftUI overlays. A single `GameSessionState` observable object bridges them all.

### Engine Layer (`GameEngine/`)

| System | Responsibility |
|---|---|
| **Movement** | Joystick and Pencil-controlled navigation with collision-respecting substeps |
| **Collision** | Footprint-based obstacle and wall resolution with sliding |
| **Walkability** | A* pathfinding across rooms, corridors, and dynamic door states |
| **Interaction** | Proximity-based REPAIR / EAT button triggers |
| **Station Visibility** | Centralized rule governing which repair stations appear in both SpriteKit and the Tactical Map |
| **Energy** | Per-second drain, movement multiplier, kitchen restoration, depletion → Game Over |
| **Lighting** | Candle-light vignette, power state transitions, victory flash |
| **Mission** | Objective validation and room-access gating |
| **Map Geometry** | Editor-driven, serializable world layout consumed by both collision and rendering |

### Story Layer (`GameEngine/Story/`)

- **`StoryContent`** — All 23 objective definitions, room access rules, chapter ordering, and drawing prompts.
- **`StoryProgressionSystem`** — `@Observable` state machine. Computes `ObjectiveStatus` from the current chapter, completed IDs, and tool availability. Advances chapters, unlocks doors, triggers cutscenes.
- **`StoryAuthority`** — Validates drawing submissions through the doodle recognizer, routes Kitchen drawings through a separate food pool.
- **`AI Dialogue`** — Contextual dialogue lines triggered by chapter entry, objective completion, power changes, and energy warnings.

### Feature Layer (`Features/`)

| Feature | Description |
|---|---|
| **Gameplay** | `GameplayCoordinator` wires session state, story authority, and the SpriteKit scene. `GameplayHUDView` renders energy, intelligence, engine bars, current objective, and dialogue. |
| **Tactical Map** | A SwiftUI vector overlay. Renders rooms, doors, stations, kitchen, and player positions. Coordinate converter maps SpriteKit world coords → SwiftUI view coords. |
| **Drawing Challenge** | PencilKit canvas with submit/share/clear controls. Shows the target drawing prompt and expected label. |
| **Map Debug** | Editor UI for modifying room geometry, walls, spawn points, stations, and collision bodies in real time. Exportable to JSON. |

### Rendering (`GameEngine/Scenes`, `Nodes/`, `World/`)

- **`GameScene`** — The main SpriteKit scene. Owns the camera, player, joystick, candle light, and game loop. Delegates world construction to `GameWorldBuilder`.
- **`ShipMapNode`** — Renders the floor plan, rooms, corridors, walls, furniture, doors, and debug overlay. Supports incremental geometry updates.
- **`PlayerNode`** — The astronaut character with animated walk cycle (`AstroWalk.atlas`), collision footprint, and interaction sensor.
- **`CandleLightNode`** — A darkness vignette with a warm, flickering light that follows the player.

### Key Design Decisions

- **One layout, two consumers.** `MapGeometryConfiguration` feeds both SpriteKit collision (`WalkabilitySystem`) and the SwiftUI tactical map (`MapCoordinateConverter`). Changing the world once updates both representations.
- **`@Observable` all the way down.** `GameSessionState` → `StoryProgressionSystem` → `SharedStoryState`. SwiftUI views re-render automatically when story progress changes. No manual notifications, no delegates for state propagation.
- **Story effects as value types.** `handle(_:)` and `completeObjective(id:)` return `[StoryEffect]` enums. `GameScene.applyStoryEffects(_:)` interprets them: power transitions, door unlocks, objective completion animations, cutscenes, victory.
- **Kitchen is independent.** The Kitchen does not participate in story progression. It uses a separate interaction path, a separate food drawing pool, and never blocks, locks, or completes. It is a permanent gameplay utility, not a mission.

---

## Station Visibility System

The station/easel visibility system is the most recent architecture addition. Its goal: **only show the repair station relevant to the current active mission**, while always showing the Kitchen.

### The Problem (Before)

Stations were visible based on **player proximity**: walk near any station and it appeared. This cluttered the game world with irrelevant repair points and gave no directional guidance. The Tactical Map had its own separate, hard-coded filtering logic that duplicated the SpriteKit rules.

### The Solution

A single centralized rule lives in `StationVisibilitySystem`:

```swift
func shouldShowStation(interactionID: String) -> Bool {
    if isDebugEnabled { return true }
    if interactionID == "kitchen-food" { return true }
    guard let activeObjective = storySystem.activeObjective else { return false }
    return interactionID == activeObjective.id
}
```

Both consumers query the same system:

```
StationVisibilitySystem (one rule)
├── GameScene.stationVisibilitySystem → SpriteKit node.isHidden
└── TacticalMapViewModel.visibleMarkers → MapMarker.isVisible → .filter(\.isVisible)
```

### When It Updates

- **Every frame** — `GameScene.update()` calls `updateStationVisibility()`.
- **On story events** — `refreshStoryVisuals()` runs after objectives complete, chapters change, or doors unlock.
- **On debug toggle** — entering or exiting map debug mode immediately calls `refreshStoryVisuals()`.
- **On Tactical Map open** — `visibleMarkers` recomputes fresh via the `@Observable` chain.

### Rules Summary

| Condition | SpriteKit | Tactical Map |
|---|---|---|
| Normal gameplay | Only active mission station + Kitchen | Only active mission marker + Kitchen |
| Debug mode active | All stations visible | All station markers visible |
| No active objective (between chapters or all complete) | Only Kitchen visible | Only Kitchen marker visible |
| Objective completed | Station hidden; next mission's station appears | Marker hidden; next mission's marker appears |
| Kitchen (always) | `foodObject` always visible | Kitchen marker always visible |

### Files

- `GameEngine/Systems/StationVisibilitySystem.swift` — the centralized rule (16 lines)
- `GameEngine/World/GameWorldBuilder.swift` — `refreshStoryVisuals()` and `updateStationVisibility()` apply it to SpriteKit nodes
- `Features/TacticalMap/TacticalMapViewModel.swift` — creates visibility system, passes to marker factory
- `Features/TacticalMap/MapMarker.swift` — `TacticalMapMarkerFactory` sets `isVisible` on station and kitchen markers
- `GameEngine/Systems/InteractionSystem.swift` — proximity checks now filter out hidden stations

---

## Tech Stack

| Technology | Role |
|---|---|
| **UIKit** | App host, view controller hierarchy |
| **SpriteKit** | Game world, physics, collision, animation, lighting |
| **SwiftUI** | HUD bars, tactical map overlay, dialogue, drawing challenge UI |
| **PencilKit** | Drawing canvas with pressure sensitivity |
| **Core ML** | Doodle recognition — a custom `HandwritingGameClassificationV2` model |
| **SwiftData** | Story progress persistence with checkpoint snapshots |

---

## Progress

### Completed

- [x] Full 23-mission story with chapter gating, door unlocks, and three power states
- [x] SpriteKit game world with joystick and Apple Pencil tap-to-move
- [x] Collision-respecting movement with substep resolution and wall sliding
- [x] Animated astronaut character with walk-cycle texture atlas
- [x] Energy system — drain, movement multiplier, Kitchen restoration, Game Over
- [x] Proximity-based interaction: REPAIR button for stations, EAT button for Kitchen
- [x] Core ML doodle recognition with confidence threshold (50%)
- [x] Drawing challenge UI with prompt display, submit, clear, and retry
- [x] Candle-light vignette with flicker animation, synchronized to player
- [x] Lighting transitions: emergency → basic power → disrupted → fully restored
- [x] Tactical Map overlay — rooms, doors, stations, Kitchen, player, teammate markers
- [x] Map coordinate converter — SpriteKit world coords ↔ SwiftUI view coords with padding and aspect ratio preservation
- [x] Map debug editor — toggle visibility layers, edit geometry, export JSON, test collision
- [x] AI dialogue system — contextual lines on chapter entry, objective complete, power change, energy low
- [x] Checkpoint system with automatic SwiftData persistence
- [x] Checkpoint retry on Game Over — reset to last checkpoint, restore minimal energy
- [x] Main Menu — continue saved game or start new
- [x] Victory screen with session stats
- [x] Background music and sound effects
- [x] Object reference album in Sleeping Room
- [x] ★ **Station Visibility System** — centralized, mission-based easel visibility across SpriteKit and Tactical Map

### In Progress / Upcoming

- [ ] **Progress bar assets** — AI Intelligence, Engine, dan Energy butuh visual bar yang terbaca sepintas dan selaras dengan estetika kapal yang rusak. Bukan sekadar angka, tapi indikator yang terasa hidup.
- [ ] **Button assets** — REPAIR, EAT, SUBMIT, dan tombol-tombol interaksi lainnya masih polos. Perlu sentuhan visual yang terasa taktil — seolah tombol itu benar-benar bisa ditekan di dalam dunia kapal.
- [ ] **Interaction object slicing** — Setiap objek yang bisa disentuh pemain (stasiun reparasi, panel makanan, terminal) perlu di-slice dari sprite sheet menjadi komponen yang siap dipakai di scene. Akurasi potongan menentukan seberapa natural interaksi terasa.
- [ ] **Dialog bar** — Panel dialog yang muncul di bagian bawah layar saat AI berbicara. Harus punya karakter: sedikit glitch, sedikit hangat, mencerminkan kepribadian AI yang retak namun setia.
- [ ] **Mission bar** — Objective tracker yang selalu terlihat di HUD. Pemain harus bisa melirik dan langsung tahu: "Apa yang harus aku gambar sekarang?" Tanpa membuka menu, tanpa kehilangan ritme.
- [ ] **Narrative dialogue list** — Semua dialog AI ditulis dulu dalam bentuk daftar naratif sebelum diintegrasikan ke sistem. Mencakup sapaan awal, reaksi keberhasilan/kegagalan misi, transisi antar chapter, peringatan energi rendah, dan momen-momen sunyi di antara perbaikan.

---

## Getting Started

1. Clone the repository.
2. Open `GameClassification.xcodeproj` in Xcode 26+.
3. Select an iOS 26 simulator or connected device.
4. Build and run the `GameClassification` scheme.

For map editing, launch with the `-ShipMapDebug` argument to enable the debug overlay and editor tools.

---

## Team

Built by **C4-team-H** — a collaborative iOS game development project.
