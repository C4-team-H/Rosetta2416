import SpriteKit

enum PhysicsCategory {
    static let none: UInt32 = 0
    static let player: UInt32 = 1 << 0
    static let wall: UInt32 = 1 << 1
    static let roomTrigger: UInt32 = 1 << 2
    static let interactable: UInt32 = 1 << 3
    static let door: UInt32 = 1 << 4
}

enum PhysicsContactResolver {
    static func otherBody(
        bodyA: SKPhysicsBody,
        bodyB: SKPhysicsBody,
        pairedWith category: UInt32
    ) -> SKPhysicsBody? {
        if bodyA.categoryBitMask == PhysicsCategory.player,
           bodyB.categoryBitMask == category {
            return bodyB
        }
        if bodyB.categoryBitMask == PhysicsCategory.player,
           bodyA.categoryBitMask == category {
            return bodyA
        }
        return nil
    }
}

struct RoomContactTracker {
    private(set) var activeTriggers: [RoomID: [String: Int]] = [:]

    var resolvedRoom: RoomID? {
        RoomID.allCases.first { activeTriggers[$0]?.isEmpty == false }
    }

    mutating func begin(room: RoomID, triggerID: String) {
        activeTriggers[room, default: [:]][triggerID, default: 0] += 1
    }

    mutating func end(room: RoomID, triggerID: String) {
        guard let count = activeTriggers[room]?[triggerID] else { return }
        if count <= 1 {
            activeTriggers[room]?[triggerID] = nil
        } else {
            activeTriggers[room]?[triggerID] = count - 1
        }
        if activeTriggers[room]?.isEmpty == true {
            activeTriggers[room] = nil
        }
    }

    mutating func reset() {
        activeTriggers.removeAll()
    }
}

enum SensorContactTarget: Equatable {
    case room(RoomID, triggerID: String)
    case interactable(String)
    case door(DoorID)
}

struct PendingSensorContact: Equatable {
    let target: SensorContactTarget
    let isBeginning: Bool
}

enum CameraFollowMath {
    static func clampedTarget(
        playerPosition: CGPoint,
        viewportSize: CGSize,
        cameraScale: CGFloat,
        worldSize: CGSize
    ) -> CGPoint {
        CGPoint(
            x: clampedAxis(
                playerPosition.x,
                viewportLength: viewportSize.width,
                cameraScale: cameraScale,
                worldLength: worldSize.width
            ),
            y: clampedAxis(
                playerPosition.y,
                viewportLength: viewportSize.height,
                cameraScale: cameraScale,
                worldLength: worldSize.height
            )
        )
    }

    static func interpolatedPosition(
        from current: CGPoint,
        to target: CGPoint,
        deltaTime: TimeInterval,
        responsiveness: CGFloat = 8
    ) -> CGPoint {
        let safeDelta = CGFloat(min(max(deltaTime, 0), 0.25))
        let progress = 1 - exp(-responsiveness * safeDelta)
        return CGPoint(
            x: current.x + (target.x - current.x) * progress,
            y: current.y + (target.y - current.y) * progress
        )
    }

    private static func clampedAxis(
        _ value: CGFloat,
        viewportLength: CGFloat,
        cameraScale: CGFloat,
        worldLength: CGFloat
    ) -> CGFloat {
        let visibleLength = max(0, viewportLength * cameraScale)
        guard visibleLength < worldLength else { return worldLength / 2 }
        let halfVisible = visibleLength / 2
        return min(max(value, halfVisible), worldLength - halfVisible)
    }
}
