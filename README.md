# GameClassification

## Tactical map viewer

The SpriteKit game uses a SwiftUI tactical map overlay. Its implementation is split by responsibility under `GameClassification/Map`:

- `GameMapLayout.swift` is the shared source of truth for world size, rooms, corridors, collision walls, stations, and default markers.
- `MapCoordinateConverter.swift` converts SpriteKit's bottom-left world coordinates into the map's top-left SwiftUI coordinates while preserving aspect ratio and padding.
- `MapViewModel.swift` owns presentation, gameplay mode, local and teammate positions, connection state, visibility configuration, and mission markers.
- `Views/FullMapView.swift` composes the vector map, mission markers, and player markers. `MapViewportTransform` keeps zoom and pan separate so gestures can be added later.
- `Integration/MapOverlayContainerView.swift` forwards touches to SpriteKit when the overlay is closed and blocks gameplay input while the full map is open.

`GameScene` updates the local position through:

```swift
mapViewModel.updateLocalPlayer(position: player.position)
```

The existing multiplayer synchronization callback should reuse its latest position data instead of sending map-specific packets:

```swift
mapViewModel.updateTeammate(
    position: synchronizedPosition,
    connectionState: .connected,
    name: teammateDisplayName
)
```

Pass `nil` with `.reconnecting` to preserve and dim the last-known position, or call `clearTeammatePosition()` when no position should remain visible. Set `showsTeammateOnMap` per level when teammate visibility is restricted.

`MapViewModel.gameplayMode` defaults to `.continueGameplay`. The map always blocks local movement input, but SpriteKit and multiplayer updates continue. Set it to `.pauseLocalGameplay` when a single-player level should suspend its local simulation.

### Replacing the vector map

For a changed SpriteKit level, update `GameMapLayout.worldSize`, `rooms`, `corridors`, and `wallSegments`. Both collision setup and map rendering consume that same layout, so the two representations remain aligned.

To use a final map image:

1. Add the original map artwork to `Assets.xcassets` with the same aspect ratio as `GameMapLayout.worldSize`.
2. In `MapBackgroundView`, render the resizable image inside `converter.mapFrame` and position it at that frame's midpoint.
3. Keep all player and mission locations in SpriteKit world coordinates. `MapCoordinateConverter` will continue to handle scaling, safe padding, clamping, and Y-axis inversion on every device size.
4. Keep `GameMapLayout.wallSegments` for SpriteKit collision even if the vector wall drawing is removed from the SwiftUI background.

The `MapMockMovementDemo` preview demonstrates live movement for both players without network traffic.
