import Foundation

struct EnergyConfiguration: Codable, Equatable, Sendable {
    let maximumEnergy: Double
    let passiveDrainPerSecond: Double
    let movementDrainMultiplier: Double
    let foodRestoreAmount: Double
    let disruptionCost: Double
    let checkpointRestartMinimum: Double

    static let standard = EnergyConfiguration(
        maximumEnergy: 100,
        passiveDrainPerSecond: 0.15,
        movementDrainMultiplier: 2.0,
        foodRestoreAmount: 50,
        disruptionCost: 10,
        checkpointRestartMinimum: 50
    )
}

struct EnergySystem: Sendable {
    let configuration: EnergyConfiguration
    private(set) var state: PlayerSurvivalState

    init(
        playerID: String,
        energy: Double = EnergyConfiguration.standard.maximumEnergy,
        configuration: EnergyConfiguration = .standard
    ) {
        self.configuration = configuration
        state = PlayerSurvivalState(
            playerID: playerID,
            energy: min(max(energy, 0), configuration.maximumEnergy)
        )
    }

    @discardableResult
    mutating func update(deltaTime: TimeInterval, isMoving: Bool) -> Bool {
        guard deltaTime.isFinite, deltaTime > 0, state.energy > 0 else { return state.energy <= 0 }
        let multiplier = isMoving ? configuration.movementDrainMultiplier : 1
        state.energy = max(0, state.energy - configuration.passiveDrainPerSecond * multiplier * deltaTime)
        return state.energy <= 0
    }

    mutating func applyElectricalDisruption() {
        state.energy = max(0, state.energy - configuration.disruptionCost)
    }

    mutating func restoreFood() {
        state.energy = min(configuration.maximumEnergy, state.energy + configuration.foodRestoreAmount)
    }

    mutating func restoreCheckpoint(_ snapshot: PlayerSurvivalState) {
        state = PlayerSurvivalState(
            playerID: snapshot.playerID,
            energy: min(
                configuration.maximumEnergy,
                max(snapshot.energy, configuration.checkpointRestartMinimum)
            )
        )
    }

    mutating func restore(_ state: PlayerSurvivalState) {
        self.state = PlayerSurvivalState(
            playerID: state.playerID,
            energy: min(max(state.energy, 0), configuration.maximumEnergy)
        )
    }
}
