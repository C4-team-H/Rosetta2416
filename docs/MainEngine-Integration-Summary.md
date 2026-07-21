# MainEngine Integration Summary

## Overview
Successfully integrated `MainEngine.png` as a unified visual replacement for 7 engine-core missions with interaction radius 76 and 2pt white outline.

## Replaced Missions
The following 7 missions now use the `MainEngineControlNode` sprite instead of individual orange rectangle stations:
1. `engine-calibration-port`
2. `engine-cooling-restart`
3. `engine-core-reconnect`
4. `engine-navigation-sync`
5. `engine-pressure-feed`
6. `engine-propulsion-calibration`
7. `engine-reactor-stabilizer`

## Implementation Details

### Asset Integration
- **Asset**: `GameClassification/Resources/Assets.xcassets/MainEngine.imageset/MainEngine.png`
- **Source**: `/users/neuhendra/downloads/rosetta/MainEngine.png`
- **Contents.json**: Created with universal 1x scale configuration

### Coordinate System
- **Anchor**: `object-engine-core` map object
- **Position Property**: `MapGeometryConfiguration.mainEngineCorePosition`
- **Derivation**: Directly uses anchor position without offset

### Node Implementation
- **Class**: `MainEngineControlNode`
- **Pattern**: Follows `EnginePipeControlNode` template exactly
- **Artwork Scale**: 0.8
- **Interaction Radius**: 76 (scaled)
- **Outline Width**: 2pt (scaled)
- **Shader**: 32-sample outline with smoothstep anti-aliasing
- **Highlight**: Smooth animated transition (0.18s, smoothstep easing)

### Scene Integration
- **Property**: `GameScene.mainEngineControlNode: MainEngineControlNode?`
- **Constant**: `GameScene.mainEngineCoreInteractionIDs: Set<String>` (7 IDs)
- **Creation**: `GameWorldBuilder.createMainEngineControl()`
- **Lifecycle**: Called in `didMove`, `applyPendingMapGeometry`, `forceMapGeometryRefresh`
- **Z-Position**: 2 (furniture layer, below candle overlay at 109.5)

### Interaction System
- **Visibility Rule**: `isMainEngineInteractable` checks if any of 7 missions are `.available` or `.active`
- **Proximity Check**: Integrated into `checkProximityToInteractiveObject()` via `mainEngineControlCandidate`
- **Selection**: Uses existing nearest-station logic with interaction radius 76
- **Button**: Reuses "REPAIR" action button
- **Behavior**:
  - Hidden when no engine-core mission is active
  - Shows white outline when player is within radius and mission is active
  - Clears outline/UI when leaving radius or mission becomes inactive
  - Clears `activeStationID` and interaction button when hidden

### Station Suppression
- **Guard**: `createInteractiveStations()` excludes all 7 engine-core station IDs
- **Result**: No legacy orange rectangle/shape nodes are created for these missions
- **Stations Kept**: All other stations (non-engine-core missions) remain unchanged

### Tactical Map
- **Marker Position**: `TacticalMapMarkerFactory` remaps all 7 engine-core station markers to `mainEngineCorePosition`
- **Result**: All 7 mission markers point to the same sprite location on the tactical map
- **Visibility**: Follows centralized `StationVisibilitySystem` rules

### Refresh & Visibility
- **Story Visuals**: `refreshStoryVisuals()` updates visibility and clears state when hidden
- **Station Visibility**: `updateStationVisibility()` syncs every frame via visibility system
- **Input Suspension**: Resets highlight when gameplay is paused/suspended
- **Power States**: Follows existing lighting system (candle overlay above world objects)

## Testing Coverage
Added 9 focused tests in `PersistenceAndMapTests`:
1. ✅ Position derivation from `object-engine-core` anchor
2. ✅ Node structure (one sprite, shader, scale=1, radius/outline values)
3. ✅ Proximity entry activates highlight and REPAIR button
4. ✅ Leaving radius clears highlight and UI
5. ✅ Inactive mission hides node and clears interaction
6. ✅ Active mission shows node and enables interaction
7. ✅ Seven engine-core stations do not create legacy rectangle nodes
8. ✅ Tactical map markers use `mainEngineCorePosition`
9. ✅ Accumulated Z-ordering (object < candle < HUD)

## Files Modified
1. `GameClassification/Resources/Assets.xcassets/MainEngine.imageset/Contents.json`
2. `GameClassification/Resources/Assets.xcassets/MainEngine.imageset/MainEngine.png`
3. `GameClassification/GameEngine/Map/MapGeometryConfiguration.swift`
4. `GameClassification/GameEngine/Nodes/MainEngineControlNode.swift` (new)
5. `GameClassification/GameEngine/Scenes/GameScene.swift`
6. `GameClassification/GameEngine/World/GameWorldBuilder.swift`
7. `GameClassification/GameEngine/Systems/InteractionSystem.swift`
8. `GameClassification/Features/TacticalMap/MapMarker.swift`
9. `GameClassificationTests/PersistenceAndMapTests.swift`

## Architectural Compliance
- ✅ Follows `docs/object-integration-SKILL.md` pattern
- ✅ Reuses `GameEngine/Nodes/EnginePipeControlNode.swift` template
- ✅ One computed position property in `MapGeometryConfiguration`
- ✅ Single sprite node with shader-based outline
- ✅ Centralized mission-gating via `isMainEngineInteractable`
- ✅ Integrated into existing proximity/interaction flow
- ✅ Respects candle overlay render order (world < candle < HUD)
- ✅ Lifecycle integration in all three refresh paths
- ✅ Tactical map markers use same position source
- ✅ Comprehensive test coverage

## Usage
When any of the 7 engine-core missions becomes active (`.available` or `.active` status):
1. `MainEngineControlNode` becomes visible at the engine core
2. Player approaching within 76-unit radius triggers white outline
3. "REPAIR" button appears
4. Completing the mission advances story; next engine-core mission takes over the same sprite
5. All 7 missions share the same visual location and interaction behavior

## Notes
- The sprite visual is independent of the underlying station definitions in `MapGeometryConfiguration.stations`
- Story progression, objective IDs, and mission flow remain unchanged
- Kitchen, Lab, and other room stations continue to use their own nodes/visuals
- Map debug mode shows all stations; normal gameplay follows visibility system rules
