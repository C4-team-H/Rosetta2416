import SpriteKit

extension GameScene: SKPhysicsContactDelegate {
    func didBegin(_ contact: SKPhysicsContact) {
        queueSensorContact(bodyA: contact.bodyA, bodyB: contact.bodyB, isBeginning: true)
    }

    func didEnd(_ contact: SKPhysicsContact) {
        queueSensorContact(bodyA: contact.bodyA, bodyB: contact.bodyB, isBeginning: false)
    }

    func processPendingPhysicsContacts() {
        guard !pendingSensorContacts.isEmpty else { return }
        let contacts = pendingSensorContacts
        pendingSensorContacts.removeAll(keepingCapacity: true)

        for contact in contacts {
            switch contact.target {
            case let .room(room, triggerID):
                if contact.isBeginning {
                    roomContactTracker.begin(room: room, triggerID: triggerID)
                } else {
                    roomContactTracker.end(room: room, triggerID: triggerID)
                }

            case let .interactable(id):
                updateContactCount(in: &interactableContactCounts, id: id, isBeginning: contact.isBeginning)

            case let .door(id):
                updateContactCount(in: &doorContactCounts, id: id, isBeginning: contact.isBeginning)
            }
        }

        let resolvedRoom = roomContactTracker.resolvedRoom
        guard resolvedRoom != sessionState.currentRoom else { return }
        if let previousRoom = sessionState.currentRoom {
            eventDelegate?.gameScene(self, didExit: previousRoom)
        }
        sessionState.updateCurrentRoom(resolvedRoom)
        if let resolvedRoom {
            eventDelegate?.gameScene(self, didEnter: resolvedRoom)
        }
    }

    func resetContactTracking() {
        pendingSensorContacts.removeAll()
        roomContactTracker.reset()
        interactableContactCounts.removeAll()
        doorContactCounts.removeAll()
        sessionState.updateCurrentRoom(nil)
    }

    private func queueSensorContact(
        bodyA: SKPhysicsBody,
        bodyB: SKPhysicsBody,
        isBeginning: Bool
    ) {
        if let triggerBody = PhysicsContactResolver.otherBody(
            bodyA: bodyA,
            bodyB: bodyB,
            pairedWith: PhysicsCategory.roomTrigger
        ),
           let rawRoom = triggerBody.node?.userData?["roomID"] as? String,
           let room = RoomID(rawValue: rawRoom) {
            let triggerID = (triggerBody.node?.userData?["triggerID"] as? String)
                ?? triggerBody.node?.name
                ?? room.triggerNodeName
            pendingSensorContacts.append(PendingSensorContact(
                target: .room(room, triggerID: triggerID),
                isBeginning: isBeginning
            ))
            return
        }

        if let interactableBody = PhysicsContactResolver.otherBody(
            bodyA: bodyA,
            bodyB: bodyB,
            pairedWith: PhysicsCategory.interaction
        ),
           let id = (interactableBody.node?.userData?["interactableID"] as? String)
            ?? interactableBody.node?.name {
            pendingSensorContacts.append(PendingSensorContact(
                target: .interactable(id),
                isBeginning: isBeginning
            ))
            return
        }

        if let doorBody = PhysicsContactResolver.otherBody(
            bodyA: bodyA,
            bodyB: bodyB,
            pairedWith: PhysicsCategory.closedDoor
        ),
           let door = doorBody.node as? ShipDoorNode {
            pendingSensorContacts.append(PendingSensorContact(
                target: .door(door.doorID),
                isBeginning: isBeginning
            ))
        }
    }

    private func updateContactCount<ID: Hashable>(
        in counts: inout [ID: Int],
        id: ID,
        isBeginning: Bool
    ) {
        if isBeginning {
            counts[id, default: 0] += 1
        } else if let count = counts[id] {
            counts[id] = count <= 1 ? nil : count - 1
        }
    }
}
