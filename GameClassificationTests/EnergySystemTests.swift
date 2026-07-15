import Testing
@testable import GameClassification

@Suite("Player energy")
struct EnergySystemTests {
    @Test("Delta time and movement multiplier control drain")
    func deltaTimeDrain() {
        var idle = EnergySystem(playerID: "idle")
        var moving = EnergySystem(playerID: "moving")

        _ = idle.update(deltaTime: 10, isMoving: false)
        _ = moving.update(deltaTime: 10, isMoving: true)

        #expect(idle.state.energy == 99.2)
        #expect(moving.state.energy == 98.8)
    }

    @Test("Food, disruption, clamping, and checkpoint minimum are local")
    func energyActions() {
        var energy = EnergySystem(playerID: "local", energy: 80)
        energy.restoreFood()
        #expect(energy.state.energy == 100)

        energy.applyElectricalDisruption()
        #expect(energy.state.energy == 95)

        energy.restoreCheckpoint(PlayerSurvivalState(playerID: "local", energy: 4))
        #expect(energy.state.energy == 50)
    }

    @Test("Zero energy reports depletion")
    func depletion() {
        var energy = EnergySystem(playerID: "local", energy: 0.04)
        let depleted = energy.update(deltaTime: 1, isMoving: false)

        #expect(depleted)
        #expect(energy.state.energy == 0)
    }
}

