# cobaGameC4 interactive object integration

Read this file before implementing an interactive artwork object in `/Users/neuhendra/Developer/cobaGameC4`. Reinspect every landmark with `rg`; filenames are stable architectural owners, while exact symbols and tests may evolve.

## Contents

- [Ownership map](#ownership-map)
- [Coordinate pattern](#coordinate-pattern)
- [Asset-catalog pattern](#asset-catalog-pattern)
- [Node contract](#node-contract)
- [Runtime and interaction contract](#runtime-and-interaction-contract)
- [Candle overlay and render order](#candle-overlay-and-render-order)
- [Story and marker boundary](#story-and-marker-boundary)
- [Focused tests](#focused-tests)
- [Verification commands](#verification-commands)

## Ownership map

| Concern | Canonical owner | Contract |
| --- | --- | --- |
| Authored objects and derived positions | `GameClassification/GameEngine/Map/MapGeometryConfiguration.swift` | Keep the coordinate derived from live configured geometry. |
| Runtime object creation | `GameClassification/GameEngine/World/GameWorldBuilder.swift` | Remove the prior node, construct once, and add it to the furniture layer. |
| Scene-held state and update lifecycle | `GameClassification/GameEngine/Scenes/GameScene.swift` | Store the node, run proximity from the existing update loop, and rebuild after relevant geometry changes. |
| Proximity and action UI | `GameClassification/GameEngine/Systems/InteractionSystem.swift` | Use the player's world position, node radius, highlight setter, and existing button/action flow. |
| Candle darkness and render order | `GameClassification/GameEngine/Scenes/GameScene.swift`, `GameClassification/GameEngine/Nodes/Effects/CandleLightNode.swift`, `GameClassification/GameEngine/Systems/LightingSystem.swift` | Keep world objects below the shared candle overlay and camera HUD above it. |
| Input dispatch | `GameClassification/Features/Gameplay/Input/GameplayInput.swift` | Route an existing or explicitly requested button name to the object action. |
| Story visibility | `GameClassification/GameEngine/Missions/StationVisibilitySystem.swift` | Add an interaction ID only when visibility is story-dependent. |
| Tactical Map marker | `GameClassification/Features/TacticalMap/MapMarker.swift` | Reuse the same centralized position and visibility decision as the world object. |
| Artwork | `GameClassification/Resources/Assets.xcassets` | Use one imageset per supplied asset. |
| Focused regression tests | `GameClassificationTests/PersistenceAndMapTests.swift` or the nearest focused suite | Test coordinate ownership, node structure, proximity entry, and proximity exit. |
| Lighting regression tests | `GameClassificationTests/LightingSystemTests.swift` | Test accumulated Z ordering and existing power/debug lighting behavior. |

The current runtime map pipeline is `MapGeometryConfiguration.drawingSpaceDefault -> GameMapLayout.makeRuntimeMap -> WorldLoader -> ShipMapNode`. `ShipMapNode` owns floors, object collision, and doors. A decorative interactive sprite belongs in the builder's furniture layer and must not recreate those systems.

## Coordinate pattern

Prefer a derived property beside the map configuration model:

```swift
var exampleObjectPosition: CGPoint {
    guard let anchor = objects.first(where: { $0.id == "object-anchor-id" }) else {
        return spawnPoint(for: .relevantRoom) ?? .zero
    }
    return CGPoint(
        x: anchor.position.x + requestedOffset.x,
        y: anchor.position.y + requestedOffset.y
    )
}
```

Use `anchor.position` when the request targets the configured object coordinate. Use `anchor.objectBounds` only when placement is explicitly relative to an edge or corner. Apply the requested offset in the same map coordinate space as the anchor. Reuse the property for world nodes and markers.

## Asset-catalog pattern

Create `GameClassification/Resources/Assets.xcassets/<Asset>.imageset/Contents.json` and copy the supplied image into it. A single source file can be registered as universal `1x` when that matches the supplied asset:

```json
{
  "images" : [
    { "filename" : "<Asset>.png", "idiom" : "universal", "scale" : "1x" },
    { "idiom" : "universal", "scale" : "2x" },
    { "idiom" : "universal", "scale" : "3x" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

Inspect the image dimensions and alpha before choosing display size. Do not edit or replace the user's source file.
If the requested source asset or anchor object ID is absent, stop and request the exact missing input instead of choosing a similarly named file or object.

## Node contract

Use the bundled node template and preserve these properties:

- `SKNode` is the object container.
- `artworkSprite` is its only visual child.
- Transparent texture padding gives the fragment shader room to draw outside the original alpha bounds.
- `SKTexture.filteringMode = .linear` keeps resized art and outline smooth.
- `artworkSprite.size` owns rendered dimensions, leaving transform scales at `1`.
- A `u_highlightMix` uniform fades between normal and outlined rendering.
- A state guard prevents the same transition from restarting every update frame.
- A keyed `SKAction` allows a direction change to replace the active fade cleanly.

Use a different node approach only when the supplied asset is animated, tiled, physically simulated, or requires multiple independent visuals.

## Runtime and interaction contract

The builder should follow this shape:

```swift
func createExampleObject() {
    exampleObjectNode?.removeFromParent()
    let node = ExampleObjectNode()
    node.position = geometryStore.configuration.exampleObjectPosition
    node.zPosition = requestedZPosition
    (shipMapNode?.furnitureLayer ?? self).addChild(node)
    exampleObjectNode = node
}
```

The proximity check must:

1. Require `.playing`, a player, a visible object, and any object-specific availability rule.
2. Reset highlight and action UI before returning from an unavailable state.
3. Compute world-space distance once.
4. Compare it with the node's centralized interaction radius.
5. Send the same Boolean to the node highlight and action UI.

Call the check from the existing update loop. During map/debug suspension and story-driven hiding, reset immediately without animation. Recreate the node after full geometry replacement or `.object` changes, removing the old node first.

## Candle overlay and render order

Treat every interactive object placed in `ShipMapNode.furnitureLayer` as world content that must follow the existing candle darkness by default. Do not add a second overlay, per-object dark tint, or darkness branch to the object's highlight shader.

SpriteKit drawing order for these nested branches depends on the accumulated Z positions of their ancestors. Inspect the current hierarchy instead of comparing only the object's local `zPosition`. The current Album Book contract is:

```text
world object: ShipMapNode 0 + FurnitureLayer 10 + object 2 = 12
candle:       CameraNode 100 + CandleLightNode 9.5        = 109.5
camera HUD:   CameraNode 100 + joystick 10 / button 12   = 110 / 112
```

Maintain this invariant:

```text
world object accumulated Z < candle accumulated Z < camera HUD accumulated Z
```

`GameScene.cameraOverlayRootZ` raises the whole camera-space branch above gameplay world layers while preserving the local ordering already used by `CandleLightNode`, joystick, interaction buttons, and transient lighting flashes. If the layer constants change, recompute the accumulated values rather than copying the example numbers.

Keep lighting state centralized:

- Let `LightingSystem` control whether the candle overlay is visible for `.off`, `.basicPower`, `.disrupted`, and `.fullyRestored`.
- Let `GameScene.synchronizeDebugLightingVisibility()` hide the overlay in map debug mode.
- Keep the object's proximity outline shader independent; the shared candle pass darkens both the artwork and white outline after they render.
- When adding a new world layer, ensure its maximum accumulated Z stays below the candle overlay unless the request explicitly defines camera-space HUD behavior.

Lock the hierarchy with a focused test in `LightingSystemTests`:

```swift
let objectWorldZ = shipMap.zPosition
    + shipMap.furnitureLayer.zPosition
    + object.zPosition
let candleWorldZ = scene.cameraNode.zPosition + candleLight.zPosition
let hudWorldZ = scene.cameraNode.zPosition + hudNode.zPosition

#expect(objectWorldZ < candleWorldZ)
#expect(candleWorldZ < hudWorldZ)
```

## Story and marker boundary

Purely decorative proximity does not require new story state. Add or alter story logic only when the request defines unlock, persistence, dialogue, or completion behavior. If a Tactical Map marker is requested, make its `worldPosition` equal the configuration position property and pass visibility through `StationVisibilitySystem` when relevant.

## Focused tests

Cover at least:

- derived position equals anchor plus the requested offset;
- optional marker position equals the same configuration property;
- node contains exactly one artwork sprite and a shader;
- artwork transform scales remain `1`;
- entering the radius activates highlight and the requested action UI;
- leaving the radius deactivates both;
- hidden or unavailable state clears highlight;
- the object's accumulated Z is below the candle overlay while its interaction button or joystick remains above it;
- a render smoke test can obtain an `SKTexture` from the highlighted node when practical.

Do not hard-code padding assumptions independently from `outlineWidth`; derive expectations with `ceil(outlineWidth) + 2`.

## Verification commands

Use an installed simulator, currently typically `iPhone 17,OS=26.5` or `iPhone 17 Pro,OS=26.5`:

```bash
rtk xcodebuild test -scheme GameClassification \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  -only-testing:GameClassificationTests/<Suite>/<testName>
rtk git diff --check
rtk git status --short
```

Final xcodebuild exit status and test result are authoritative. Report simulator service noise separately when the test itself passes.
