---
name: add-spritekit-map-object
description: Add or replace interactive SpriteKit artwork objects in the GameClassification map in /Users/neuhendra/Developer/cobaGameC4. Use when a user supplies a PNG or asset and asks to place it at an existing map object or centralized coordinate, resize or offset it, register proximity interaction, add or tune a smooth white outline, make it follow the candle darkness overlay, connect an action or Tactical Map marker, or repeat the Album Book integration pattern without duplicating gameplay, lighting, or story systems.
---

# Add SpriteKit Map Object

Implement each object through the repository's existing map, scene, interaction, visibility, and test owners. Treat the Album Book as a proven pattern, not as code to duplicate verbatim.

## Collect the object contract

Determine these values from the request and current checkout before editing:

- Swift type and scene property names
- asset source path and asset-catalog name
- node name and interaction ID
- anchor map object ID or existing centralized coordinate
- map-space offset from the anchor
- rendered artwork multiplier or exact size
- interaction radius and outline width
- whether it is a world object that must follow candle darkness or a camera-space HUD element
- interaction action, action-button label, visibility rule, and Tactical Map marker requirement

Infer naming and purely visual defaults from nearby code. Ask only when an unspecified action or story condition would materially change gameplay.

## Follow the workflow

1. Read [references/cobagamec4-integration.md](references/cobagamec4-integration.md) before patching this repository.
2. Inspect local instructions, `git status --short`, the supplied image, and current owners with `rg`. Preserve unrelated user changes.
3. Add the image to `GameClassification/Resources/Assets.xcassets/<Asset>.imageset`. Keep the original transparent pixels and use a valid `Contents.json`.
4. Add one computed position to the canonical `MapGeometryConfiguration`. Derive it from the configured anchor object or existing geometry plus the requested map-space offset. Do not create a second coordinate store.
5. Create the visual node from [assets/InteractiveMapObjectNode.swift.template](assets/InteractiveMapObjectNode.swift.template). Replace every `__TOKEN__` and adapt names, size, radius, and outline width.
6. Keep exactly one `SKSpriteNode` for the artwork. Expand its texture with transparent padding, apply the outline in one shader, and animate one highlight uniform. Set rendered dimensions through `SKSpriteNode.size`; keep `xScale` and `yScale` at `1` unless the request explicitly requires mirroring.
7. Register one optional node property on `GameScene`. In `GameWorldBuilder`, remove the old instance before creating the new one, position it from `geometryStore.configuration`, and add it to `shipMapNode?.furnitureLayer ?? self`.
8. Connect proximity through `InteractionSystem` and the existing scene update flow. Toggle highlight only when the desired state changes. On leaving the radius, hiding the object, pausing input, or leaving gameplay, remove the outline and interaction UI.
9. Verify the candle render stack described in [references/cobagamec4-integration.md](references/cobagamec4-integration.md#candle-overlay-and-render-order). Keep a world object's accumulated Z below the candle overlay and keep camera HUD controls above it. Use the shared overlay; do not darken individual objects separately.
10. Recreate or reposition the object when map object geometry changes. Reuse the existing action, story, lighting, visibility, and marker systems; extend them only when the request requires new behavior.
11. Add focused Swift Testing coverage. Start from [assets/InteractiveMapObjectTests.swift.template](assets/InteractiveMapObjectTests.swift.template), then adapt it to the actual scene action, lighting, and visibility contract.

## Validate the integration

Run the static audit after replacing its arguments:

```bash
rtk bash /Users/neuhendra/.codex/skills/add-spritekit-map-object/scripts/audit_object_integration.sh \
  --repo /Users/neuhendra/Developer/cobaGameC4 \
  --type AlbumBookNode \
  --asset AlbumBook \
  --position albumBookPosition \
  --scene-var albumBookNode \
  --proximity checkProximityToAlbumBook
```

Then run the smallest relevant iOS Simulator test with an installed destination and finish with `rtk git diff --check`. Inspect the final diff and report unrelated pre-existing failures separately.

## Guardrails

- Do not hard-code a second world position in the builder, marker factory, or interaction system.
- Do not silently substitute a nearby asset name or anchor object ID when the requested one is missing.
- Do not add a duplicate sprite for the outline.
- Do not add a per-object darkness shader, tint, or duplicate overlay when `CandleLightNode` should cover the world object.
- Do not assign a world object's accumulated Z above the candle overlay; preserve `world object < candle overlay < camera HUD`.
- Do not rebuild or restart the highlight action every frame.
- Do not let interaction remain visible when the object becomes hidden or unavailable.
- Do not move physical map collision merely to align decorative artwork unless explicitly requested.
- Do not change unrelated story progression, station behavior, movement, collision, or map geometry.
- Do not overwrite source assets or unrelated dirty worktree files.
- Do not edit `GameClassification.xcodeproj/project.pbxproj` for ordinary source or asset additions; the project uses filesystem-synchronized groups.
